#if defined _eventinho_inc_
	#endinput
#endif
#define _eventinho_inc_

enum EventState
{
	EventStartCountdown,
	EventInProgress,
	EventEndCountdown,
	EventEnded,
};

enum EventRequirementType
{
	ReqUnknown,
	ReqBlacklistMaps,
	ReqWhitelistMaps,
	ReqPlayerTeam,
	ReqPlayerClass,
};

#define EVENTO_NENHUM_GANHDOR -1
#define EVENTO_CANCELADO -2

methodmap EventRewardAttribute < Handle
{
	public native int GetID();
	public native float GetValue();
};

methodmap EventReward < Handle
{
	public native int GetItemID();
	public native void GetModel(char[] model, int size);

	public native void GetAttributes(ArrayList list);
};

methodmap EventRequirement < Handle
{
	public native EventRequirementType GetType();
	public native void GetValues(ArrayList list);
};

methodmap EventCommand < Handle
{
	public native void GetName(char[] name, int size);
	public native void GetValue(char[] value, int size);
};

methodmap Evento < Handle
{
	public native void GetName(char[] name, int size);
	public native void GetDescription(char[] desc, int size);
	
	public native void GetStartCommands(ArrayList list);
	public native void GetEndCommands(ArrayList list);

	public native void GetRequirements(ArrayList list);
	public native void GetRewards(ArrayList list);
	
	public native void SetState(EventState state);
	public native EventState GetState();
	
	public native StringMap GetOptions();
};

native void Eventinho_FindEvento(const char[] nome, Evento &even);
native void Eventinho_GetAllEvents(ArrayList list);
native Evento Eventinho_CurrentEvent();
native bool Eventinho_StartEvent(const char[] nome, StringMap options, float countdown=0.0);
native bool Eventinho_EndEvent(ArrayList winners, float countdown=0.0);
native bool Eventinho_Participate(int client, bool is);
native bool Eventinho_IsParticipating(int client);
native void Eventinho_ReDisplayOptionsMenu(int client, const char[] event, StringMap options);

forward void Eventinho_OnEventStateChanged(Evento event);
forward void Eventinho_OnPlayerWonEvent(int client, Evento event);
forward void Eventinho_OnPlayerParticipating(int client, Evento event, bool is);
forward void Eventinho_OnEventStarted(Evento event, StringMap options, int admin);
forward void Eventinho_ModifyDefaultOptions(const char[] name, StringMap options);
forward bool Eventinho_HandleMenuOption(int client, const char[] event, StringMap options, const char[] name, char[] value, int length);

stock bool Eventinho_CancelEvent() {
	return Eventinho_EndEvent(null, 0.0);
}

stock bool Eventinho_InEvent() {
	return (Eventinho_CurrentEvent() != null);
}

stock EventState Eventinho_CurrentEventState() {
	Evento evento = Eventinho_CurrentEvent();
	if(evento == null) {
		return EventEnded;
	} else {
		return evento.GetState();
	}
}

public SharedPlugin __pl_eventinho =
{
	name = "eventinho",
	file = "eventinho.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_eventinho_SetNTVOptional()
{
	MarkNativeAsOptional("Evento.GetName");
	MarkNativeAsOptional("Evento.GetDescription");
	MarkNativeAsOptional("Evento.GetStartCommands");
	MarkNativeAsOptional("Evento.GetEndCommands");
	MarkNativeAsOptional("Evento.GetRequirements");
	MarkNativeAsOptional("Evento.GetRewards");
	MarkNativeAsOptional("Evento.SetState");
	MarkNativeAsOptional("Evento.GetState");
	MarkNativeAsOptional("Evento.GetOptions");

	MarkNativeAsOptional("EventRequirement.GetType");
	MarkNativeAsOptional("EventRequirement.GetValues");

	MarkNativeAsOptional("EventReward.GetItemID");
	MarkNativeAsOptional("EventReward.GetModel");
	MarkNativeAsOptional("EventReward.GetAttributes");

	MarkNativeAsOptional("EventRewardAttribute.GetID");
	MarkNativeAsOptional("EventRewardAttribute.GetValue");

	MarkNativeAsOptional("EventCommand.GetName");
	MarkNativeAsOptional("EventCommand.GetValue");
	
	MarkNativeAsOptional("Eventinho_FindEvento");
	MarkNativeAsOptional("Eventinho_GetAllEvents");
	MarkNativeAsOptional("Eventinho_CurrentEvent");
	MarkNativeAsOptional("Eventinho_StartEvent");
	MarkNativeAsOptional("Eventinho_EndEvent");
	MarkNativeAsOptional("Eventinho_Participate");
	MarkNativeAsOptional("Eventinho_IsParticipating");
}
#endif
