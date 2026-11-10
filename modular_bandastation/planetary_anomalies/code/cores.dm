/**
 * Cores of the Shiptest anomalies. None of our recipes takes them: the xenoarchaeology scan pad
 * catalogues each core once for research notes. Shiptest's grind reagents and core detonations are
 * not ported.
 */
/obj/item/assembly/signaler/anomaly/planetary
	abstract_type = /obj/item/assembly/signaler/anomaly/planetary
	/// Research the scan pad pays for cataloguing it.
	var/research_points = 60
	/// Paid its catalogue research already.
	var/research_paid = FALSE
	/// ARTIFACT_ENERGY_* it carries.
	var/energy_kind = ARTIFACT_ENERGY_CONCENTRATED
	/// Effect an exotic harvester pours from it into a battery, spending the core.
	var/battery_effect = /datum/artifact_effect/temperature/heat
	/// Corps journal protocol of the anomaly it came from, if that was documented off the station.
	var/datum/expedition_record/xenoarch_find/journal_record

/obj/item/assembly/signaler/anomaly/planetary/Destroy()
	journal_record = null
	return ..()

/obj/item/assembly/signaler/anomaly/planetary/chrono
	energy_kind = ARTIFACT_ENERGY_CONCENTRATED
	battery_effect = /datum/artifact_effect/bestow/sprint
	name = "ядро аномалии хронографа"
	desc = "Стабилизированное ядро хронографа. Из него сочится украденное время."
	icon_state = "grav_core"

/obj/item/assembly/signaler/anomaly/planetary/heartbeat
	energy_kind = ARTIFACT_ENERGY_PARTICLE
	battery_effect = /datum/artifact_effect/radiation
	name = "ядро аномалии сердцебиения"
	desc = "Стабилизированное ядро сердцебиения. По оболочке пробегают тёплые толчки."

/obj/item/assembly/signaler/anomaly/planetary/melter
	energy_kind = ARTIFACT_ENERGY_CONCENTRATED
	battery_effect = /datum/artifact_effect/temperature/heat
	name = "ядро аномалии плавильщика"
	desc = "Стабилизированное ядро плавильщика. Оно шипит и потрескивает."
	icon_state = "pyro_core"

/obj/item/assembly/signaler/anomaly/planetary/phantom
	energy_kind = ARTIFACT_ENERGY_PSIONIC
	battery_effect = /datum/artifact_effect/poltergeist
	name = "ядро аномалии фантома"
	desc = "Стабилизированное ядро фантома. Оно тихо кричит."

/obj/item/assembly/signaler/anomaly/planetary/plasmasoul
	energy_kind = ARTIFACT_ENERGY_SYNTHESIS
	battery_effect = /datum/artifact_effect/gas_vent/plasma
	name = "ядро аномалии плазменной души"
	desc = "Стабилизированное ядро плазменной души. Воздух вокруг шипит."

/obj/item/assembly/signaler/anomaly/planetary/pulsar
	energy_kind = ARTIFACT_ENERGY_ELECTROMAGNETIC
	battery_effect = /datum/artifact_effect/emp
	name = "ядро аномалии пульсара"
	desc = "Стабилизированное ядро пульсара. От него идёт электромагнитный треск."

/obj/item/assembly/signaler/anomaly/planetary/sparkler
	energy_kind = ARTIFACT_ENERGY_ELECTROMAGNETIC
	battery_effect = /datum/artifact_effect/tesla
	name = "ядро аномалии искрителя"
	desc = "Стабилизированное ядро искрителя. С него соскакивают крошечные искры."

/obj/item/assembly/signaler/anomaly/planetary/tvstatic
	energy_kind = ARTIFACT_ENERGY_PSIONIC
	battery_effect = /datum/artifact_effect/hallucination
	name = "ядро аномалии статики"
	desc = "Стабилизированное ядро статики. От одного взгляда на него болит голова."
	research_points = 90

/obj/item/assembly/signaler/anomaly/planetary/transfusion
	energy_kind = ARTIFACT_ENERGY_ORGANIC
	battery_effect = /datum/artifact_effect/blood/drain
	name = "ядро аномалии трансфузии"
	desc = "Стабилизированное ядро трансфузии. Из оболочки медленно сочится багрянец."
	icon_state = "pyro_core"

/obj/item/assembly/signaler/anomaly/planetary/veins
	energy_kind = ARTIFACT_ENERGY_ORGANIC
	battery_effect = /datum/artifact_effect/life_drain
	name = "ядро аномалии фонтана"
	desc = "Стабилизированное ядро фонтана. Скользкое, как кишка."

/// Our anomalies drop a core only while its type is under the research subsystem's limit.
/datum/controller/subsystem/research/Initialize()
	. = ..()
	for(var/core_type in subtypesof(/obj/item/assembly/signaler/anomaly/planetary))
		anomaly_hard_limit_by_type[core_type] = 8
