#if defined _eventinho2_inc_
	#endinput
#endif
#define _eventinho2_inc_

enum EventoState
{
	EVENTO_STATE_ENDED,
	EVENTO_STATE_IN_COUNTDOWN_START,
	EVENTO_STATE_IN_COUNTDOWN_END,
	EVENTO_STATE_IN_PROGRESS
}

native EventoState Eventinho_GetCurrentState();
native bool Eventinho_IsParticipating(int client);
native bool Eventinho_IsBhopEnabled();

public SharedPlugin __pl_eventinho2 =
{
	name = "eventinho2",
	file = "eventinho2.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_eventinho2_SetNTVOptional()
{
	MarkNativeAsOptional("Eventinho_GetCurrentState");
	MarkNativeAsOptional("Eventinho_IsParticipating");
	MarkNativeAsOptional("Eventinho_IsBhopEnabled");
}
#endif