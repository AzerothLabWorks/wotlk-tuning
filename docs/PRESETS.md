# Presets

Presets are starting points. They are intentionally conservative enough for a
private server owner to understand, preview, and restore.

Use `--dry-run` before applying any preset:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk --dry-run apply-preset solo-friendly
```

## blizzlike

Returns common tuning keys to conservative AzerothCore-style defaults.

Primary intent:

- undo common rate tuning
- establish a known baseline
- keep the game close to normal WotLK pacing

## solo-friendly

Good first preset for one player or a small group.

Primary intent:

- reduce leveling friction
- avoid extreme item or money inflation
- make dual spec available earlier
- reduce repair pain

Default flavor:

- 2x XP
- 2x reputation
- 1.5x item drops
- 2x money
- 1.5x skill gains

## fast-leveling

Good for players who want to reach later zones quickly.

Primary intent:

- make leveling fast
- keep loot relatively restrained
- support professions and reputation enough to keep pace

Default flavor:

- 5x XP
- 2x reputation
- 1x item drops
- 2x money
- 2x skill gains

## alt-friendly

Good for private servers where players create many characters.

Primary intent:

- make repeated leveling smoother
- speed up professions
- provide starter money
- skip repeated cinematics

Default flavor:

- 3x XP
- 2x reputation
- 1.5x item drops
- 3x money
- 3x skill gains
- 10 gold starting money

## loot-rich

Good for casual servers where players enjoy frequent drops.

Primary intent:

- increase item drops
- increase money
- support relaxed private-server play

This preset also adjusts `Rate.Drop.Item.ReferencedAmount` and
`Rate.Drop.Item.GroupAmount` conservatively. Test it before using it on a server
you care about, because referenced loot affects boss and grouped loot behavior.

## reputation-friendly

Good for players who enjoy faction rewards but dislike long reputation grinds.

Primary intent:

- speed up faction progress
- boost WSG, AB, and AV reputation gains
- keep leveling moderately boosted

## casual-weekend

Good for players who only have short play sessions and want relaxed private
server pacing.

Primary intent:

- keep leveling, reputation, money, and loot moving
- reduce repeat-start friction
- make dual spec available early

Default flavor:

- 3x XP
- 3x reputation
- 2x item drops
- 3x money
- 2x skill gains

## profession-friendly

Good for players who like crafting, gathering, and self-sufficiency.

Primary intent:

- speed up profession catch-up
- keep leveling moderate
- make gathering and weapon skill gains less grindy

Default flavor:

- 2x XP
- 2x reputation
- 1.5x item drops
- 2x money
- 5x skill gains
- higher orange, yellow, and green skill-up chances

## pvp-friendly

Good for private servers where battlegrounds or arenas are part of the fun but
rewards need to move faster.

Primary intent:

- boost honor and arena points
- boost WSG, AB, and AV reputation
- make dual spec available earlier

Default flavor:

- 2x XP
- 2x reputation
- 3x honor
- 3x arena points
- 3x battleground reputation

## group-friendly

Good for small groups running dungeons together.

Primary intent:

- improve group loot pacing
- reduce repair pain
- make instance resets friendlier

Default flavor:

- 2x XP
- 2x reputation
- 2x item drops
- 2x money
- 1.25x referenced/grouped loot amount
- 0.5x instance reset time

## hardcore-lite

Good for players who want slower progression without adding database rules,
permadeath, or source patches.

Primary intent:

- slow leveling slightly
- reduce loot and money
- make repairs matter more

Default flavor:

- 0.75x XP
- 1x reputation
- 0.75x item drops
- 0.75x money
- 1.5x repair cost

## Common Overrides

Any preset can be customized:

```bash
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-preset fast-leveling --xp 3
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-preset solo-friendly --rep 4
./scripts/wotlk-tuner.sh --server-dir ~/azerothcore-wotlk apply-preset alt-friendly --start-money 500000
```

Decimal values use a period:

```bash
--drop 1.5
```

Do not use a comma:

```bash
--drop 1,5
```
