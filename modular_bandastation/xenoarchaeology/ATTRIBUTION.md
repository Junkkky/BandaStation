# Источники ксеноархеологии

Код и спрайты портированы из [Voidcrew PR #506](https://github.com/voidcrew/Voidcrew/pull/506)
(Jackriip и участники Voidcrew, коммит `cfde23a6397c667b73e73a680a503b425bf3a169`, AGPL-3.0).
Voidcrew собрал их из NovaSector (порт TauCeti), Polaris и VOREStation; спрайты — под CC BY-SA 3.0.
Источники состояний ниже указаны по комментариям донора в `artifact_appearance.dm` и `specimen_crate.dm`.

## `icons/artifacts.dmi`

| Состояния | Источник |
| --- | --- |
| `pylon`, `terminal`, `vents`, `growth`, `crystal_green`, `crystal_violet`, `crystal_blue` (+ `_active`) | NovaSector `5ce2bd2215c0`, `artifacts.dmi`, состояния 7–13 |
| `torus`, `monolith`, `spire`, `idol`, `cradle`, `effigy`, `spindle` (+ `_active`) | Polaris `6cd19fe0dec6`, `xenoarchaeology.dmi`: `ano10`, `ano70`, `ano80`, `ano120`, `ano130`, `ano140`, `ano150` |
| `shard` | Aurora, `crystal_madness` |
| `shard_active` | нарисован для Voidcrew на основе `crystal_madness` |
| `label_tag` | [Voidcrew PR #506](https://github.com/voidcrew/Voidcrew/pull/506) |

Донор сообщает, что состояния, восходящие к Goonstation (Nova `artifact_1`–`6`, Bay/Polaris
`ano00`/`20`/`30`/`40`/`50`), не используются.

## `icons/specimen_crate.dmi`

Перекраска ящика /tg/station (`icons/obj/storage/crates.dmi`, `crate`/`crateopen`) для Voidcrew;
состояния `manifest` и `welded` скопированы из того же файла /tg/station.
