// Skill costs, prerequisites and starting profiles adapted from SierraBay/SierraBay12,
// AGPL-3.0, commit 3a146c38cd257e931334153f1d9c4feaa50a21df (code/modules/mob/skills, maps/sierra/job).
#define ST_TRAINING_UNSKILLED 1
#define ST_TRAINING_BASIC 2
#define ST_TRAINING_TRAINED 3
#define ST_TRAINING_EXPERIENCED 4
#define ST_TRAINING_MASTER 5

GLOBAL_LIST_INIT(stationtrauma_training_levels, list("Без подготовки", "Базовый", "Обученный", "Опытный", "Мастер"))
GLOBAL_LIST_INIT(stationtrauma_training_skills, list(
	"bureaucracy" = new /datum/stationtrauma_training_skill("Делопроизводство", 1, ST_TRAINING_MASTER),
	"finance" = new /datum/stationtrauma_training_skill("Финансы", 1, ST_TRAINING_MASTER),
	"EVA" = new /datum/stationtrauma_training_skill("Водолазная подготовка", 1, ST_TRAINING_MASTER),
	"exosuit" = new /datum/stationtrauma_training_skill("Экзоскелеты", 2, ST_TRAINING_BASIC, prerequisites = list("EVA" = ST_TRAINING_TRAINED)),
	"pilot" = new /datum/stationtrauma_training_skill("Пилотирование", 2),
	"hauling" = new /datum/stationtrauma_training_skill("Атлетика", 1, ST_TRAINING_MASTER),
	"computer" = new /datum/stationtrauma_training_skill("Компьютеры", 1, ST_TRAINING_MASTER),
	"botany" = new /datum/stationtrauma_training_skill("Ботаника", 1, ST_TRAINING_MASTER, description = "Базовый уровень нужен для лабораторного анализа растительных проб."),
	"cooking" = new /datum/stationtrauma_training_skill("Кулинария", 1, ST_TRAINING_MASTER),
	"combat" = new /datum/stationtrauma_training_skill("Ближний бой", costs = list(0, 2, 4, 4, 8), description = "В боевом режиме влияет на силу ударов предметами и восстановление после успешного удара кулаком. Обученный — обычная эффективность; опытный и мастер дают небольшой бонус."),
	"weapons" = new /datum/stationtrauma_training_skill("Оружие", costs = list(0, 2, 4, 6, 8), description = "Уменьшает дополнительный разброс при стрельбе. Мастер сохраняет базовую точность самого оружия."),
	"forensics" = new /datum/stationtrauma_training_skill("Криминалистика", costs = list(0, 4, 4, 4, 6)),
	"construction" = new /datum/stationtrauma_training_skill("Строительство", 1),
	"electrical" = new /datum/stationtrauma_training_skill("Электротехника"),
	"atmos" = new /datum/stationtrauma_training_skill("Газовые системы"),
	"engines" = new /datum/stationtrauma_training_skill("Энергетика", 4),
	"devices" = new /datum/stationtrauma_training_skill("Сложные устройства"),
	"science" = new /datum/stationtrauma_training_skill("Научная методика", description = "Базовый уровень: обследование находок и отбор проб. Обученный: лабораторный анализ. Опытный и мастер выполняют эти действия быстрее."),
	"medical" = new /datum/stationtrauma_training_skill("Медицина", 4),
	"anatomy" = new /datum/stationtrauma_training_skill("Анатомия", 4, description = "Базовый уровень нужен для лабораторного анализа проб тканей."),
	"chemistry" = new /datum/stationtrauma_training_skill("Химия", 4, description = "Базовый уровень нужен для лабораторного анализа минеральных проб."),
	"virology" = new /datum/stationtrauma_training_skill("Вирусология", 4, ST_TRAINING_BASIC, prerequisites = list("chemistry" = ST_TRAINING_BASIC)),
))

