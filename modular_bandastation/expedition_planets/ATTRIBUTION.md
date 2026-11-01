# Источники экспедиционных планет

Профили условий и планировки адаптированы из SierraBay/SierraBay12, коммит
`8623b35f6943130998002e94cf001a9c6ccb3f4c`. Авторы — участники SierraBay и Baystation;
индивидуальные вклады доступны в истории исходных файлов по ссылкам ниже.

[Политика лицензирования Sierra](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/README.md#лизцензия):
новый исходный код — AGPL v3, ресурсы — CC BY-SA 3.0, если не указано исключение.
Лицензия включённого исходного кода не подменяется лицензией ресурсов.
Полные тексты: [AGPL v3](../../LICENSE),
[CC BY-SA 3.0](../space_overmap/LICENSE-ASSETS-CC-BY-SA-3.0.txt).

## Профили планет

| Локальный профиль | Исходный профиль Sierra |
| --- | --- |
| `code/barren.dm`, `code/planet_site.dm`, `code/planet_generator.dm` | [barren.dm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/barren.dm) |
| `code/frozen.dm` | [snow.dm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/snow.dm) |
| `code/arid.dm` | [desert.dm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/desert.dm) |
| `code/lush.dm` | [grass.dm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/grass.dm) |

Адаптированы условия среды и различия биомов. Исполнение использует штатные
TG-типы, rust-g и местный генератор с резервированием площадок, руин и проходов;
контроллеры планет, атмосферы и обработки Sierra целиком не переносились.
Внешняя графика для профилей не добавлялась: грунт, руда, флора и существа
используют существующие ресурсы сборки с их исходными лицензиями.

## Биомы Celadon

Выбор биома по высоте, теплу и влажности, таблицы биомов, высота гор и плотности
флоры и фауны адаптированы из генераторов планет CeladonSS13/Shiptest, коммит
`4214796c7289b74779f10dd25df2d695c264aa8f` (исходный код — AGPL v3; авторы — участники
Celadon, Shiptest и TG). Наполнение биомов заменено существующими TG-типами.

| Локальный файл | Генератор Celadon |
| --- | --- |
| `code/barren.dm`, `code/planet_generator.dm` | [moon_generator.dm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/code/datums/mapgen/planetary/moon_generator.dm) |
| `code/frozen.dm` | [SnowGenerator.dm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/code/datums/mapgen/planetary/SnowGenerator.dm) |
| `code/arid.dm` | [SandGenerator.dm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/code/datums/mapgen/planetary/SandGenerator.dm) |
| `code/lush.dm` | [JungleGenerator.dm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/code/datums/mapgen/planetary/JungleGenerator.dm) |
| `code/lava.dm` | [LavaGenerator.dm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/code/datums/mapgen/planetary/LavaGenerator.dm) |

Наземные руины указаны в [overmap_ruins/ATTRIBUTION.md](../overmap_ruins/ATTRIBUTION.md).

## Детали рельефа Celadon

Мелкие шаблоны поверхности (greebles) из CeladonSS13/Shiptest, коммит
`4214796c7289b74779f10dd25df2d695c264aa8f`; планировки CC BY-SA 3.0, авторы — участники
Celadon, Shiptest, Whitesands и TG. Расстановка по планете — местный код генератора.

| Локальные файлы | Источник CeladonSS13/Shiptest |
| --- | --- |
| `maps/features/celadon_moon_crater1.dmm` … `celadon_moon_crater6.dmm` | [_maps/templates/greebles/moon_crater1.dmm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/templates/greebles/moon_crater1.dmm) … `moon_crater6.dmm` |
| `maps/features/celadon_jungle_1.dmm` … `celadon_jungle_29.dmm` | [_maps/templates/greebles/jungle/greeble_jungle_1.dmm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/templates/greebles/jungle/greeble_jungle_1.dmm) … `greeble_jungle_29.dmm` |
| `maps/features/celadon_jungle_30.dmm` | [_maps/templates/greebles/jungle/jungle_greeble_30.dmm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/templates/greebles/jungle/jungle_greeble_30.dmm) |
| `maps/features/celadon_jungle_anomaly_1.dmm` … `celadon_jungle_anomaly_12.dmm` | [_maps/templates/greebles/jungle/greeble_jungle_anomaly_1.dmm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/templates/greebles/jungle/greeble_jungle_anomaly_1.dmm) … `greeble_jungle_anomaly_12.dmm` |
| `maps/features/celadon_junglecave_1.dmm` … `celadon_junglecave_10.dmm` | [_maps/templates/greebles/jungle/greeble_junglecave_1.dmm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/templates/greebles/jungle/greeble_junglecave_1.dmm) … `greeble_junglecave_10.dmm` |
| `maps/features/celadon_sulfur_pool_1.dmm` … `celadon_sulfur_pool_19.dmm` | [_maps/templates/greebles/whitesands/sulfur_pool_1.dmm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/templates/greebles/whitesands/sulfur_pool_1.dmm) … `sulfur_pool_19.dmm` |
| `maps/features/celadon_oasis_1.dmm` | [_maps/templates/greebles/whitesands/oasis_1.dmm](https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/templates/greebles/whitesands/oasis_1.dmm) |

Природный грунт и скала стали заглушками, которые генератор заменяет грунтом и
породой планеты. Аномалии Shiptest заменены неподвижными бессрочными аномалиями TG,
источники радиации — декалями без излучения, оружие — ближайшими местными аналогами.
Вода Whitesands несёт атмосферу пустынного профиля, а её случайные спавнеры сохраняют
донорские шансы с местной флорой и фауной; пещерные медведи стали шахтёрскими волками.

Исходные permalink, коммиты и контрольные суммы всех 78 деталей рельефа включены в
[ASSETS.json](../space_overmap/ASSETS.json) `space_overmap`. Указание авторства не означает
одобрения этой адаптации исходными проектами.
