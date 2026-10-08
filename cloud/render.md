# Render service configuration

The service that runs QuickNotes on Render. Everything below was set in the
dashboard when the service was created, and nothing here is a secret.

| Setting | Value |
|---|---|
| Service type | Web Service |
| Name | `quicknotes:0.1.0` |
| Public URL | https://quicknotes-0-1-0.onrender.com |
| Instance type | Free |
| Region | Frankfurt |
| Source | Existing Image |
| Image | `ghcr.io/aniksel/devops-intro/quicknotes` |
| Image tag at creation | `0.1.0` |
| Health Check Path | `/health` |

## Environment variables

| Name | Value | Why |
|---|---|---|
| `PORT` | `8080` | Render sends traffic to the port in this variable, and it defaults to 10000. |
| `ADDR` | `:8080` | The address QuickNotes binds to. It already defaults to `:8080`, but setting it makes the pair explicit, so the two can never drift apart silently. |

Both are set so the first boot already agrees on a port. The deploy log shows
`quicknotes listening on :8080` and goes straight to `Your service is live`,
with no `New primary port detected` restart.

## Source choice

The service runs the image that CI built, not a build of its own from the Git
repository. Three reasons.

The image that runs in production is then byte for byte the image that Lab 9
scanned with Trivy and ZAP. If Render rebuilt it, the thing scanned and the
thing serving traffic would be two different builds.

The build already happens once in CI, on a runner with a layer cache. Letting
Render build it again would repeat the same work on a slower free instance.

And the tag is immutable. `v0.1.2` is one digest forever, so a rollback is a
tag change and not a rebuild of whatever the branch happens to contain today.

## Deploy from CI

A tag push runs [.github/workflows/release.yml](../.github/workflows/release.yml),
which pushes the image and then calls the service deploy hook with the new tag:

```bash
encoded="$(printf '%s' "$IMAGE" | jq -sRr @uri)"
curl -sS -o /dev/null -w '%{http_code}' "${RENDER_DEPLOY_HOOK}&imgURL=${encoded}"
```

The hook URL carries a secret key, so it lives in the GitHub Actions secret
`RENDER_DEPLOY_HOOK` and never in the repository. The `imgURL` parameter has to
be percent encoded, and only the tag may differ from the image the service was
created with: anything else, including a difference in letter case, is answered
with HTTP 400.
