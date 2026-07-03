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

The tuner also creates one automatic baseline snapshot before the first command
that changes server tuning:

```text
baseline-before-wotlk-tuner
```

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

The automatic baseline snapshot is the easiest way to undo tuner experiments:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-baseline
```

This restores the config state from before the tuner first applied a preset,
custom override, or default reset.

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

## Default Values

`apply-defaults` is different from `restore-baseline`.

`restore-baseline` restores your server's pre-tuner values. This may include your
own custom settings.

`apply-defaults` writes conservative default-style values for common tuning keys:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run apply-defaults
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-defaults
```

Use `restore-baseline` when you want to undo tuner changes. Use `apply-defaults`
when you intentionally want to move managed tuning keys back toward normal
AzerothCore values.

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
