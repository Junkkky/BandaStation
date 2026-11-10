// Xenoarchaeology, ported from Voidcrew PR #506 (cfde23a6397c), which ported it from NovaSector and
// Polaris. Only what the current stage reads lives here; later stages add their own sections.

// ===== Bands =====
// A find's band is stamped when it is dug: the danger of the planet it came from.
#define XENOARCH_BAND_GREEN 1
#define XENOARCH_BAND_YELLOW 2
#define XENOARCH_BAND_RED 3
/// Clamps a stamped band (or null) to a valid index into the positional lists below.
#define XENOARCH_BAND_INDEX(band) clamp(band || XENOARCH_BAND_GREEN, XENOARCH_BAND_GREEN, XENOARCH_BAND_RED)

// ===== Effect tiers =====
#define ARTIFACT_TIER_COMMON 1
#define ARTIFACT_TIER_UNCOMMON 2
#define ARTIFACT_TIER_RARE 3
#define ARTIFACT_TIER_EXTREME 4

/// Main-effect tier weights for a large artifact, per band.
#define ARTIFACT_TIER_ODDS_GREEN list("1" = 62, "2" = 28, "3" = 9, "4" = 1)
#define ARTIFACT_TIER_ODDS_YELLOW list("1" = 45, "2" = 33, "3" = 18, "4" = 4)
#define ARTIFACT_TIER_ODDS_RED list("1" = 30, "2" = 34, "3" = 27, "4" = 9)

/// Chance a large artifact also carries a minor second effect.
#define ARTIFACT_SECOND_EFFECT_CHANCE 50

// ===== Effect strength =====
#define ARTIFACT_STRENGTH_SMALL "small"
#define ARTIFACT_STRENGTH_MEDIUM "medium"
#define ARTIFACT_STRENGTH_LARGE "large"
/// Strength weights per band: green leans small, red leans large.
#define ARTIFACT_STRENGTH_ODDS_GREEN list(ARTIFACT_STRENGTH_SMALL = 60, ARTIFACT_STRENGTH_MEDIUM = 30, ARTIFACT_STRENGTH_LARGE = 10)
#define ARTIFACT_STRENGTH_ODDS_YELLOW list(ARTIFACT_STRENGTH_SMALL = 35, ARTIFACT_STRENGTH_MEDIUM = 45, ARTIFACT_STRENGTH_LARGE = 20)
#define ARTIFACT_STRENGTH_ODDS_RED list(ARTIFACT_STRENGTH_SMALL = 15, ARTIFACT_STRENGTH_MEDIUM = 45, ARTIFACT_STRENGTH_LARGE = 40)

// ===== Release modes =====
#define ARTIFACT_RELEASE_TOUCH "touch"
#define ARTIFACT_RELEASE_AURA "aura"
#define ARTIFACT_RELEASE_PULSE "pulse"

// ===== Charge, per second =====
// Auras spend three times what the artifact refills, so an awake aura runs about a third of the time.
#define ARTIFACT_RECHARGE_PER_SECOND 0.5
#define ARTIFACT_AURA_COST_PER_SECOND 1.5
#define ARTIFACT_TOUCH_COST 3

// ===== Triggers =====
#define ARTIFACT_TRIGGER_TOUCH (1<<0)
#define ARTIFACT_TRIGGER_WATER (1<<1)
#define ARTIFACT_TRIGGER_ACID (1<<2)
#define ARTIFACT_TRIGGER_VOLATILE (1<<3)
#define ARTIFACT_TRIGGER_TOXIN (1<<4)
#define ARTIFACT_TRIGGER_IMPACT (1<<5)
#define ARTIFACT_TRIGGER_ENERGY (1<<6)
#define ARTIFACT_TRIGGER_HEAT (1<<7)
#define ARTIFACT_TRIGGER_COLD (1<<8)
#define ARTIFACT_TRIGGER_PLASMA (1<<9)
#define ARTIFACT_TRIGGER_CO2 (1<<10)
#define ARTIFACT_TRIGGER_PROXIMITY (1<<11)

/// Triggers read from the air on the artifact's tile every process.
#define ARTIFACT_TRIGGERS_AIR (ARTIFACT_TRIGGER_HEAT | ARTIFACT_TRIGGER_COLD | ARTIFACT_TRIGGER_PLASMA | ARTIFACT_TRIGGER_CO2)
/// Triggers held for as long as a condition lasts, rather than woken by a stimulus.
#define ARTIFACT_TRIGGERS_LEVEL (ARTIFACT_TRIGGERS_AIR | ARTIFACT_TRIGGER_PROXIMITY)

