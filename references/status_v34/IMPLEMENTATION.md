# v34 shared status and target feedback

Scope: the unchanged historical 5834 Mage/Warlock 27-card union and coin/sheep/mirror tokens. Rendering assets and controller evidence come from the same verified modern build 37.0.0.255130.254477. This is a native Godot migration, not execution of the original client or a pixel-identical claim.

## Source-backed scope

- TargetReticleManager prefab chain: original bullseye/tip and 15 cached dash objects. Source spacing, parabola, pitch, alpha fade and retained animation offset. Original valid bullseye toggles only the ring, retaining the tip. Invalid targeting does not recolor the arrow or create a prohibited sign.
- Invalid target input retains targeting with unchanged mana, cards, readiness, health and rules RNG; explicit right-click/Escape clears, valid target commits exactly once.
- Frozen minion and hero: original Actor spell-table type14, tag260, original source mesh, material, particles and Birth/Death FSM. The minion remains in its EnableIce source state rather than an invented Idle state. Death clears ice meshes and runs original 3-second shatter tail.
- Sleep: original type52 Zzz particle asset, not font-drawn letters. The IsAsleep source condition is separate from attack exhaustion and does not exclude frozen. Status adapter corrections after the preliminary sample are tracked in QA.
- Taunt: original type8 model, particles, material and source FSM. Source prefab scales and local hierarchy attach to the actual minion actor.
- Corruption: the real 5834 pending enchantment remains in the rules. Same-build CS2_063e has empty persistent play/lifetime/death effect references; the finite original skull impact remains in combat. The old fabricated persistent text label is removed.
- Deathrattle: unreachable in these recipes/tokens. EX1_556 is only a retained legacy definition and is not advertised as current-pool coverage.

## Explicit boundaries

The board has no recovered original camera. Source local geometry is registered through the existing 15-degree projection. Source shader ambient/light globals are not available; existing fixed-board ambient and main light are the compatibility inputs. Particle simulation and GL color/blend bridges are native Godot compatibility implementations. Original source equations and resource identities are separately recorded.

The first screenshot milestone is not the final status acceptance: golden eligibility silhouettes, exact taunt departure curves, source sleep overlap and any discovered render issues are verified separately before completion. Existing BGM, audio dispatch, endgame and rules are not replaced by this feature.
