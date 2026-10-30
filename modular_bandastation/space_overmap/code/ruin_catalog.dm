// AI EDIT START - space overmap module integration
// Local TG equivalents of the original layouts; no foreign controllers or AI processing.
/** Imported space templates excluded from ordinary station space ruin selection. */
/datum/map_template/ruin/space/expedition
	prefix = "modular_bandastation/space_overmap/maps/ruins/"
	ruin_type = "expedition_space"
	/// Crew-facing chart name for this imported ruin.
	var/overmap_name

/** Expedition-only ruin template for Expedition-Space void astraeus. */
/datum/map_template/ruin/space/expedition/void_astraeus
	id = "void_astraeus"
	name = "Expedition-Space void astraeus"
	suffix = "void_astraeus.dmm"
	overmap_name = "Аварийный корабль Astraeus"

/** Expedition-only ruin template for Expedition-Space void power_puzzle. */
/datum/map_template/ruin/space/expedition/void_power_puzzle
	id = "void_power_puzzle"
	name = "Expedition-Space void power_puzzle"
	suffix = "void_power_puzzle.dmm"
	overmap_name = "Обесточенное хранилище"

/** Expedition-only ruin template for Expedition-Space void nuclear_dump. */
/datum/map_template/ruin/space/expedition/void_nuclear_dump
	id = "void_nuclear_dump"
	name = "Expedition-Space void nuclear_dump"
	suffix = "void_nuclear_dump.dmm"
	overmap_name = "Хранилище радиоактивных отходов"

/** Expedition-only ruin template for Expedition-Space void transport18. */
/datum/map_template/ruin/space/expedition/void_transport18
	id = "void_transport18"
	name = "Expedition-Space void transport18"
	suffix = "void_transport18.dmm"
	overmap_name = "Потерянный транспорт"

/** Expedition-only ruin template for Expedition-Space void dark_glade. */
/datum/map_template/ruin/space/expedition/void_dark_glade
	id = "void_dark_glade"
	name = "Expedition-Space void dark_glade"
	suffix = "void_dark_glade.dmm"
	overmap_name = "Заросший обломок"

/** Expedition-only ruin template for Expedition-Space paradise abandoned_engi_sat. */
/datum/map_template/ruin/space/expedition/paradise_abandoned_engi_sat
	id = "paradise_abandoned_engi_sat"
	name = "Expedition-Space paradise abandoned_engi_sat"
	suffix = "paradise_abandoned_engi_sat.dmm"
	overmap_name = "Заброшенный инженерный спутник"

/** Expedition-only ruin template for Expedition-Space paradise alien_cache_site. */
/datum/map_template/ruin/space/expedition/paradise_alien_cache_site
	id = "paradise_alien_cache_site"
	name = "Expedition-Space paradise alien_cache_site"
	suffix = "paradise_alien_cache_site.dmm"
	overmap_name = "Неопознанное хранилище"

/** Expedition-only ruin template for Expedition-Space paradise freighter. */
/datum/map_template/ruin/space/expedition/paradise_freighter
	id = "paradise_freighter"
	name = "Expedition-Space paradise freighter"
	suffix = "paradise_freighter.dmm"
	overmap_name = "Затерянный грузовой корабль"

/** Expedition-only ruin template for Expedition-Space paradise wreckedcargoship. */
/datum/map_template/ruin/space/expedition/paradise_wreckedcargoship
	id = "paradise_wreckedcargoship"
	name = "Expedition-Space paradise wreckedcargoship"
	suffix = "paradise_wreckedcargoship.dmm"
	overmap_name = "Разграбленный грузовой корабль"

// CeladonSS13/Shiptest contributors; adapted layouts: CC BY-SA 3.0; see source links in each DMM.
// https://github.com/CeladonSS13/Shiptest/tree/4214796c7289b74779f10dd25df2d695c264aa8f/_maps/_mod_celadon/RandomRuins
/** Expedition-only ruin template for Expedition-Space celadon fueldepot. */
/datum/map_template/ruin/space/expedition/celadon_fueldepot
	id = "celadon_fueldepot"
	name = "Expedition-Space celadon fueldepot"
	suffix = "celadon_fueldepot.dmm"
	overmap_name = "Заброшенный топливный склад"

/** Expedition-only ruin template for Expedition-Space celadon corporate_mining. */
/datum/map_template/ruin/space/expedition/celadon_corporate_mining
	id = "celadon_corporate_mining"
	name = "Expedition-Space celadon corporate_mining"
	suffix = "celadon_corporate_mining.dmm"
	overmap_name = "Корпоративный шахтёрский модуль"

/** Expedition-only ruin template for Expedition-Space celadon excavator. */
/datum/map_template/ruin/space/expedition/celadon_excavator
	id = "celadon_excavator"
	name = "Expedition-Space celadon excavator"
	suffix = "celadon_excavator.dmm"
	overmap_name = "Разбитый экскаватор класса DK"

/** Expedition-only ruin template for Expedition-Space celadon djstation. */
/datum/map_template/ruin/space/expedition/celadon_djstation
	id = "celadon_djstation"
	name = "Expedition-Space celadon djstation"
	suffix = "celadon_djstation.dmm"
	overmap_name = "Музыкальная радиостанция"

/** Expedition-only ruin template for Expedition-Space celadon cryocontainment. */
/datum/map_template/ruin/space/expedition/celadon_cryocontainment
	id = "celadon_cryocontainment"
	name = "Expedition-Space celadon cryocontainment"
	suffix = "celadon_cryocontainment.dmm"
	overmap_name = "Криогенное хранилище"
// AI EDIT END
