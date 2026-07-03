# Custom Adjustments

Use `apply-custom` when you want to cherry-pick settings instead of applying a
full preset.

Always preview first:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run apply-custom --xp 2 --rep 3
```

Then apply:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-custom --xp 2 --rep 3
```

## Common Examples

Only change all XP rates:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-custom --xp 2
```

Make quests faster than kills:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-custom --kill-xp 1.5 --quest-xp 3
```

Boost reputation and money:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-custom --rep 3 --money 2
```

Boost PvP rewards:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-custom --honor 3 --arena 3
```

Make alts less tedious:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-custom --dual-spec-level 20 --skip-cinematics 2 --start-money 100000
```

Use a lower-resource performance profile:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-custom --performance low
```

## Combining Presets And Overrides

You can apply a preset and override some values in the same command:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-preset fast-leveling --xp 3 --money 2
```

The preset is applied first. Your custom values are applied afterward.

## Check The Result

After any change, run:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk diagnose-rates
```

## Revert Options

Return to your automatic pre-tuner baseline:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk restore-baseline
```

Apply conservative default-style values for common tuning keys:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-defaults
```
