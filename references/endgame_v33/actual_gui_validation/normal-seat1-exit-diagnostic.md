# Normal-input seat1 exit -9: preserved failure and scoped static checks

The frozen candidate reached turn10 using the original seed19032/input policy, with turn8[26,22],turn9[20,18],turn10[13,12] matching the earlier baseline. After playing Arcane Missiles, the process exited -9 at553.48 wall seconds. The run did not reach a normal-game ending and is not a passed normal GUI run.

Observed peak RSS was2,693,852KiB. The parent process chain stayed present. All requested cgroup memory.events/max observations returned FileNotFound. A separate six-case terminal matrix ran605.48seconds successfully in the same host, so a universal553-second tool timeout is not supported. Exit-9 alone cannot prove an out-of-memory cause.

Read-only particle/source diagnosis:
- The combat_v32 source manifest and runtime routes remain byte-identical to v32.1.
- Its178 particle systems contain only7 nonempty subemitter edges, all Birth(type0). No Death(type2) or enabled randomized Force exists in this old combat library.
- Arcane Missiles has10 particle systems across start/missile/impact, all with SubModule disabled. The new Death/Force support therefore does not introduce a new Arcane recursion path.
- Original looping rates are start10.58/s+2/s and missile3×110/s. Source end paths remain start0.1sStop/1.1sNone, missile1sNone, impact2sNone; generic effect expiry disposes its container.
- Retaining historical particles and speed segments until destruction predates v33. Missing disposal could still cause growth, but no active-effect/heap snapshot proves such a failure in this run.
- The new screen-size cap adds projection/temporary CPU work, not particle or vertex counts. All old combat minimum caps are0, so it cannot expand these billboard sizes.
- RSS rose only1748KiB between turn4 andturn7 (~195seconds), and216KiB between turn10 start and the final live sample (~16seconds). The successful earlier turn2 Arcane interval rose110892KiB.

No causal claim about the process kill is established. This failed run remains separate from the successful six-case final matrix and the shorter normal-input fallback run. No production change was made to evade the failure.
