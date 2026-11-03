# Источники кораблей овермапы

Атрибуция кораблей `overmap_ships`. Механики кораблей указаны в
[space_overmap/ATTRIBUTION.md](../space_overmap/ATTRIBUTION.md). Карты лежат в
`_maps/map_files/overmap_ships/`; пути в таблице — от корня репозитория.

## Лицензии и авторы

Исходный код и адаптации используют GNU AGPL v3; полный текст находится в
корневом [LICENSE](../../LICENSE). Для планировок и графики сохраняется CC BY-SA 3.0;
включённый исходный код сохраняет лицензию кода донора.

| Источник и авторы | Версия и лицензионная политика |
| --- | --- |
| Void-Crew/Voidcrew-LRP, участники Voidcrew, Shiptest, Whitesands и TG | [66c552922bf2a28963c2a8f5d89993623a141a1f](https://github.com/Void-Crew/Voidcrew-LRP/blob/66c552922bf2a28963c2a8f5d89993623a141a1f/README.md#license) |
| CeladonSS13/Shiptest, участники Celadon, Shiptest, Whitesands и TG | [4214796c7289b74779f10dd25df2d695c264aa8f](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/README.md) |
| TG, BandaStation и Primera contributors | [65a9bd040b816783f0b6c24ba1e84ee7aab48456](https://github.com/SpaceStation220/Primera/blob/65a9bd040b816783f0b6c24ba1e84ee7aab48456/README.md#license) |

[Полный текст CC BY-SA 3.0](../space_overmap/LICENSE-ASSETS-CC-BY-SA-3.0.txt),
[официальная страница лицензии](https://creativecommons.org/licenses/by-sa/3.0/).
Указание авторства не означает одобрения этой адаптации исходными проектами.

## Корабли

| Локальный файл | Источник |
| --- | --- |
| `_maps/map_files/overmap_ships/pocketrocket.dmm` | [_maps/shuttles/shiptest/voidcrew/pocketrocket.dmm](https://github.com/Void-Crew/Voidcrew-LRP/blob/66c552922bf2a28963c2a8f5d89993623a141a1f/_maps/shuttles/shiptest/voidcrew/pocketrocket.dmm) |
| `_maps/map_files/overmap_ships/raven.dmm` | [_maps/shuttles/emergency/emergency_raven.dmm](https://github.com/SpaceStation220/Primera/blob/65a9bd040b816783f0b6c24ba1e84ee7aab48456/_maps/shuttles/emergency/emergency_raven.dmm); переработка: планировка Junkkky, тритиевая камера сгорания и оборудование овермапы |

Несовместимые объекты, механизмы, обитатели и лут заменены местными типами.
Изолированы area и управляющие ID. На кораблях добавлены навигация, транспондеры,
терминалы переходов и порты.

`modular_bandastation/overmap_ships/icons/raven_areas.dmi` — собственная работа
StationTrauma / BandaStation contributors, CC BY-SA 3.0: иконки отсеков Raven,
видимые только в маппере.

## Корабли Celadon

| Локальный файл | Источник CeladonSS13/Shiptest |
| --- | --- |
| `_maps/map_files/overmap_ships/venture.dmm` | [_maps/_mod_celadon/shuttles/nanotrasen/nanotrasen_venture.dmm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/_mod_celadon/shuttles/nanotrasen/nanotrasen_venture.dmm) |
| `_maps/map_files/overmap_ships/bubble.dmm` | [_maps/_mod_celadon/shuttles/independent/independent_bubble.dmm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/_mod_celadon/shuttles/independent/independent_bubble.dmm) |
| `_maps/map_files/overmap_ships/glimpse.dmm` | [_maps/_mod_celadon/shuttles/solfed/solfed_glimpse.dmm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/_mod_celadon/shuttles/solfed/solfed_glimpse.dmm) |
| `_maps/map_files/overmap_ships/kilo.dmm` | [_maps/_mod_celadon/shuttles/independent/independent_kilo.dmm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/_mod_celadon/shuttles/independent/independent_kilo.dmm) |

Планировки сохранены. Штурвал стал навигационной консолью, двигатели — штатными двигателями шаттла,
консоль карго — консолью блюспейс-перехода; добавлены транспондер и порт овермапы. Топливная
инфраструктура Shiptest, корабельные турели и несовместимые объекты удалены или заменены местными типами.

[ASSETS.json](ASSETS.json) перечисляет карты кораблей с permalink, коммитами и SHA-256
исходников и локальных файлов.
