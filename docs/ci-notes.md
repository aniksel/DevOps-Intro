# CI notes

The PR gate for QuickNotes lives in `.github/workflows/ci.yml`.

- `changes` decides whether anything under `app/` or `.github/workflows/`
  actually changed in the pull request; everything else is documentation and
  does not need a build.
- `vet`, `test` and `lint` do the real work and run only when it did.
  `vet` and `test` run against Go 1.23 and 1.24 in parallel.
- `ci-ok` aggregates the results and is the single check required by branch
  protection on `main`, so the matrix can change without anyone editing the
  protection settings.

This file is documentation only — pushing it should leave `vet`, `test` and
`lint` skipped.
