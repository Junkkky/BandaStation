/// An open ticket fixture without round-global notifications, timers or database side effects.
/datum/help_ticket/unit_test/New()
	set_ticket_type_id(TICKET_TYPE_ADMIN)
	messages = list()
	admin_replied = TRUE

/datum/client_interface/ticket_participant
	var/datum/admins/holder
	COOLDOWN_DECLARE(ticket_response)

/// An answered, assigned ticket accepts its owner and denies other players at message delivery.
/datum/unit_test/help_ticket_participants/Run()
	var/datum/help_ticket/ticket = allocate(/datum/help_ticket/unit_test)
	var/datum/client_interface/ticket_participant/owner = allocate(/datum/client_interface/ticket_participant)
	var/datum/client_interface/ticket_participant/other_player = allocate(/datum/client_interface/ticket_participant)
	var/datum/client_interface/assigned_staff = allocate(/datum/client_interface)
	ticket.initiator_key = owner.key
	ticket.initiator_client = owner.persistent_client
	ticket.linked_admin = assigned_staff.persistent_client
	TEST_ASSERT(GLOB.ticket_manager.can_send_message(owner, ticket), "The owner should be able to reply to their assigned ticket.")
	TEST_ASSERT(!GLOB.ticket_manager.add_ticket_message(other_player, ticket, "Routine update"), "An unrelated player must be refused at delivery.")
	TEST_ASSERT_EQUAL(length(ticket.messages), 0, "A refused reply must leave the history empty.")
