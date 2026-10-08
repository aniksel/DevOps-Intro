# Lab 9 submission

## Task 1: Trivy, image, filesystem, config and SBOM

Scanner pinned to `aquasec/trivy:0.59.1`. Artifacts:

- [security/trivy-image-before.txt](../security/trivy-image-before.txt)
- [security/trivy-image-after.txt](../security/trivy-image-after.txt)
- [security/trivy-fs.txt](../security/trivy-fs.txt)
- [security/trivy-config.txt](../security/trivy-config.txt)
- [security/quicknotes.sbom.cdx.json](../security/quicknotes.sbom.cdx.json)

### 1. Image scan

```
$ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$HOME/.cache/trivy:/root/.cache/trivy" \
    aquasec/trivy:0.59.1 image --severity HIGH,CRITICAL quicknotes:lab6

healthcheck (gobinary)
======================
Total: 19 (HIGH: 19, CRITICAL: 0)

┌─────────┬────────────────┬──────────┬────────┬───────────────────┬──────────────────────────────┐
│ Library │ Vulnerability  │ Severity │ Status │ Installed Version │        Fixed Version         │
├─────────┼────────────────┼──────────┼────────┼───────────────────┼──────────────────────────────┤
│ stdlib  │ CVE-2026-25679 │ HIGH     │ fixed  │ v1.24.13          │ 1.25.8, 1.26.1               │
│         │ CVE-2026-27145 │          │        │                   │ 1.25.11, 1.26.4              │
│         │ CVE-2026-32280 │          │        │                   │ 1.25.9, 1.26.2               │
...

quicknotes (gobinary)
=====================
Total: 19 (HIGH: 19, CRITICAL: 0)
```

There are no OS package findings. The runtime stage is `scratch`, so the image
holds no OS packages at all. Every finding comes from the Go standard library
linked into the two binaries, and both binaries carry the same 19.

### 2. Filesystem scan

```
$ docker run --rm -v "$PWD":/repo -v "$HOME/.cache/trivy:/root/.cache/trivy" \
    aquasec/trivy:0.59.1 fs --severity HIGH,CRITICAL /repo

.vagrant/machines/default/virtualbox/private_key (secrets)
==========================================================
Total: 1 (HIGH: 1, CRITICAL: 0)

HIGH: AsymmetricPrivateKey (private-key)
════════════════════════════════════════
Asymmetric Private Key
────────────────────────────────────────
 .vagrant/machines/default/virtualbox/private_key:1
```

No vulnerabilities were found in the source tree. `go.mod` declares no
dependencies, so there is nothing to be vulnerable. The one finding comes from
the secret scanner, which Trivy runs by default.

### 3. Config scan

```
$ docker run --rm -v "$PWD":/repo -v "$HOME/.cache/trivy:/root/.cache/trivy" \
    aquasec/trivy:0.59.1 config /repo

app/Dockerfile (dockerfile)
===========================
Tests: 28 (SUCCESSES: 26, FAILURES: 2)
Failures: 2 (UNKNOWN: 0, LOW: 1, MEDIUM: 1, HIGH: 0, CRITICAL: 0)

AVD-DS-0013 (MEDIUM): RUN should not be used to change directory
AVD-DS-0026 (LOW): Add HEALTHCHECK instruction in your Dockerfile
```

26 of the 28 Dockerfile checks pass. There is no HIGH or CRITICAL finding.
`compose.yaml` produced no failures.

### 4. SBOM, CycloneDX

```
$ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$HOME/.cache/trivy:/root/.cache/trivy" -v "$PWD/security:/out" \
    aquasec/trivy:0.59.1 image --format cyclonedx \
    --output /out/quicknotes.sbom.cdx.json quicknotes:lab6
```

First 30 lines:

