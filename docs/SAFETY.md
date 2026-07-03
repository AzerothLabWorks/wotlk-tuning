# Safety

The tuner is designed for private server owners who may not be deeply technical.
The safety model is simple:

1. Preview first with `--dry-run`.
2. Back up before every edit.
3. Change only config files in phase 1.
4. Restart worldserver after config changes.
5. Restore the latest tuner backup if needed.

Phase 2 adds named snapshots so you can save a known-good tuning state before
trying several presets.

## Dry Run

Dry run prints intended changes without editing files:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run apply-preset solo-friendly
```

## Backups

Before editing an existing file, the tuner creates a timestamped backup next to
the file:

```text
worldserver.conf.bak.YYYYMMDD-HHMMSS
docker-compose.override.yml.bak.YYYYMMDD-HHMMSS
```

## Named Snapshots

Create a named snapshot before experimenting:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk snapshot before-testing
```

List snapshots:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk list-snapshots
```

Restore a named snapshot:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-snapshot before-testing
```

Snapshots live inside the server folder:

```text
.wotlk-tuner/snapshots/
```

Snapshot names may only contain letters, numbers, dots, dashes, and underscores.

## Restore

Restore the latest tuner backups:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-latest
```

Restore and restart:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-latest --restart
```

## What The Tuner Does Not Back Up

The phase 1 tuner does not back up:

- databases
- characters
- accounts
- source code
- Docker volumes
- map/vmap/mmaps data
- files outside the selected `worldserver.conf` and optional Compose override

Keep your own full server and database backups before tuning a server that
matters to you.
