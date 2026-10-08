# Teardown

Nothing in this lab costs money, but here is how to remove it.

## Render service

1. Open the service in the Render dashboard.
2. **Settings**, scroll to the bottom, **Delete Web Service**.
3. Suspending instead keeps the configuration and stops the instance:
   **Settings**, **Suspend Web Service**.

A free instance that is simply left alone spins down after 15 idle minutes and
bills nothing, so leaving it is also a valid end state.

## Container image on ghcr.io

1. https://github.com/aniksel?tab=packages, open `DevOps-Intro/quicknotes`.
2. **Package settings**, **Danger Zone**, delete a single version or the whole
   package.

Deleting the package breaks the Render service, because the image it pulls
disappears. Delete the service first.

## GitHub Actions secret

Remove `RENDER_DEPLOY_HOOK` at
https://github.com/aniksel/DevOps-Intro/settings/secrets/actions once the
service is gone. The hook is useless without it, but a dead secret is still a
credential sitting in a repository.

## Local

```bash
docker compose down
docker rmi ghcr.io/aniksel/devops-intro/quicknotes:0.1.0
```