```json
{
  "$schema": "http://cyclonedx.org/schema/bom-1.6.schema.json",
  "bomFormat": "CycloneDX",
  "specVersion": "1.6",
  "serialNumber": "urn:uuid:78a52315-9149-41e4-8d42-e07a6f5a1882",
  "version": 1,
  "metadata": {
    "timestamp": "2026-10-08T11:22:11+00:00",
    "tools": {
      "components": [
        {
          "type": "application",
          "group": "aquasecurity",
          "name": "trivy",
          "version": "0.59.1"
        }
      ]
    },
    "component": {
      "bom-ref": "pkg:oci/quicknotes@sha256%3Ad076d70b06dc46110c9b93dc4d5e92ced74228ce66b74c272b1f2657eb561181?arch=arm64&repository_url=index.docker.io%2Flibrary%2Fquicknotes",
      "type": "container",
      "name": "quicknotes:lab6",
      "purl": "pkg:oci/quicknotes@sha256%3Ad076d70b06dc46110c9b93dc4d5e92ced74228ce66b74c272b1f2657eb561181?arch=arm64&repository_url=index.docker.io%2Flibrary%2Fquicknotes",
      "properties": [
        {
          "name": "aquasecurity:trivy:DiffID",
          "value": "sha256:589943c2a77412b988665927edfe19381383284cb813fa17f4f82752eaf52f93"
        },
        {
          "name": "aquasecurity:trivy:DiffID",
```

### Triage

Every HIGH finding across the three scans, with a decision.

#### Image scan, 19 HIGH, both binaries

All 19 are the same Go standard library entries at `v1.24.13`, reported once for
`quicknotes` and once for `healthcheck`. Trivy lists a fixed version for each,
and the highest one needed is 1.26.6. The builder in `app/Dockerfile` moved from
`golang:1.24` to `golang:1.26`, which is go1.26.8, so all 19 are fixed in one
change.

| CVE | Package | Severity | Disposition | Reason |
|---|---|---|---|---|
| CVE-2026-25679 | net/url | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-27145 | crypto/x509 | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-32280 | crypto/x509 | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-32281 | crypto/x509 | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-32283 | crypto/tls | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-33811 | net | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-33814 | net/http/internal/http2 | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-33818 | encoding/asn1 | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-39820 | net/mail | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-39821 | golang.org/x/net/idna | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-39822 | os.Root | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-39836 | net | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-42499 | net/mail | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-42504 | mime | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-56853 | net/http | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-56858 | html/template | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-56859 | encoding/xml | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-56860 | net/url | HIGH | FIX | Rebuilt on go1.26.8 |
| CVE-2026-56862 | crypto/tls | HIGH | FIX | Rebuilt on go1.26.8 |

The change, in `app/Dockerfile`:

```diff
-FROM golang:1.24 AS builder
+FROM golang:1.26 AS builder
```

Proof that the fix landed:

```
$ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$HOME/.cache/trivy:/root/.cache/trivy" \
    aquasec/trivy:0.59.1 image --severity HIGH,CRITICAL --exit-code 1 quicknotes:lab6
trivy exit code: 0 (0 = no HIGH or CRITICAL findings)

[
  {
    "Target": "healthcheck",
    "high_or_critical": 0
  },
  {
    "Target": "quicknotes",
    "high_or_critical": 0
  }
]
```

The SBOM regenerated from the new image lists `stdlib v1.26.8` for both
binaries.

Worth saying plainly: most of these 19 were not reachable from QuickNotes. The
service speaks plain HTTP, parses only JSON, renders no templates, sends no
mail and makes no outbound calls, so the `crypto/tls`, `crypto/x509`,
`net/mail`, `encoding/xml` and `html/template` entries sit in code it never
runs. The two `net/url` entries are reachable, because `net/http` parses the
URL of every request. The reason all 19 are marked FIX and not ACCEPT is that
one line closed the whole set, which was cheaper than arguing about each one.

#### Filesystem scan, 1 HIGH

| Finding | File | Severity | Disposition | Reason |
|---|---|---|---|---|
| AsymmetricPrivateKey | `.vagrant/machines/default/virtualbox/private_key` | HIGH | ACCEPT, re-evaluate by 2026-12-31 | See below |

This is the SSH key Vagrant generates for the Lab 5 VM on first boot. It never
reaches the repository, because `.vagrant/` is ignored:

