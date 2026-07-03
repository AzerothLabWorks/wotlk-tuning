# Safety

The tuner is designed for private server owners who may not be deeply technical.
The safety model is simple:

1. Preview first with `--dry-run`.
2. Back up before every edit.
3. Change only config files in phase 1.
4. Restart worldserver after config changes.
5. Restore the latest tuner backup if needed.

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

Keep your own full server and database backups before tuning a server that
matters to you.
