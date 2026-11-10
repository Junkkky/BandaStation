/// Items never set the field off.
#define FIELD_ITEMS_IGNORED 0
/// Only conductive items set the field off; a steel bolt does.
#define FIELD_ITEMS_METAL 1
/// Any item heavy enough sets the field off.
#define FIELD_ITEMS_ANY 2

/// Its carrier keeps their footing: no field throws them and a gravitational field does not rip them.
#define FIELD_ARTEFACT_ANCHOR (1<<0)
/// Field throws carry its carrier much further.
#define FIELD_ARTEFACT_LIFT (1<<1)
/// Its carrier is not blinded by a flash field.
#define FIELD_ARTEFACT_BLINDPROOF (1<<2)