```
$ git check-ignore -v .vagrant/machines/default/virtualbox/private_key
.gitignore:27:.vagrant/        .vagrant/machines/default/virtualbox/private_key
```

The key unlocks one local, disposable VM that holds no data. The control that
matters is the ignore rule, so the re-evaluation is tied to it: check again by
2026-12-31, and immediately if `.gitignore` ever stops covering `.vagrant/`.

#### Config scan

No HIGH or CRITICAL. Both findings are documented anyway.

| ID | Severity | Disposition | Reason |
|---|---|---|---|
| AVD-DS-0013 | MEDIUM | ACCEPT, re-evaluate by 2026-12-31 | The `cd` is inside the builder stage, which is thrown away and never shipped. It exists because the healthcheck source is written with `printf`, since a BuildKit heredoc needs a `syntax` directive and a registry pull. This is a readability rule, not a security one. |
| AVD-DS-0026 | LOW | ACCEPT, re-evaluate when the image ships outside Compose | The health check exists. It is declared in `compose.yaml` with an interval, a timeout, retries and a start period, which is where this deployment defines it. A second copy in the Dockerfile would be a duplicate that can drift. |

### Design questions

**a) What matters besides the CVE severity**

A CVSS score describes the worst case for any user of the component. It does not
know how we use it. Four other things change the real risk.

Reachability. A bug in a function our code never calls cannot be used against
us. That is most of the 19 above.

Exploit availability. A CVE with working public exploit code is a different
problem from one with a theoretical write-up. The first can be used today by
anyone who can read.

Deployment context. This container runs as a non-root user, with every Linux
capability dropped, a read-only root filesystem and no new privileges. It is not
reachable from the internet. A remote code execution bug lands in a process that
can do very little.

Cost of the fix. Here one line closed all 19, so reasoning about each one would
have cost more than fixing them. Cheap fixes should not wait for perfect
analysis.

**b) Why the minimal base is the strongest single control**

A scanner reports a vulnerability for a component that is present. Fewer
components mean fewer reports, and the reports that remain are about code the
team chose to ship. This image is built on `scratch`, so it has no OS packages,
and neither image scan returned a single OS finding.

The second half is what an attacker can do after a bug is used. A minimal base
has no shell, no package manager, no curl and no coreutils. A remote code
execution bug normally gives an attacker a process, and the next step is to run
`sh`, pull a tool and move sideways. Here there is nothing to run. One decision,
taken once, removes both the noise and the next step.

**c) When `.trivyignore` is right and when it is theater**

It is right when the decision behind it is real and written down: a finding in
code that is never reached, a false positive that has been confirmed, or a CVE
with no upstream fix yet. In those cases the entry carries the reason, who
decided, and an expiry date. The file is then a record of decisions.

It is theater when its purpose is to make the build green. Suppressing a
reachable finding that has an available fix does not change the risk, it only
removes the reminder. The tell is an entry with no comment and no date: nobody
will revisit it, so the suppression becomes permanent by accident. Trivy
supports an expiry date per entry, and an entry without one should be treated as
a bug in the file.

**d) What future problem the SBOM solves**

It answers one question quickly: are we affected by this new CVE, and where.

When Log4Shell was published in December 2021, the hard part for most companies
was not patching. It was finding out which services contained log4j, often as a
dependency of a dependency. Teams spent days reading build files and rebuilding
images just to find out. The teams that kept an SBOM per build ran a query
instead.

The file here lists `stdlib v1.26.8` against both binaries with their package
URLs. On the day a Go standard library CVE is published, it answers whether this
image contains the affected version without rebuilding the image or even having
it at hand. The value is created before the incident, which is why the SBOM has
to be produced by the pipeline on every build and kept next to the image.

---

## Task 2: OWASP ZAP baseline and a fix in code

Scanner pinned to `zaproxy/zap-stable:2.16.1`. Passive baseline only, no active
scan. Reports:

- [security/zap-baseline-before.html](../security/zap-baseline-before.html), [JSON](../security/zap-baseline-before.json)
- [security/zap-baseline-after.html](../security/zap-baseline-after.html), [JSON](../security/zap-baseline-after.json)

