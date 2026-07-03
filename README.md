# WotLK Tuning

Standalone tuning helper for AzerothCore WotLK private servers.

This repo is for server owners who already have an AzerothCore WotLK server and
want an easier way to adjust common gameplay and performance settings such as XP
rates, reputation rates, drop rates, starting money, profession skill gain, and
basic performance profiles.

The tuner focuses on config changes that only need an `ac-worldserver` restart.
It does not edit databases, apply source patches, or rebuild your server.

## Development Status

This project is under active development and should be considered experimental.
It has safeguards such as `--dry-run`, timestamped config backups, confirmation
prompts, and `restore-latest`, but every server install is a little different.

Review the dry-run output before applying changes, keep your own server and
database backups, and test on a non-production copy first when possible.

## What It Tunes

Config tuning includes:

- XP rates for kills, quests, dungeon finder quests, exploration, and pets
- reputation gain rates
- item and money drop rates
- profession, weapon, gathering, and defense skill gain rates
- starting level, starting money, cinematic skipping, and dual spec level
- cautious performance profiles for low, medium, and high-resource hosts
- Docker Compose environment override alignment
- safety checks, timestamped backups, and restore from the latest tuner backup
- plain-English preset inspection with `show-preset`
- compact current-rate diagnostics with `diagnose-rates`
- named config snapshots for safer experimentation
- automatic baseline snapshot before the first tuner apply command
- direct cherry-picked tuning with `apply-custom`

## Requirements

- Bash
- Git
- Docker Compose if you want the tuner to restart `ac-worldserver`
- An AzerothCore WotLK server

On Linux, Steam Deck, and WSL, Bash and Git are usually enough to run the script.
Docker Compose is only required for `--restart` or the `restart` command.

## Step 1: Open A Terminal

Use the terminal environment where you normally manage your server.

For WSL on Windows:

```bash
wsl
```

Then work from your Linux home folder, for example:

```bash
cd ~
```

For Steam Deck desktop mode:

1. Switch to Desktop Mode.
2. Open Konsole.
3. Work from your home folder:

```bash
cd ~
```

For a normal Linux server:

```bash
cd ~
```

## Step 2: Download The Tuner

Recommended method:

```bash
git clone https://github.com/AzerothLabWorks/wotlk-tuning.git
cd wotlk-tuning
```

To update later:

```bash
cd ~/wotlk-tuning
git pull
```

If you do not have Git, download the ZIP from GitHub:

```text
https://github.com/AzerothLabWorks/wotlk-tuning
```

Click `Code`, then `Download ZIP`, extract it, and open a terminal inside the
extracted folder.

## Step 3: Find Your Server Directory

The `--server-dir` value must point to your AzerothCore WotLK server folder, not
to this tuner repo.

Examples:

```bash
~/azerothcore-wotlk
~/wow-server
~/wow-server-playerbots
~/Servers/azerothcore-wotlk
```

You can verify a likely folder with:

```bash
ls ~/azerothcore-wotlk
ls ~/azerothcore-wotlk/env/dist/etc
ls ~/azerothcore-wotlk/docker-compose.yml
```

Use the folder that contains your server files. Docker-based installs usually
have `docker-compose.yml`; compiled installs usually have `env/dist/etc` or
`env/dist/configs`.

On WSL, avoid pointing the tuner at a Windows path unless your server actually
lives there. A Linux-side server path is usually better:

```bash
~/azerothcore-wotlk
```

rather than:

```bash
/mnt/c/Users/YourName/Desktop/azerothcore-wotlk
```

On Steam Deck, your server may be under custom folders such as:

```bash
~/Games/azerothcore-wotlk
~/Servers/azerothcore-wotlk
```

## Step 4: Run A Safety Check

From inside the `wotlk-tuning` folder:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk doctor
```

If your server is somewhere else, change the path:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/YOUR-SERVER-FOLDER doctor
```

`doctor` prints the config it found, common tuning values, Docker override values,
and safety notes.

## Step 5: Preview Changes First

Always run `--dry-run` first. This prints what the tuner would change without
editing files or restarting anything.

Solo-friendly private server:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run apply-preset solo-friendly
```

Fast leveling:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run apply-preset fast-leveling
```

Alt-friendly:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run apply-preset alt-friendly
```

## Step 6: Apply A Preset

When the dry run looks correct, run the same command without `--dry-run`.

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-preset solo-friendly
```

The first time you apply a preset, custom change, or defaults, the tuner
automatically saves a snapshot named:

```text
baseline-before-wotlk-tuner
```

Use this if you want to return to the settings your server had before this tuner
made its first change:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-baseline
```

To apply and restart `ac-worldserver` in one command:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-preset solo-friendly --restart
```

If you want a different XP rate than the preset default:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-preset fast-leveling --xp 3 --restart
```

If you want a Steam Deck or lower-resource profile:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-preset solo-friendly --performance low --restart
```

## Cherry-Pick Adjustments

You do not have to use a full preset. Use `apply-custom` when you only want to
change specific values.

Examples:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run apply-custom --xp 2
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-custom --xp 2 --rep 3 --money 2
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-custom --kill-xp 1.5 --quest-xp 3
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-custom --drop 2 --money 3
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-custom --honor 3 --arena 3
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-custom --repair-cost 0.5 --dual-spec-level 20
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-custom --performance low
```

Supported cherry-pick options:

- `--xp`, `--kill-xp`, `--quest-xp`, `--explore-xp`, `--pet-xp`
- `--rep`
- `--drop`, `--referenced-drop`, `--group-drop`
- `--money`
- `--skill`
- `--honor`, `--arena`
- `--repair-cost`
- `--start-level`, `--start-money`, `--dual-spec-level`
- `--skip-cinematics`
- `--instance-reset`
- `--performance low|medium|high`

You can also combine a preset with overrides. This applies the preset first, then
your overrides:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-preset fast-leveling --xp 3 --money 2
```

