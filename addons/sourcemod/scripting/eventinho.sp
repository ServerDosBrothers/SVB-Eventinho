#include <sourcemod>
#include <morecolors>
#include <ripext>
#include <teammanager>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#include <eventinho>

#include <eventinho/globals_core.sp>

#include <eventinho/helpers.sp>

#include <eventinho/forwards_core.sp>
#include <eventinho/commands_core.sp>
#include <eventinho/natives_core.sp>

#include <eventinho/globals_evento.sp>
#include <eventinho/commands_evento.sp>
#include <eventinho/natives_evento.sp>

#include <eventinho/natives_event_reward.sp>
#include <eventinho/natives_event_reward_attribute.sp>
#include <eventinho/natives_event_requirement.sp>
#include <eventinho/natives_event_command.sp>

public Plugin myinfo =
{
	name = "eventinho",
	author = "Arthurdead/Mathx",
	description = "Plugin para ajudar staff nos eventos.",
	version = "",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int length)
{
	Register_Core_Natives();
	Register_Core_Forwards();

	Register_Evento_Natives();
	Register_EventCommand_Natives();
	Register_EventRequirement_Natives();
	Register_EventReward_Natives();
	Register_EventRewardAttribute_Natives();
	
	RegPluginLibrary("eventinho");

	return APLRes_Success;
}

public void OnPluginStart()
{
	Core_Init();
	Evento_Init();
	
	Register_Core_Commands();
	Register_Evento_Commands();
	
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}

	LoadTranslations("common.phrases");
}

public void OnPluginEnd()
{
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			OnClientDisconnect(i);
		}
	}
	
	OnMapEnd();
}

public void OnMapStart()
{
	
}

public void OnMapEnd()
{
	Eventinho_CancelEvent();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PostThinkPost, PostThinkPost);
}

stock void PostThinkPost(int client)
{
	if(PlayerSprite[client] != INVALID_ENT_REFERENCE) {
		float pos[3];
		GetClientAbsOrigin(client, pos);
		
		float hullmax[3];
		GetEntPropVector(client, Prop_Send, "m_vecMaxs", hullmax);
		
		pos[2] += hullmax[2];
		pos[2] += 20.0;
		
		TeleportEntity(PlayerSprite[client], pos, NULL_VECTOR, NULL_VECTOR);
	}
}

public void OnClientDisconnect(int client)
{
	Eventinho_Participate(client, false);

	g_tmpConvidarPlayer[client] = -1;

	if(client == g_TmpAdmin) {
		g_TmpAdmin = -1;
	}
}
