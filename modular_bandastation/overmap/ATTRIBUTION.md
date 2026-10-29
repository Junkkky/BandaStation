<!-- AI EDIT START - Sources and licenses of the overmap integration -->
# Источники общей овермапы

Код общей навигации и его адаптации распространяются на условиях GNU AGPL v3;
[полный текст лицензии](../../LICENSE) находится в корне сборки.

| Локальный код | Источник | Использование и изменения |
| --- | --- | --- |
| `code/overmap_autopilot.dm` | [ship_autopilot.dm](https://github.com/voidcrew/Voidcrew/blob/0c87384b55294dc7348f83bbd3fddd9427d136de/voidcrew/modules/overmap/code/modules/overmap/ship_autopilot.dm) | Адаптация ограниченного восьминаправленного A*, очереди и сохранённого маршрута. Местная геометрия корпуса и непрерывные координаты заменяют замкнутую сетку и зоны источника. |
| `code/overmap_contacts.dm` | [ship_sensors.dm](https://github.com/voidcrew/Voidcrew/blob/0c87384b55294dc7348f83bbd3fddd9427d136de/voidcrew/modules/overmap/code/modules/overmap/ship_sensors.dm) | Источник подхода к личным данным сенсоров и обнаружению. Здесь замеры, возраст контакта и идентификация хранятся отдельно для экипажей; полный контроллер сенсоров не перенесён. |

Источник — **voidcrew/Voidcrew (Voidcrew Reborn)**, участники Voidcrew и TG;
проект представлен Jackrip. Зафиксированный коммит:
[`0c87384b55294dc7348f83bbd3fddd9427d136de`](https://github.com/voidcrew/Voidcrew/tree/0c87384b55294dc7348f83bbd3fddd9427d136de).
[Лицензионная политика этой версии](https://github.com/voidcrew/Voidcrew/blob/0c87384b55294dc7348f83bbd3fddd9427d136de/README.md#license)
сохраняет AGPL v3 для нового кода и условия прежних GPL-компонентов.
Индивидуальные вклады устанавливаются по истории файлов; авторство донорского
кода не приписывается автору адаптации.

Штатные механизмы TG/BandaStation для сигналов, перемещения, света, снарядов и
повреждений сохраняют свои лицензии и уведомления. Чужие растровые изображения,
карты и аудио в общий модуль не добавлялись. Ресурсы окружения перечислены в
[space_overmap/ATTRIBUTION.md](../space_overmap/ATTRIBUTION.md) и
[expedition_planets/ATTRIBUTION.md](../expedition_planets/ATTRIBUTION.md).
<!-- AI EDIT END -->
