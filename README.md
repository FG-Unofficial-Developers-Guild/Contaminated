
# Contaminated

[![Build FG Extension](https://github.com/rhagelstrom/Contaminated/actions/workflows/create-release.yml/badge.svg)](https://github.com/rhagelstrom/Contaminated/actions/workflows/create-release.yml) [![Luacheckrc](https://github.com/rhagelstrom/Contaminated/actions/workflows/luacheck.yml/badge.svg)](https://github.com/rhagelstrom/Contaminated/actions/workflows/luacheck.yml) [![Markdownlint](https://github.com/rhagelstrom/Contaminated/actions/workflows/markdownlint.yml/badge.svg)](https://github.com/rhagelstrom/Contaminated/actions/workflows/markdownlint.yml)

**Current Version:** ~dev_version~ \
**Updated:** ~date~

**Overview:**
Contaminated is a 5E extension for Fantasy Grounds that introduces contamination as a condition, alongside immunities to it. This extension supports the [Dungeons of Drakkenheim](https://ghostfiregaming.com/dungeons-of-drakkenheim/) campaign.

## Features

- **Contamination Automation:** Automatically sums contamination levels when applied and decrements them during a long rest.
- **Mutation Table Integration:** When an actor gains a level of contamination, a mutation table is rolled, and the GM applies the results.
- **NPC and Spell Parsing:** Automatically processes contamination in NPC sheets and spells, using phrases like "target is contaminated" or "gain(s) (N) level(s) of contamination".
- **Calendar of Saint Tarna:** Added the calendar of Drakkenheim.

> **Note**: If using SilentRuin's Generic Actions extension, ensure **Verify Cast Effect** is set to "off".

## Contamination Levels and Symptoms

| Level | Symptoms |
| --- | --- |
| 1 | None |
| 2 | Hit points regained by spending hit dice halved |
| 3 | No hit points regained at the end of a long rest |
| 4 | Damage dealt by weapon attacks and spells halved |
| 5 | Incapacitated |
| 6 | Monstrous Transformation! |