GLOBAL_LIST_INIT(stationtrauma_training_profiles, list(
	"explorer" = new /datum/stationtrauma_training_profile("Исследователь", 16,
		list("EVA" = 2, "science" = 2, "medical" = 2), list("science" = 5, "combat" = 4, "weapons" = 4), /datum/job/explorer),
	"leader" = new /datum/stationtrauma_training_profile("Руководитель экспедиции", 22,
		list("bureaucracy" = 2, "EVA" = 3, "science" = 3, "pilot" = 2, "medical" = 2), list("pilot" = 5, "science" = 5, "combat" = 4, "weapons" = 4)),
	"pilot" = new /datum/stationtrauma_training_profile("Пилот экспедиции", 16,
		list("EVA" = 2, "science" = 2, "pilot" = 3, "medical" = 2), list("pilot" = 5, "science" = 5, "combat" = 4, "weapons" = 4)),
	"field_medic" = new /datum/stationtrauma_training_profile("Полевой медик", 26,
		list("EVA" = 2, "medical" = 2, "hauling" = 2, "science" = 2, "anatomy" = 2), list("medical" = 5, "science" = 5, "combat" = 4, "weapons" = 4), /datum/job/doctor),
	"field_engineer" = new /datum/stationtrauma_training_profile("Полевой инженер", 20,
		list("EVA" = 2, "construction" = 2, "electrical" = 2, "hauling" = 2, "atmos" = 2, "science" = 2, "computer" = 2, "engines" = 2, "medical" = 2),
		list("construction" = 5, "electrical" = 5, "science" = 5, "combat" = 4, "weapons" = 4), /datum/job/station_engineer),
	"scientist" = new /datum/stationtrauma_training_profile("Научный сотрудник", 22,
		list("bureaucracy" = 2, "computer" = 2, "devices" = 2, "science" = 3), list("devices" = 5, "science" = 5, "chemistry" = 5), /datum/job/scientist),
	"senior_scientist" = new /datum/stationtrauma_training_profile("Старший научный сотрудник", 30,
		list("bureaucracy" = 2, "computer" = 2, "finance" = 2, "botany" = 2, "anatomy" = 2, "devices" = 3, "science" = 3), list("devices" = 5, "science" = 5, "anatomy" = 5)),
	"assistant" = new /datum/stationtrauma_training_profile("Лаборант", 16,
		list(), list("devices" = 5, "science" = 5, "chemistry" = 5)),
	"security_officer" = new /datum/stationtrauma_training_profile("Офицер СБ", 20,
		list("bureaucracy" = 2, "EVA" = 2, "combat" = 2, "hauling" = 2, "weapons" = 3, "forensics" = 2), list("combat" = 5, "weapons" = 5), /datum/job/security_officer),
	"warden" = new /datum/stationtrauma_training_profile("Смотритель СБ", 25,
		list("bureaucracy" = 3, "EVA" = 2, "hauling" = 2, "combat" = 2, "weapons" = 3, "forensics" = 2), list("combat" = 5, "weapons" = 5, "forensics" = 5), /datum/job/warden),
	"detective" = new /datum/stationtrauma_training_profile("Детектив", 22,
		list("bureaucracy" = 2, "computer" = 2, "EVA" = 2, "combat" = 2, "weapons" = 2, "forensics" = 3), list("combat" = 5, "weapons" = 5, "forensics" = 5), /datum/job/detective),
))

/** One preparation discipline; costs are per purchased level, not TG experience. */
/datum/stationtrauma_training_skill
	/// Display name, never used as a save key.
	var/name
	/// Current gameplay use, so players can distinguish implemented skills from reserved ones.
	var/description
	/// Maximum selectable level unless the profession overrides it.
	var/maximum
	/// Cost of each incremental level, indexed by the resulting level.
	var/list/costs
	/// Other disciplines required for any training above unskilled.
	var/list/prerequisites

/datum/stationtrauma_training_skill/New(name, difficulty = 2, maximum = ST_TRAINING_TRAINED, list/costs, list/prerequisites = list(), description = "Влияние на действия пока не подключено.")
	src.name = name
	src.description = description
	src.maximum = maximum
	src.costs = costs || list(0, difficulty, difficulty, 2 * difficulty, 2 * difficulty)
	src.prerequisites = prerequisites

/** A profession's free starting training, selection limits and extra point allowance. */
/datum/stationtrauma_training_profile
	/// Display name.
	var/name
	/// Points available above the free starting levels.
	var/points
	/// Minimum levels; omitted disciplines start unskilled.
	var/list/minimums
	/// Profession-specific upper limits.
	var/list/maximums
	/// Existing event occupation receiving this profile; null means manual assignment.
	var/job_type

