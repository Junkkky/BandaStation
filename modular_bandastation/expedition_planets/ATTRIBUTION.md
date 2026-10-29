<!-- AI EDIT START - Sources and licenses of the expedition_planets integration -->
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
| `code/barren.dm` | [barren.dm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/barren.dm) |
| `code/frozen.dm` | [snow.dm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/snow.dm) |
| `code/arid.dm` | [desert.dm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/desert.dm) |
| `code/lush.dm` | [grass.dm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/grass.dm) |

Адаптированы условия среды и различия биомов. Исполнение использует штатные
TG-типы, rust-g и местный генератор с резервированием площадок, руин и проходов;
контроллеры планет, атмосферы и обработки Sierra целиком не переносились.
Внешняя графика для профилей не добавлялась: грунт, руда, флора и существа
используют существующие ресурсы сборки с их исходными лицензиями.

## Наземные руины

| Локальный файл | Исходник Sierra |
| --- | --- |
| `maps/ruins/sierra_crashed_pod.dmm` | [maps/random_ruins/exoplanet_ruins/crashed_pod/crashed_pod.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/crashed_pod/crashed_pod.dmm) |
| `maps/ruins/sierra_crashed_probe.dmm` | [maps/random_ruins/exoplanet_ruins/crashed_probe/crashed_probe.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/crashed_probe/crashed_probe.dmm) |
| `maps/ruins/sierra_crashed_shuttle.dmm` | [maps/random_ruins/exoplanet_ruins/crashed_shuttle/crashed_shuttle.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/crashed_shuttle/crashed_shuttle.dmm) |
| `maps/ruins/sierra_deserted_lab.dmm` | [maps/random_ruins/exoplanet_ruins/deserted_lab/deserted_lab.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/deserted_lab/deserted_lab.dmm) |
| `maps/ruins/sierra_drill_site.dmm` | [maps/random_ruins/exoplanet_ruins/drill_site/drill_site.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/drill_site/drill_site.dmm) |
| `maps/ruins/sierra_ec_old_crash.dmm` | [maps/random_ruins/exoplanet_ruins/ec_old_crash/ec_old_crash.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/ec_old_crash/ec_old_crash.dmm) |
| `maps/ruins/sierra_excavation_site.dmm` | [maps/random_ruins/exoplanet_ruins/excavation_site/excavation_site.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/excavation_site/excavation_site.dmm) |
| `maps/ruins/sierra_hut.dmm` | [maps/random_ruins/exoplanet_ruins/hut/hut.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/hut/hut.dmm) |
| `maps/ruins/sierra_hydrobase.dmm` | [maps/random_ruins/exoplanet_ruins/hydrobase/hydrobase.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/hydrobase/hydrobase.dmm) |
| `maps/ruins/sierra_lodge.dmm` | [maps/random_ruins/exoplanet_ruins/lodge/lodge.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/lodge/lodge.dmm) |
| `maps/ruins/sierra_monoliths.dmm` | [maps/random_ruins/exoplanet_ruins/monoliths/monoliths.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/monoliths/monoliths.dmm) |
| `maps/ruins/sierra_oasis.dmm` | [maps/random_ruins/exoplanet_ruins/oasis/oasis.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/oasis/oasis.dmm) |
| `maps/ruins/sierra_oasis2.dmm` | [maps/random_ruins/exoplanet_ruins/oasis/oasis2.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/oasis/oasis2.dmm) |
| `maps/ruins/sierra_oasis3.dmm` | [maps/random_ruins/exoplanet_ruins/oasis/oasis3.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/oasis/oasis3.dmm) |
| `maps/ruins/sierra_oldlab.dmm` | [maps/random_ruins/exoplanet_ruins/oldlab/oldlab.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/oldlab/oldlab.dmm) |
| `maps/ruins/sierra_oldlab2.dmm` | [maps/random_ruins/exoplanet_ruins/oldlab2/oldlab2.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/oldlab2/oldlab2.dmm) |
| `maps/ruins/sierra_oldpod.dmm` | [maps/random_ruins/exoplanet_ruins/oldpod/oldpod.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/oldpod/oldpod.dmm) |
| `maps/ruins/sierra_radshrine.dmm` | [maps/random_ruins/exoplanet_ruins/radshrine/radshrine.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/radshrine/radshrine.dmm) |
| `maps/ruins/sierra_skrell_biodome.dmm` | [maps/random_ruins/exoplanet_ruins/skrell_biodome/skrell_biodome.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/skrell_biodome/skrell_biodome.dmm) |
| `maps/ruins/sierra_spider_nest.dmm` | [maps/random_ruins/exoplanet_ruins/spider_nest/spider_nest.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/spider_nest/spider_nest.dmm) |
| `maps/ruins/sierra_tar_anomaly.dmm` | [maps/random_ruins/exoplanet_ruins/tar_anomaly/tar_anomaly.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/tar_anomaly/tar_anomaly.dmm) |
| `maps/ruins/sierra_transshipment.dmm` | [maps/random_ruins/exoplanet_ruins/transshipment/transshipment.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/transshipment/transshipment.dmm) |
| `maps/ruins/sierra_trash_heap.dmm` | [maps/random_ruins/exoplanet_ruins/trash_heap/trash_heap.dmm](https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/maps/random_ruins/exoplanet_ruins/trash_heap/trash_heap.dmm) |

Сохранены исходные планировки. Несовместимые сущности, area, трубы, механизмы,
обитатели и добыча адаптированы к местным типам; добавлены местные исследовательские
объекты. Это адаптации карт, а не перенос всех механик доноров. Лаборатория
посадочного лагеря отдельно указана в
[space_overmap/ATTRIBUTION.md](../space_overmap/ATTRIBUTION.md).

Исходные permalink, коммиты и контрольные суммы всех 23 карт включены в общий
[ASSETS.json](../space_overmap/ASSETS.json). Указание авторства не означает
одобрения этой адаптации исходными проектами.
<!-- AI EDIT END -->