```
$ docker run --rm --network devops-intro_default \
    -v "$PWD/security:/zap/wrk:rw" -t zaproxy/zap-stable:2.16.1 \
    zap-baseline.py -t http://quicknotes:8080/notes \
    -r zap-baseline-before.html -J zap-baseline-before.json -I
```

The target is `/notes` and not `/`. QuickNotes has no route at the root, so a
scan of `/` only ever reaches a 404 page, the spider finds nothing to follow,
and every header rule passes on an empty response. Starting at `/notes` gives
the passive rules a real API response to read.

### Before the fix

```
WARN-NEW: X-Content-Type-Options Header Missing [10021] x 1
        http://quicknotes:8080/notes (200 OK)
WARN-NEW: Storable and Cacheable Content [10049] x 3
        http://quicknotes:8080/ (404 Not Found)
        http://quicknotes:8080/notes (200 OK)
        http://quicknotes:8080/sitemap.xml (404 Not Found)
WARN-NEW: ZAP is Out of Date [10116] x 1
        http://quicknotes:8080/sitemap.xml (404 Not Found)
WARN-NEW: Insufficient Site Isolation Against Spectre Vulnerability [90004] x 1
        http://quicknotes:8080/notes (200 OK)
FAIL-NEW: 0     FAIL-INPROG: 0  WARN-NEW: 4     WARN-INPROG: 0  INFO: 0 IGNORE: 0       PASS: 63
```

### Triage of every finding

| ID | Name | Risk (confidence) | Affected URL | Disposition | Reason |
|---|---|---|---|---|---|
| 10021 | X-Content-Type-Options Header Missing | Low (Medium) | `/notes` | FIX | A browser may sniff the body and treat a JSON response as something it can run. One header stops it. Fixed in the middleware, the rule is PASS in the second scan. |
| 10049 | Storable and Cacheable Content | Informational (Medium) | `/`, `/notes`, `/sitemap.xml` | FIX | Responses carry user notes, so no shared cache or proxy may keep a copy. `Cache-Control: no-store` was added. The rule now reports the opposite case, Non-Storable Content. |
| 90004 | Insufficient Site Isolation Against Spectre Vulnerability | Low (Medium) | `/notes` | FIX | Without the cross-origin headers another site can pull this response into its own process, which is what a Spectre-style read needs. CORP, COOP and COEP were added, the rule is PASS in the second scan. |
| 10116 | ZAP is Out of Date | Low (High) | `/sitemap.xml` | ACCEPT, re-evaluate when the course bumps the pin | The alert is about the scanner, not about QuickNotes. 2.16.1 is pinned on purpose, because the lab asks for a fixed tag and a scan has to be repeatable. No change to the application can clear it. |

### The fix

New file `app/security.go`, middleware that wraps the whole router:

```go
func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()

		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("Cache-Control", "no-store")

		h.Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; base-uri 'none'")
		h.Set("X-Frame-Options", "DENY")
		h.Set("Referrer-Policy", "no-referrer")

		h.Set("Cross-Origin-Resource-Policy", "same-origin")
		h.Set("Cross-Origin-Opener-Policy", "same-origin")
		h.Set("Cross-Origin-Embedder-Policy", "require-corp")

		next.ServeHTTP(w, r)
	})
}
```

The router now returns the wrapped handler, so the headers apply to every route
and to the 404 the router itself writes:

```diff
-func (s *Server) Routes() *http.ServeMux {
+func (s *Server) Routes() http.Handler {
 	mux := http.NewServeMux()
 	...
-	return mux
+	return securityHeaders(mux)
 }
```

The test in `app/security_test.go` goes through `Routes()` and checks four
targets: a JSON handler, the plain text metrics handler, the notes list, and a
path with no route at all.

```go
srv := newTestServer(t)
for _, target := range []string{"/health", "/metrics", "/notes", "/no-such-path"} {
	...
	srv.Routes().ServeHTTP(rec, req)
	for name, value := range want {
		if got := rec.Header().Get(name); got != value {
			t.Errorf("%s: got %q, want %q", name, got, value)
		}
	}
}
```

