# PocketFlow

## Getting started

```sh
make get        # install packages
make run        # run the app (dev)
make preview    # widget previewer
make check      # format + analyze + tests
make help       # all targets
```

## Project layout

- `lib/features/` — one folder per feature (page → state → views/widgets). See `docs/new-feature-guidelines.md`.
- `lib/data/repositories/` — shared data access
- `lib/ui/` — theme, preview helper, shared widgets
- `test/` — mirrors `lib/`; golden tests are tagged `golden`

## Golden tests

Goldens must be generated on Linux to match CI:

- `make docker-setup` once, then `make test update-goldens`, or
- run the **CI** workflow manually with `update_goldens` checked