/datum/stationtrauma_training_profile/New(name, points, list/minimums, list/maximums, job_type)
	src.name = name
	src.points = points
	src.minimums = minimums
	src.maximums = maximums
	src.job_type = job_type

/** Return a fresh, complete allocation at the profession's starting levels. */
/datum/stationtrauma_training_profile/proc/starting_levels()
	var/list/result = list()
	for(var/skill_id in GLOB.stationtrauma_training_skills)
		result[skill_id] = minimums[skill_id] || ST_TRAINING_UNSKILLED
	return result

/** Count purchased levels. Call only after validating discipline IDs and level bounds. */
/datum/stationtrauma_training_profile/proc/spent_points(list/levels)
	var/spent = 0
	for(var/skill_id in levels)
		var/datum/stationtrauma_training_skill/skill = GLOB.stationtrauma_training_skills[skill_id]
		var/minimum = minimums[skill_id] || ST_TRAINING_UNSKILLED
		for(var/level in minimum + 1 to levels[skill_id])
			spent += skill.costs[level]
	return spent

/** Return an explanatory error for untrusted allocations, or null when valid. */
/datum/stationtrauma_training_profile/proc/allocation_error(list/levels)
	if(!islist(levels) || length(levels) != length(GLOB.stationtrauma_training_skills))
		return "Неполный список дисциплин."
	for(var/skill_id in levels)
		if(!istext(skill_id) || !(skill_id in GLOB.stationtrauma_training_skills))
			return "Неизвестная дисциплина."
	for(var/skill_id in GLOB.stationtrauma_training_skills)
		var/datum/stationtrauma_training_skill/skill = GLOB.stationtrauma_training_skills[skill_id]
		var/level = levels[skill_id]
		var/minimum = minimums[skill_id] || ST_TRAINING_UNSKILLED
		var/maximum = maximums[skill_id] || skill.maximum
		if(!isnum(level) || level != round(level) || level < minimum || level > maximum)
			return "Недопустимый уровень: [skill.name]."
		if(level <= ST_TRAINING_UNSKILLED)
			continue
		for(var/prerequisite in skill.prerequisites)
			var/required_level = levels[prerequisite]
			if(!isnum(required_level) || required_level < skill.prerequisites[prerequisite])
				var/datum/stationtrauma_training_skill/required_skill = GLOB.stationtrauma_training_skills[prerequisite]
				return "Для [skill.name] требуется [required_skill.name]: [GLOB.stationtrauma_training_levels[skill.prerequisites[prerequisite]]]."
	if(spent_points(levels) > points)
		return "Недостаточно очков навыков."
	return null

/** Immutable round preparation belongs to the mind, so changing bodies keeps it. */
/datum/component/stationtrauma_training
	/// Stable profession ID for inspection and future skill-gated equipment.
	var/profile_id
	/// Private copy, independent of saved character preferences and other minds.
	VAR_PRIVATE/list/levels

/datum/component/stationtrauma_training/Initialize(profile_id, list/levels)
	if(!istype(parent, /datum/mind) || !istext(profile_id))
		return COMPONENT_INCOMPATIBLE
	var/datum/stationtrauma_training_profile/profile = GLOB.stationtrauma_training_profiles[profile_id]
	if(!profile || profile.allocation_error(levels))
		return COMPONENT_INCOMPATIBLE
	src.profile_id = profile_id
	src.levels = levels.Copy()

/datum/component/stationtrauma_training/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MIND_TRANSFERRED, PROC_REF(mind_transferred))
	var/datum/mind/mind = parent
	bind_combat(mind.current)

/datum/component/stationtrauma_training/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_MIND_TRANSFERRED)
	bind_combat(null)

/** A mind swap need not log in its new client again; refresh both bodies' inspection commands. */
/datum/component/stationtrauma_training/proc/mind_transferred(datum/mind/mind, mob/living/old_body)
	SIGNAL_HANDLER
	bind_combat(mind.current)
	if(old_body?.client)
		SSstationtrauma_training.refresh_verbs(old_body.client)
	if(mind.current?.client)
		SSstationtrauma_training.refresh_verbs(mind.current.client)

/** Query a valid discipline without exposing the stored allocation for mutation. */
/datum/component/stationtrauma_training/proc/get_level(skill_id)
	if(!istext(skill_id) || !(skill_id in GLOB.stationtrauma_training_skills))
		return null
	return levels[skill_id]
