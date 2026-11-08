# Источники экспедиционного корпуса

## Полевая форма

Спрайты участников SierraBay и Baystation из
[SierraBay/SierraBay12, c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037](https://github.com/SierraBay/SierraBay12/tree/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037):

| Файл модуля | Исходник |
| --- | --- |
| `icons/uniforms.dmi` | [maps/sierra/icons/obj/obj_under_exploration.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/maps/sierra/icons/obj/obj_under_exploration.dmi) |
| `icons/uniforms_worn.dmi` | [maps/sierra/icons/mob/onmob_under_exploration.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/maps/sierra/icons/mob/onmob_under_exploration.dmi) |

Файлы скопированы без изменения пикселей или DMI-метаданных. Привязка четырёх
вариантов формы к должностям адаптирована к системе одежды TG/BandaStation.

## Остальной полевой гардероб

Из того же коммита SierraBay/SierraBay12 извлечены только используемые состояния:

| Файлы модуля | Исходники SierraBay/SierraBay12 |
| --- | --- |
| `head.dmi`, `head_worn.dmi` — пилотский шлем | [obj_head.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/clothing/obj_head.dmi), [onmob_head.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/onmob_head.dmi) |
| `shoes.dmi`, `shoes_worn.dmi` — служебные ботинки | [obj_feet.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/clothing/obj_feet.dmi), [onmob_feet.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/onmob_feet.dmi) |
| `gloves.dmi`, `gloves_worn.dmi` — рабочие перчатки | [obj_hands.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/clothing/obj_hands.dmi), [onmob_hands.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/onmob_hands.dmi) |
| `suits.dmi`, `suits_worn.dmi` — куртка | [obj_suit.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/clothing/obj_suit.dmi), [onmob_suit.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/onmob_suit.dmi) |
| `accessories.dmi`, `accessories_worn.dmi` — разгрузка и ножны | [obj_accessories.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/clothing/obj_accessories.dmi), [onmob_accessories.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/onmob_accessories.dmi) |

Авторство графики сохраняется за участниками SierraBay/Baystation. Кадры извлечены
без перерисовки, масштабирования или перекраски; совпадение пикселей проверено.
Изменена упаковка DMI; открытое состояние куртки переименовано из `_open` в `_t`
для штатного переключателя TG. Ножны используют один рисунок в поясном варианте
и как аксессуар формы. Карманы и хранение работают через имеющуюся систему TG.

Состав взят из [шкафов НТ-эксплореров](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/maps/sierra/structures/closets/exploration.dm)
и их [стартовых наборов](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/maps/sierra/job/outfits.dm).
Механические свойства адаптированы на основе местных ботинок, перчаток, шлема,
одежды и storage; системы инвентаря и военных званий Bay не переносились.

Лицензия графики — [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/),
согласно [лицензионной политике источника](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/README.md#лизцензия).
Полный текст уже включён в [space_overmap/LICENSE-ASSETS-CC-BY-SA-3.0.txt](../space_overmap/LICENSE-ASSETS-CC-BY-SA-3.0.txt).

## Мачете

Состояние `machete` извлечено без изменения пикселей из того же коммита SierraBay/SierraBay12:
[melee_physical.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/obj/weapons/melee_physical.dmi),
[lefthand.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/items/lefthand.dmi),
[righthand.dmi](https://github.com/SierraBay/SierraBay12/blob/c5ad038ddf56f54c7e7f3bfc11883cd28e6e2037/icons/mob/onmob/items/righthand.dmi).
Файлы модуля: `machete.dmi`, `machete_lefthand.dmi`, `machete_righthand.dmi`.
Авторство SierraBay/Baystation, лицензия графики CC BY-SA 3.0, упаковка DMI изменена.
Механика местного `/obj/item/hatchet`; материалы и парирование Bay не переносились.
