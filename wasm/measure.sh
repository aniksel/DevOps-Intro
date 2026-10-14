#!/usr/bin/env bash
# Lab 12 perf comparison: the Spin WASM component against the Lab 6 container.
# Warm latency comes from hyperfine, cold start from a Python driver that
# spawns each runtime and polls until the first HTTP 200.
# The container is published on 8081 so a compose stack on 8080 is left alone.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SPIN_DIR="$HERE/moscow-time"
OUT="$HERE/perf"
mkdir -p "$OUT"

SPIN_URL="http://127.0.0.1:3000/time"
DOCKER_URL="http://127.0.0.1:8081/health"
IMAGE="quicknotes:lab6"
PORT=8081
SAMPLES=5

echo "== rig =="
{
  sw_vers 2>/dev/null | tr '\n' ' '
  echo
  uname -m
  sysctl -n machdep.cpu.brand_string 2>/dev/null
  echo "spin      $(spin --version)"
  echo "docker    $(docker --version)"
  echo "hyperfine $(hyperfine --version)"
  echo "go        $(go version)"
} | tee "$OUT/rig.txt"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "== building $IMAGE =="
  docker build -t "$IMAGE" "$HERE/../app" || exit 1
fi

echo
echo "== artifact size =="
{
  ls -l "$SPIN_DIR/main.wasm" | awk '{printf "main.wasm on disk        %d bytes (%.2f MB)\n", $5, $5/1048576}'
  docker images --format '{{.Size}}' "$IMAGE" | awk '{printf "quicknotes:lab6 on disk  %s (uncompressed, docker images)\n", $0}'
  docker image inspect "$IMAGE" --format '{{.Size}}' | awk '{printf "quicknotes:lab6 content  %d bytes (%.2f MB, compressed layers)\n", $1, $1/1048576}'
} | tee "$OUT/size.txt"

echo
echo "== warm latency =="
docker rm -f qn-perf >/dev/null 2>&1
( cd "$SPIN_DIR" && exec spin up ) >"$OUT/spin-warm.log" 2>&1 &
SPIN_PID=$!
docker run -d --name qn-perf -p "$PORT:8080" "$IMAGE" >/dev/null || exit 1

for i in $(seq 1 300); do curl -fs -o /dev/null "$SPIN_URL" && break; sleep 0.1; done
for i in $(seq 1 300); do curl -fs -o /dev/null "$DOCKER_URL" && break; sleep 0.1; done

hyperfine -N --warmup 5 --runs 50 --export-json "$OUT/warm-spin.json" \
  "curl -s $SPIN_URL" | tee "$OUT/warm-spin.txt"
hyperfine -N --warmup 5 --runs 50 --export-json "$OUT/warm-docker.json" \
  "curl -s $DOCKER_URL" | tee "$OUT/warm-docker.txt"

echo
echo "== server-side latency, 50 requests inside one curl process =="
{
  for u in "$SPIN_URL" "$DOCKER_URL"; do
    args=""
    for i in $(seq 1 50); do args="$args -o /dev/null $u"; done
    # shellcheck disable=SC2086
    curl -s -w '%{time_total}\n' $args > "$OUT/tmp-times.txt"
    python3 - "$u" "$OUT/tmp-times.txt" <<'PY'
import sys
xs = sorted(float(l) * 1000 for l in open(sys.argv[2]) if l.strip())
def pct(q):
    k = (len(xs) - 1) * q
    lo, hi = int(k), min(int(k) + 1, len(xs) - 1)
    return xs[lo] + (xs[hi] - xs[lo]) * (k - lo)
print(f"{sys.argv[1]:40s} n={len(xs)}  p50 {pct(.50):.3f} ms  p95 {pct(.95):.3f} ms")
PY
  done
} | tee "$OUT/server-side.txt"
rm -f "$OUT/tmp-times.txt"

kill "$SPIN_PID" 2>/dev/null; wait "$SPIN_PID" 2>/dev/null
docker rm -f qn-perf >/dev/null 2>&1
sleep 2

echo
echo "== cold start, $SAMPLES samples each =="
python3 - "$SPIN_DIR" "$IMAGE" "$SAMPLES" "$PORT" <<'PY' | tee "$OUT/cold.txt"
import subprocess, sys, time, urllib.request, statistics

spin_dir, image, samples, port = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
DEVNULL = subprocess.DEVNULL

def wait(url, timeout=120):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2) as r:
                if r.status == 200:
                    return True
        except Exception:
            pass
        time.sleep(0.002)
    return False

spin, docker = [], []

for i in range(samples):
    t0 = time.perf_counter()
    p = subprocess.Popen(["spin", "up"], cwd=spin_dir, stdout=DEVNULL, stderr=DEVNULL)
    ok = wait("http://127.0.0.1:3000/time")
    ms = (time.perf_counter() - t0) * 1000
    print(f"spin   sample {i+1}: {ms:8.1f} ms" + ("" if ok else "  (TIMEOUT)"))
    spin.append(ms)
    p.terminate(); p.wait()
    time.sleep(1.5)

for i in range(samples):
    subprocess.run(["docker", "rm", "-f", "qn-cold"], stdout=DEVNULL, stderr=DEVNULL)
    time.sleep(0.5)
    t0 = time.perf_counter()
    r = subprocess.run(["docker", "run", "-d", "--name", "qn-cold",
                        "-p", f"{port}:8080", image], stdout=DEVNULL, stderr=DEVNULL)
    if r.returncode != 0:
        print(f"docker sample {i+1}: FAILED to start")
        continue
    ok = wait(f"http://127.0.0.1:{port}/health")
    ms = (time.perf_counter() - t0) * 1000
    print(f"docker sample {i+1}: {ms:8.1f} ms" + ("" if ok else "  (TIMEOUT)"))
    docker.append(ms)
    subprocess.run(["docker", "rm", "-f", "qn-cold"], stdout=DEVNULL, stderr=DEVNULL)
    time.sleep(1.5)

print()
if spin:
    print(f"spin   cold p50: {statistics.median(spin):.1f} ms   min {min(spin):.1f}   max {max(spin):.1f}")
if docker:
    print(f"docker cold p50: {statistics.median(docker):.1f} ms   min {min(docker):.1f}   max {max(docker):.1f}")
PY

echo
echo "== warm percentiles (hyperfine wall clock) =="
python3 - "$OUT/warm-spin.json" "$OUT/warm-docker.json" <<'PY' | tee "$OUT/warm-percentiles.txt"
import json, sys, statistics

def pct(xs, q):
    xs = sorted(xs)
    k = (len(xs) - 1) * q
    lo, hi = int(k), min(int(k) + 1, len(xs) - 1)
    return xs[lo] + (xs[hi] - xs[lo]) * (k - lo)

for label, path in (("spin", sys.argv[1]), ("docker", sys.argv[2])):
    d = json.load(open(path))["results"][0]["measurements"]
    t = [m["time_wall_clock"]["value"] * 1000 for m in d]
    print(f"{label:7s} n={len(t)}  p50 {pct(t,0.50):6.2f} ms   "
          f"p95 {pct(t,0.95):6.2f} ms   mean {statistics.mean(t):6.2f} ms   "
          f"min {min(t):6.2f}   max {max(t):6.2f}")
PY

echo
echo "== done, artifacts in $OUT =="
