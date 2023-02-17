[![Build FG Extension](https://github.com/rhagelstrom/Contaminated/actions/workflows/create-release.yml/badge.svg)](https://github.com/rhagelstrom/Contaminated/actions/workflows/create-release.yml) [![Luacheckrc](https://github.com/rhagelstrom/Contaminated/actions/workflows/luacheck.yml/badge.svg)](https://github.com/rhagelstrom/Contaminated/actions/workflows/luacheck.yml)
# Contaminated

**Current Version:** 1.1
**Last Updated:** 02/17/23

5E extension for FantasyGrounds that adds contamination as a condition as well as immunities to the contamination condition for support of [Dungeons of Drakkenheim](https://ghostfiregaming.com/dungeons-of-drakkenheim/)

This extension also automates the contamination stack by summing contamination levels when applied and decrementing them on long rest. When an actor gains a level of contamination, the mutation table will be rolled on and the result will show if a mutation takes place. The mutation table will need to be entered into FG by the GM, rolled on by the GM and results applied by the GM.

NPC Sheets and spells will automatically parse contamination as a condition with the text "target is contamination" or "gain(s) (N) level(s) of contamination".

| Level | Symptoms |
|-----|--------|
| 1 | None |
| 2 | Hit points regained by spending hit dice halved |
| 3 | No hit points regained at the end of a long rest |
| 4 | Damage dealt by weapon attacks and spells halved |
| 5 | Incapacitated |
| 6 | Monstrous Transformation! |

**Note:** If using SilentRuin's Generic Actions extension, Verify Cast Effect must be set to "off" in that extension

