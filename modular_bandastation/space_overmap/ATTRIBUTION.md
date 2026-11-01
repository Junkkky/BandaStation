# Источники космической овермапы

Атрибуция новых материалов `space_overmap`. Общая навигация указана в
[overmap/ATTRIBUTION.md](../overmap/ATTRIBUTION.md), биомы — в
[expedition_planets/ATTRIBUTION.md](../expedition_planets/ATTRIBUTION.md), корабли — в
[overmap_ships/ATTRIBUTION.md](../overmap_ships/ATTRIBUTION.md), руины — в
[overmap_ruins/ATTRIBUTION.md](../overmap_ruins/ATTRIBUTION.md).

## Лицензии и авторы

Исходный код и адаптации используют GNU AGPL v3; полный текст уже находится в
корневом [LICENSE](../../LICENSE). Исторические GPL-компоненты сохраняют условия
источника. Для планировок и графики сохраняется CC BY-SA 3.0; включённый исходный
код сохраняет лицензию кода донора. Исключения отдельных ресурсов не отменяются.

| Источник и авторы | Версия и лицензионная политика |
| --- | --- |
| SierraBay/SierraBay12, участники SierraBay и Baystation | [8623b35f6943130998002e94cf001a9c6ccb3f4c](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/README.md#лизцензия) |
| Void-Crew/Voidcrew-LRP, участники Voidcrew, Shiptest, Whitesands и TG | [66c552922bf2a28963c2a8f5d89993623a141a1f](https://github.com/Void-Crew/Voidcrew-LRP/blob/66c552922bf2a28963c2a8f5d89993623a141a1f/README.md#license) |
| CeladonSS13/Shiptest, участники Celadon, Shiptest, Whitesands и TG | [4214796c7289b74779f10dd25df2d695c264aa8f](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/README.md) |
| ParadiseSS13/Paradise, участники Paradise | [8e4ad940e497f64443c3fc635a09840a8fa7a1d2](https://github.com/ParadiseSS13/Paradise/blob/8e4ad940e497f64443c3fc635a09840a8fa7a1d2/README.md#licenses) |
| TG, BandaStation и Primera contributors | [65a9bd040b816783f0b6c24ba1e84ee7aab48456](https://github.com/SpaceStation220/Primera/blob/65a9bd040b816783f0b6c24ba1e84ee7aab48456/README.md#license) |

[Полный текст CC BY-SA 3.0](LICENSE-ASSETS-CC-BY-SA-3.0.txt),
[официальная страница лицензии](https://creativecommons.org/licenses/by-sa/3.0/).
Указание авторства не означает одобрения этой адаптации исходными проектами.

## Космические локации

| Локальный файл | Источник |
| --- | --- |
| `maps/asteroid_field.dmm` | Собственная планировка StationTrauma на штатных ресурсах сборки |
| `maps/drift_cargo.dmm` | Собственная планировка StationTrauma на штатных ресурсах сборки |

`asteroid_field.dmm` и `drift_cargo.dmm` созданы для этой интеграции на штатных
ресурсах. Существующие TG-руины подключаются по исходным шаблонам без копирования
графики и изменения их лицензий.

[ASSETS.json](ASSETS.json) перечисляет 81 неаудиоресурс: две карты локаций,
78 деталей рельефа планет (их источники указаны в
[expedition_planets/ATTRIBUTION.md](../expedition_planets/ATTRIBUTION.md)) и
`icons/obj/fluff/map_previews.dmi`. Реестр содержит permalink, коммиты и SHA-256
исходников и локальных файлов.
Превью карт создаётся штатным генератором и сохраняет авторство исходных карт и
ресурсов; это не самостоятельно нарисованная новая графика.

CRT-оформление TGUI и SVG-индикаторы созданы кодом для адаптации. Растровые
референсы других игр в модуль не включены. Штатные компьютерные спрайты, иконки,
шрифты и остальные существующие ресурсы сохраняют свои исходные уведомления.

## Звуки корабля

`code/ship_audio.dm` ссылается на существующие ресурсы сборки без копирования,
изменения или добавления аудиофайлов. Для них сохраняются исходные уведомления:

| Назначение | Ресурс сборки | Источник и лицензия |
| --- | --- | --- |
| Запуск двигателя и отход | `sound/items/jet_ignite.ogg` | kyles, [Freesound 453408](https://freesound.org/people/kyles/sounds/453408/), CC0; обработка ArcaneMusic, см. [sound/attributions.txt](../../sound/attributions.txt) |
| Работа двигателя | `sound/items/jet_active.ogg` | Тот же источник, CC0; очистка шума, небольшое изменение высоты тона, нарезка и конвертация в OGG указаны в исходном уведомлении |
| Остановка двигателя | `sound/items/jet_off.ogg` | Тот же источник, CC0; исходное уведомление сохраняется |
| Фон внутри корпуса | `sound/ambience/general/shipambience.ogg` | Существующий фон `/area`, участники TG; [общая лицензия ресурсов сборки](../../README.md#license), CC BY-SA 3.0 |
| Посадка и стыковка | `sound/machines/airlock/airlock_latch_hiss.ogg` | Usernameis1337, [Freesound 632755](https://freesound.org/people/Usernameis1337/sounds/632755/), CC BY 4.0; см. [исходное уведомление](../../sound/machines/airlock/attributions.txt) |

Тройка звуков двигателя уже используется штатным
`/datum/looping_sound/burning_jet`. Ранее добавленные `sound/ship_engine_starts.ogg`,
`sound/ship_engine_processing.ogg`, `sound/ship_engine_stops.ogg`,
`sound/ship_interior_ambience.ogg` и `sound/ship_landing.ogg` удалены: их точный
источник и условия распространения не подтверждены. Эта замена сохраняет запуск,
зацикленную работу, остановку, фон корпуса и сигнал механической фиксации.
Реестр `ASSETS.json` остаётся реестром неаудиоресурсов; новых медиа замена не вносит.

## Границы записи

Подводные модули и неизменённые ресурсы основной Primera целиком здесь не аудируются.

`ASSETS.json` не содержит AI-комментариев, поскольку JSON их не допускает.
Текст лицензии скопирован без изменений и не размечается AI-комментариями.