#define ARTIFACT_ALL_TRIGGERS list(\
	ARTIFACT_TRIGGER_TOUCH,\
	ARTIFACT_TRIGGER_WATER,\
	ARTIFACT_TRIGGER_ACID,\
	ARTIFACT_TRIGGER_VOLATILE,\
	ARTIFACT_TRIGGER_TOXIN,\
	ARTIFACT_TRIGGER_IMPACT,\
	ARTIFACT_TRIGGER_ENERGY,\
	ARTIFACT_TRIGGER_HEAT,\
	ARTIFACT_TRIGGER_COLD,\
	ARTIFACT_TRIGGER_PLASMA,\
	ARTIFACT_TRIGGER_CO2,\
	ARTIFACT_TRIGGER_PROXIMITY,\
)

// Trigger thresholds (Nova's values).
#define ARTIFACT_HEAT_AIR_KELVIN 375
#define ARTIFACT_HEAT_TOOL_KELVIN 700
#define ARTIFACT_COLD_AIR_KELVIN 225
#define ARTIFACT_GAS_TRIGGER_MOLES 10
#define ARTIFACT_PROXIMITY_RANGE 3
#define ARTIFACT_IMPACT_THROWFORCE 10

// Trigger families, as the analyser reports them.
#define ARTIFACT_FAMILY_CONTACT "contact"
#define ARTIFACT_FAMILY_ENERGY "energy"
#define ARTIFACT_FAMILY_AIR "air"

// ===== Waking =====
/// How long a contact stimulus keeps an effect awake; each artifact rolls once in this range.
#define ARTIFACT_WAKE_MIN (45 SECONDS)
#define ARTIFACT_WAKE_MAX (90 SECONDS)
/// How long a level trigger keeps an effect awake after its condition ends.
#define ARTIFACT_LEVEL_LINGER (6 SECONDS)
/// Hauling, bumping and repeated pats count as one touch per this long.
#define ARTIFACT_TOUCH_COOLDOWN (3 SECONDS)

// ===== Energy kinds =====
// Several effects share each kind, so the analyser narrows an artifact down without naming its effect.
#define ARTIFACT_ENERGY_CONCENTRATED "concentrated"
#define ARTIFACT_ENERGY_PSIONIC "psionic"
#define ARTIFACT_ENERGY_ELECTROMAGNETIC "electromagnetic"
#define ARTIFACT_ENERGY_PARTICLE "particle"
#define ARTIFACT_ENERGY_ORGANIC "organic"
#define ARTIFACT_ENERGY_BLUESPACE "bluespace"
#define ARTIFACT_ENERGY_SYNTHESIS "synthesis"

// ===== Labels =====
/// The second-effect field when the labeller thinks there is none. A correct "none" counts.
#define ARTIFACT_LABEL_NONE "Нет"

// ===== Scan and harvest lock =====
/// A lock nobody released frees itself after this long.
#define ARTIFACT_LOCK_TIMEOUT (2 MINUTES)

// ===== Harvesting =====
#define ARTIFACT_MAX_HARVESTS 3

/// do_after key for every xenoarchaeology action, so one person works one thing at a time.
#define DOAFTER_SOURCE_XENOARCH "doafter_xenoarch"

// ===== Signals, sent on the artifact =====
/// An effect woke: (datum/artifact_effect/effect)
#define COMSIG_ARTIFACT_EFFECT_ACTIVATED "artifact_effect_activated"
/// An effect went dormant: (datum/artifact_effect/effect)
#define COMSIG_ARTIFACT_EFFECT_DEACTIVATED "artifact_effect_deactivated"
/// A stimulus reached the artifact, whether or not anything woke: (trigger, mob/living/user, woke)
#define COMSIG_ARTIFACT_STIMULATED "artifact_stimulated"
/// A label was stuck on or scraped off: (datum/artifact_label/label_or_null, mob/user)
#define COMSIG_ARTIFACT_LABEL_CHANGED "artifact_label_changed"
/// The artifact was stamped as dug: (band)
#define COMSIG_ARTIFACT_STAMPED "artifact_stamped"