It passes with the middleware in place:

```
$ docker run --rm -v "$PWD/app":/src -w /src golang:1.26 go test ./...
ok      quicknotes      0.003s
```

And it fails when the middleware is taken out. This run copies the source,
removes the wrap and runs the tests, without touching the repository:

```
$ docker run --rm -v "$PWD/app":/src:ro golang:1.26 sh -c \
    'cp -r /src /tmp/app && cd /tmp/app && \
     sed -i "s/return securityHeaders(mux)/return mux/" handlers.go && go test ./...'

    --- FAIL: TestSecurityHeaders_OnEveryRoute//notes (0.00s)
        security_test.go:35: X-Frame-Options: got "", want "DENY"
        security_test.go:35: X-Content-Type-Options: got "", want "nosniff"
        security_test.go:35: Cache-Control: got "", want "no-store"
        ...
    --- FAIL: TestSecurityHeaders_OnEveryRoute//no-such-path (0.00s)
        security_test.go:35: Cache-Control: got "", want "no-store"
        ...
FAIL    quicknotes      0.003s
```

### After the fix

Headers on a live response:

```
$ curl -sI http://localhost:8080/notes
HTTP/1.1 200 OK
Cache-Control: no-store
Content-Security-Policy: default-src 'none'; frame-ancestors 'none'; base-uri 'none'
Content-Type: application/json
Cross-Origin-Embedder-Policy: require-corp
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Resource-Policy: same-origin
Referrer-Policy: no-referrer
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
```

Re-scan of the rebuilt image:

```
PASS: X-Content-Type-Options Header Missing [10021]
PASS: Insufficient Site Isolation Against Spectre Vulnerability [90004]
WARN-NEW: Non-Storable Content [10049] x 3
WARN-NEW: ZAP is Out of Date [10116] x 1
FAIL-NEW: 0     FAIL-INPROG: 0  WARN-NEW: 2     WARN-INPROG: 0  INFO: 0 IGNORE: 0       PASS: 65
```

Two of the three application findings moved into PASS. The third, rule 10049,
now reports Non-Storable Content, which is the same rule confirming the opposite
result. PASS went from 63 to 65.

### Design questions

**e) Why a middleware and not a header set in each handler**

Because the property has to hold for every response, including the ones no
handler writes.

Per-handler code relies on each handler remembering. It is correct on the day it
is written and wrong on the day someone adds a route, and nothing in a review
makes the missing line visible.

A handler also cannot cover what it never sees. The 404 for an unknown path is
written by the router, not by a handler. The test checks `/no-such-path` for
that reason, and it passes only because the middleware wraps the router.

One place also means one value. Eight header calls copied into six handlers is
forty-eight chances to type a slightly different policy.

**f) What `default-src 'none'` breaks, and why it suits an API**

It blocks everything a page would load: scripts, styles, images, fonts, frames,
form targets and outgoing connections. A browser rendering an HTML page under
this policy shows the text and nothing else.

For QuickNotes that is correct. The service returns JSON and never returns HTML,
so there is no page to render and nothing for the policy to break. If an
attacker ever did get HTML into a response, the policy is what stops that HTML
from loading a script. It costs nothing here and removes a whole class of
attack.

On a website it would break the site on the first request. A real site needs an
allowlist built from what it actually loads: its own scripts and styles, its
CDN, its fonts, its analytics. That list has to be written, tested and kept up
to date as the site changes, which is why CSP on a real site is a project and
not a header.

**g) The cost of accepting informational findings without reading them**

The cost is that accepting stops being a decision and becomes a habit.

Three things follow. The next person opens a list where everything is already
accepted and learns that the list does not matter. A real finding that appears
later gets the same treatment, because nothing in the process tells it apart.
And the written reason, which is the only part of triage worth anything six
months later, is missing, so nobody can tell whether the risk was understood or
the row was just closed.

Informational findings are also the ones whose meaning depends on context.
Storable and Cacheable Content is informational, and it was still worth fixing
here, because the responses carry user notes. The same alert on a public price
list would be fine to leave. Reading it is what tells the two apart.
