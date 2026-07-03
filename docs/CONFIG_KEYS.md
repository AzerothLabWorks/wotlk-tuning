# Config Keys

This project writes normal AzerothCore `worldserver.conf` properties. It does
not edit the database in phase 1.

## XP

- `Rate.XP.Kill`
- `Rate.XP.Quest`
- `Rate.XP.Quest.DF`
- `Rate.XP.Explore`
- `Rate.XP.Pet`

## Reputation

- `Rate.Reputation.Gain`
- `Rate.Reputation.LowLevel.Kill`
- `Rate.Reputation.LowLevel.Quest`
- `Rate.Reputation.RecruitAFriendBonus`
- `Rate.Reputation.WSG`
- `Rate.Reputation.AB`
- `Rate.Reputation.AV`

## Drops And Money

- `Rate.Drop.Item.Poor`
- `Rate.Drop.Item.Normal`
- `Rate.Drop.Item.Uncommon`
- `Rate.Drop.Item.Rare`
- `Rate.Drop.Item.Epic`
- `Rate.Drop.Item.ReferencedAmount`
- `Rate.Drop.Item.GroupAmount`
- `Rate.Drop.Money`

`Rate.Drop.Item.ReferencedAmount` and `Rate.Drop.Item.GroupAmount` should be
tuned carefully because they affect grouped/reference loot behavior.

## Skill Gains

- `SkillGain.Crafting`
- `SkillGain.Defense`
- `SkillGain.Gathering`
- `SkillGain.Weapon`

## Character Convenience

- `StartPlayerLevel`
- `StartHeroicPlayerLevel`
- `StartPlayerMoney`
- `StartHeroicPlayerMoney`
- `MinDualSpecLevel`
- `SkipCinematics`

## Performance Profiles

- `GridUnload`
- `MapUpdate.Threads`
- `Network.Threads`
- `ThreadPool`
- `Visibility.Distance.Continents`
- `Visibility.Distance.Instances`

Performance profiles are deliberately small. The goal is to provide a safe first
pass, not to pretend one config can perfectly tune every host.