Use `diagnose-rates` after any change to confirm the final values.

## Presets

`blizzlike`

Conservative AzerothCore defaults for common tuning keys. This is useful as a
baseline if you want to move back toward normal rates.

`solo-friendly`

2x XP and reputation, modest drops, cheaper repairs, easier dual spec, and
cinematic skipping. Good for one player or a small private group.

`fast-leveling`

5x XP with modest reputation, skill, and money support. Good when players want to
reach later zones quickly without turning every drop into a loot explosion.

`alt-friendly`

3x XP, faster skills, starter money, earlier dual spec, and skipped cinematics.
Good for players who make many characters.

`loot-rich`

More item drops and money for casual private servers. This also adjusts reference
and group amount rates conservatively, so test this one before using it on a
server you care about.

`reputation-friendly`

Faster faction progress with modest leveling support and battleground reputation
boosts.

Show presets:

```bash
./scripts/wotlk-tuner.sh list-presets
```

Inspect one preset before applying it:

```bash
./scripts/wotlk-tuner.sh show-preset casual-weekend
```

Additional Phase 2 presets:

`casual-weekend`

Relaxed 3x pacing for short play sessions.

`profession-friendly`

Fast profession and gathering progression with moderate leveling support.

`pvp-friendly`

Boosts honor, arena points, and battleground reputation.

`group-friendly`

Small-group and dungeon-friendly loot and reset pacing.

`hardcore-lite`

Slower progression, leaner drops, and higher repair cost without adding database
or source-code hardcore rules.

## Performance Profiles

Performance profiles are intentionally conservative. They tune a small set of
server-side settings that are easy to understand and easy to restore.

```bash
./scripts/wotlk-tuner.sh list-performance
```

Suggested starting points:

- Steam Deck, older laptop, small VPS, or modest WSL install: `--performance low`
- Average desktop/server: `--performance medium`
- Strong host with spare CPU and memory: `--performance high`

## Useful Commands

```bash
./scripts/wotlk-tuner.sh list-presets
./scripts/wotlk-tuner.sh show-preset casual-weekend
./scripts/wotlk-tuner.sh list-performance
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk doctor
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk diagnose-rates
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk snapshot before-testing
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run apply-preset solo-friendly
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-preset fast-leveling --xp 3 --restart
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-snapshot before-testing
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-latest
```

## Diagnostics

Use `diagnose-rates` to show current tuning values in one compact report:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk diagnose-rates
```

This is useful before and after applying presets, or when helping someone else
understand how their server is currently tuned.

## Defaults, Snapshots, Backups, And Restore

There are two different ways to go back:

- `restore-baseline` restores the automatic snapshot from before this tuner first
  changed your server.
- `apply-defaults` writes conservative AzerothCore-style default values for the
  common tuning keys this tool manages.

For most people, `restore-baseline` is the safer “undo my tuner experiment”
choice:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-baseline
```

Use `apply-defaults` when you specifically want common tuning keys set back to
default-style values:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run apply-defaults
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-defaults --restart
```

Named snapshots are best before experimenting:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk snapshot before-fast-leveling
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk list-snapshots
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-snapshot before-fast-leveling
```

Snapshots save:

- `worldserver.conf`
- `docker-compose.override.yml` when it exists

They are stored under your server folder in:

```text
.wotlk-tuner/snapshots/
```

Timestamped backups are still created automatically before tuner edits.

Before editing an existing config or Docker override, the script creates a
timestamped backup next to the file:

```text
worldserver.conf.bak.YYYYMMDD-HHMMSS
docker-compose.override.yml.bak.YYYYMMDD-HHMMSS
```

Preview restore:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run restore-latest
```

Restore the latest tuner-created backups:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-latest
```

Restore and restart `ac-worldserver`:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-latest --restart
```

Use `--yes` if you want to skip confirmation prompts:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-latest --restart --yes
```

`restore-latest` restores the newest tuner-created backups for:

- `worldserver.conf`
- `docker-compose.override.yml`

It does not reset databases, source code, account data, or character data.

## WSL Notes

Recommended flow:

```bash
wsl
cd ~
git clone https://github.com/AzerothLabWorks/wotlk-tuning.git
cd wotlk-tuning
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk doctor
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run apply-preset solo-friendly
```

If your Docker Desktop integration is enabled for WSL, `--restart` should work
from WSL. If Docker commands fail, run:

```bash
docker compose version
docker ps
```

If those fail too, fix Docker/WSL integration before using tuner commands that
need Docker.

## Steam Deck Notes

Steam Deck runs SteamOS, which is Linux-based. The tuner should be run from
Desktop Mode using Konsole.

Recommended flow:

```bash
cd ~
git clone https://github.com/AzerothLabWorks/wotlk-tuning.git
cd wotlk-tuning
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk doctor
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run apply-preset solo-friendly --performance low
```

If Docker is not installed or not running on the Steam Deck, you can still use
the tuner to edit config files, but `--restart` will not work until Docker
Compose is available.

## Restart vs Rebuild

Restart-only changes:

- presets
- XP, reputation, drop, money, and skill rates
- start level and start money
- dual spec level and cinematic settings
- performance profiles
- restoring config backups

Rebuild-required changes:

- none in phase 1

Database changes:

- none in phase 1
