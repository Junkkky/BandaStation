# Legendary sword assets

Imported from [BandaStation #2461](https://github.com/ss220club/BandaStation/pull/2461), commit `df77130c6ede3bb27b1f55993e19118c18c703ca`.

- **Dark Star** sprites (`ds_dualsaber0`, `ds_dualsaberdarkstar1` in `icons/melee/legendary.dmi` and both `icons/melee/inhands` files): **Mooniverse**.
- **Dark Star** and **Liar** sounds (`sound/melee/ds_saber_*.ogg`, `sound/melee/lz_saber_*.ogg`): **Fullonibus**.
- **Liar** sprites (`lz_dualsaber0`, `lz_dualsaberliar1` in the same DMI files): **author not yet identified**. Attribution must be completed before this draft is merged.

The known credits above were confirmed by Fullonibus on 2026-10-30. The source PR did not record the Liar sprite author.

## Malice

The five action icons in `icons/melee/legendary_abilities.dmi` were drawn for this build using the open Malice saber, `mid_dualsabermidnight1`. The base item and in-hand sprites came from the Paradise port in [BandaStation #1092](https://github.com/ss220club/BandaStation/pull/1092).

The effects in `icons/melee/malice_rage.dmi`, `malice_critical_strike.dmi` and `malice_guard.dmi` adapt those sprites for the charged strike, its impact and the frontal guard. The spinning trails in `malice_spin.dmi` and the three directional cuts in `malice_harvest.dmi` were drawn for these abilities. The artwork follows the repository's CC BY-SA 3.0 asset license.

`icons/melee/malice_recall.dmi` contains original pixel animations for the blade opening and sparks at the catch. Its action icon shows the open Malice item sprite credited above arcing toward a gloved hand. The icon uses the same CC BY-SA 3.0 license.

The supplied recordings listed below are by **konu_shi**. Permission to use these recordings, including in the mixes listed here, is limited to SS220.

| Game sound in `sound/melee/` | Source recordings |
| --- | --- |
| `malice_dance.ogg` | `kylohup1.mp3`, `kylohup2.mp3` and `kylohup3.mp3` (the “Two Blades” rotation) |
| `malice_dance_hit.ogg` | `kylohit3.mp3`, also supplied as `kylohit3 (1).mp3` (shared by Dance and Shadow) |
| `malice_rage_cry.ogg` | The existing Malice blade sounds and `midnight scream.wav` |
| `malice_rage_hit.ogg` | `kylobounce2.mp3` |
| `malice_harvest_hit1.ogg` | The existing `mid_saberhit.ogg`, `kylohit3.mp3` and `kylohup1.mp3` |
| `malice_harvest_hit2.ogg` | `mid_saberhit.ogg`, `kylobounce2.mp3` and `kylohup2.mp3` |
| `malice_harvest_hit3.ogg` | `mid_saberhit.ogg`, `kylohit3.mp3`, `kylobounce2.mp3` and `kylohup3.mp3` |
| `malice_guard_spin.ogg` | `kylohup1 (1).mp3` (rotation) |
| `malice_guard_block.ogg` | `kylohup1 (1).mp3` and `kyloblock1.mp3` (parry) |
| `malice_recall_launch.ogg` | The existing `mid_saberon.ogg` and `kylohup3.mp3` |
| `malice_recall_flight.ogg` | `kylohup1.mp3`, `kylohup2.mp3` and `kylohup3.mp3` |
| `malice_recall_hit.ogg` | The existing `mid_saberhit.ogg`, `kylohit3.mp3` and `kylobounce2.mp3` |
| `malice_recall_catch.ogg` | `kyloblock1.mp3` and `kylohup1.mp3` |

## Light Sister

The three action icons and the `sister_*` sprites in `icons/melee/` adapt Light Sister's Normandy blade (`norm_dualsabernormandy1`) and its in-hand sprites. The gauntlet grip, blade glint, dome, embedded blade and Dawn aura were drawn for these abilities. The artwork follows the repository's CC BY-SA 3.0 asset license.

The dome and Silver Sting sound effects use the original Normandy ignition, power-down and impact recordings (`norm_saberon.ogg`, `norm_saberoff.ogg` and `norm_saberhit.ogg`). **mnvrse** is the author of the additional recording mixed into `sister_dome_open.ogg` and the three recordings used for `sister_dawn.ogg` (`saberon_savage.mp3`, `saberoff_savage.mp3` and `saberbodyhit3.mp3`).

# Legacy display revolvers

The `anaconda` and `rsh12` sprites in `icons/ranged/ballistic.dmi`, and the added revolver states in `icons/ranged/inhands/ballistic/{lefthand,righthand}.dmi`, were imported from [BandaStation #2756](https://github.com/ss220club/BandaStation/pull/2756), commit `f1089abd748be433a1ebc8cb826673c86f4a29e9` by Ingakem. The source PR is the asset provenance; these resources follow BandaStation's CC BY-SA 3.0 asset license.

# Exploreverse Mk.III

The `laser_gate_mk3`, `laser_gate_mk3_charge1`…`_charge4`, `laser_gate_mk3_empty` and `laser_gate_mk3_nomag` states in `icons/ranged/energy.dmi` are cut from the laser carbine sprites (`laser`, `laser0`…`laser100`) of [SierraBay/SierraBay12 `icons/obj/guns/laser_carbine.dmi`](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/guns/laser_carbine.dmi), commit `c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037`: the base is the empty-charge frame, the charge and empty overlays are the indicator pixels of each level, and the no-magazine body has the indicator strip removed; no other pixel or timing changes. Authorship belongs to the SierraBay/Baystation contributors; CC BY-SA 3.0.

The `exploreverse_battery` and `exploreverse_battery_charge1`…`_charge3` states were drawn for this repository in the carbine's palette.

`sound/ranged/exploreverse_mk3_fire.ogg` is [prifle_flash0_by_OnlyTheGhosts.wav](https://freesound.org/people/onlytheghosts/sounds/251430/) by **OnlyTheGhosts** on Freesound, licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), converted from WAV to Ogg Vorbis without other changes.
