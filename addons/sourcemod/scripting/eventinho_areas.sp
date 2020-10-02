#include <sourcemod>
#include <morecolors>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <teammanager>

#pragma semicolon 1
#pragma newdecls required

#include <eventinho>
#include <eventinho/helpers.sp>

public Plugin myinfo =
{
	name = "eventinho_areas",
	author = "Arthurdead",
	description = "",
	version = "",
	url = ""
};

#define CHAT_PREFIX "{dodgerblue}[Evento]{default} "

KeyValues kvEventinhoAreas = null;
int iAreasMapKVID = -1;
char szLastArea[64];
float g_RedTeleport[3] = {0.0, ...};
float g_BlueTeleport[3] = {0.0, ...};
bool g_bTeleported[MAXPLAYERS+1] = {false, ...};
bool g_bManualTeleportRed = false;
bool g_bManualTeleportBlue = false;
int g_TmpAdmin = -1;

public void OnPluginStart()
{
	RegAdminCmd("sm_reloadareas", ConCommand_ReloadAreas, ADMFLAG_ROOT);
	RegAdminCmd("sm_getpos", ConCommand_GetPos, ADMFLAG_ROOT);
	RegAdminCmd("sm_setteleport", ConCommand_SetTeleport, ADMFLAG_ROOT);
	RegAdminCmd("sm_resetteleport", ConCommand_ResetTeleport, ADMFLAG_ROOT);
	
	char filepath[64];
	BuildPath(Path_SM, filepath, sizeof(filepath), "data/eventinho_areas.txt");
	
	kvEventinhoAreas = new KeyValues("eventinho_areas");
	if(!kvEventinhoAreas.ImportFromFile(filepath)) {
		PrintToServer("[Evento] Faltando arquivo de areas.");
		delete kvEventinhoAreas;
	}

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
}

public void Eventinho_ModifyDefaultOptions(const char[] name, StringMap options)
{
	options.SetString("Teleport", "ON");

	if(iAreasMapKVID != -1) {
		//options.SetString("Area", "test");
	}
}

stock int MenuHandler_Areas(Menu menu, MenuAction action, int param1, int param2)
{
	char optionsid[64];
	menu.GetItem(0, optionsid, sizeof(optionsid));
	
	StringMap options = view_as<StringMap>(StringToInt(optionsid));
	
	char title[64];
	menu.GetTitle(title, sizeof(title));
	
	char eventname[64];
	FindSubstrReverse(title, " - Areas", eventname, sizeof(eventname));
	
	if(action == MenuAction_Select) {
		char name[64];
		menu.GetItem(param2, name, sizeof(name));
		
		options.SetString("Area", name);
		
		Eventinho_ReDisplayOptionsMenu(param1, eventname, options);
	} else if(action == MenuAction_End) {
		
		Eventinho_ReDisplayOptionsMenu(param1, eventname, options);
		
		delete menu;
	}
}

public bool Eventinho_HandleMenuOption(int client, const char[] event, StringMap options, const char[] name, char[] value, int length)
{
	g_TmpAdmin = client;

	if(StrEqual(name, "Area")) {
		Handle style = GetMenuStyleHandle(MenuStyle_Default);
		Menu menu = CreateMenuEx(style, MenuHandler_Areas, MENU_ACTIONS_DEFAULT);
		
		SetMenuTitleFormated(menu, "%s - Areas", event);
		
		ArrayList list = new ArrayList(64);
		GetAllAreas(list);
		
		for(int i = 0; i < list.Length; i++) {
			char area[64];
			list.GetString(i, area, sizeof(area));
			
			menu.AddItem(area, area, ITEMDRAW_DEFAULT);
		}
		
		delete list;
		
		char optionsid[64];
		IntToString(view_as<int>(options), optionsid, sizeof(optionsid));
		
		menu.InsertItem(0, optionsid, optionsid, ITEMDRAW_IGNORE);
		
		menu.Display(client, MENU_TIME_FOREVER);

		return true;
	} else if(StrEqual(name, "Teleport")) {
		if(StrEqual(value, "ON")) {
			strcopy(value, length, "OFF");
		} else if(StrEqual(value, "OFF")) {
			strcopy(value, length, "ON");
		}
		options.SetString("Teleport", value);

		Eventinho_ReDisplayOptionsMenu(client, event, options);
		return true;
	}
	
	return false;
}

public void OnClientDisconnect(int player)
{
	g_bTeleported[player] = false;
	if(player == g_TmpAdmin) {
		g_TmpAdmin = -1;
	}
}

stock bool HasTeleport(float teleport[3])
{
	return (teleport[0] != 0.0 || teleport[1] != 0.0 || teleport[2] != 0.0);
}

public void Eventinho_OnEventStateChanged(Evento event)
{
	EventState state = event.GetState();
	if(state == EventEnded) {
		g_bManualTeleportRed = false;
		g_bManualTeleportBlue = false;
		g_TmpAdmin = -1;

		for(int i = 1; i <= MaxClients; i++) {
			if(g_bTeleported[i]) {
				TF2_RespawnPlayer(i);
			}
			g_bTeleported[i] = false;
		}

		RemoveAllDoors();
		g_RedTeleport = NULL_VECTOR;
		g_BlueTeleport = NULL_VECTOR;

		//poe isso em outro lugar
		char nome[64];
		event.GetName(nome, sizeof(nome));

		if(StrEqual(nome, "Battle Royale")) {
			for(int i = 1; i <= MaxClients; i++) {
				if(IsClientInGame(i) && !IsFakeClient(i)) {
					TeamManager_SetPlayerFF(i, false);
				}
			}
		}
	}
}

void GetTeleport(int client, float teleport[3])
{
	if(IsClientInGame(client)) {
		int team = GetClientTeam(client);
		if(team == 2) {
			teleport[0] = g_RedTeleport[0];
			teleport[1] = g_RedTeleport[1];
			teleport[2] = g_RedTeleport[2];
		} else if(team == 3) {
			teleport[0] = g_BlueTeleport[0];
			teleport[1] = g_BlueTeleport[1];
			teleport[2] = g_BlueTeleport[2];
		}
	}
}

public void Eventinho_OnPlayerParticipating(int client, Evento event, bool is)
{
	char nome[64];
	if(event) {
		event.GetName(nome, sizeof(nome));
	}

	if(!is) {
		if(g_bTeleported[client]) {
			TF2_RespawnPlayer(client);
		}
		g_bTeleported[client] = false;
	} else {
		if(event.GetState() == EventInProgress) {
			Teleport_Player(client, true, nome);
		}
	}

	//poe isso em outro lugar
	if(IsClientInGame(client) && !IsFakeClient(client)) {
		if(!is) {
			if(StrEqual(nome, "Battle Royale")) {
				TeamManager_SetPlayerFF(client, false);
			}
		}
	}
}

stock void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("userid"));
	int flags = event.GetInt("death_flags");

	if(!(flags & TF_DEATHFLAG_DEADRINGER)) {
		g_bTeleported[player] = false;
	}
}

stock void Teleport_Player(int player, bool print, const char[] nome)
{
	if(!g_bTeleported[player]) {
		float teleport[3];
		GetTeleport(player, teleport);
		if(HasTeleport(teleport)) {
			TeleportEntity(player, teleport, NULL_VECTOR, NULL_VECTOR);
			TF2_RegeneratePlayer(player);
			g_bTeleported[player] = true;
			if(print) {
				CPrintToChat(player, CHAT_PREFIX ... "Você foi teleportado para o local do %s.", nome);
			}
		}
	}
}

stock void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int player = GetClientOfUserId(userid);

	Evento evento = Eventinho_CurrentEvent();
	if(evento && evento.GetState() == EventInProgress) {
		if(Eventinho_IsParticipating(player)) {
			char nome[64];
			event.GetName(nome, sizeof(nome));

			Teleport_Player(player, true, nome);
		}
	}
}

stock void FrameTeleport(DataPack data)
{
	data.Reset();

	int i = data.ReadCell();
	
	char nome[32];
	data.ReadString(nome, sizeof(nome));

	Teleport_Player(i, true, nome);

	delete data;
}

public void Eventinho_OnEventStarted(Evento event, StringMap options, int admin)
{
	g_TmpAdmin = admin;

	options.GetString("Area", szLastArea, sizeof(szLastArea));
	
	CreateDoorsFromArea(szLastArea);

	char tele[5];
	options.GetString("Teleport", tele, sizeof(tele));
	if(StrEqual(tele, "ON")) {
		if(g_TmpAdmin >= 1) {
			if(!g_bManualTeleportRed) {
				GetClientAbsOrigin(g_TmpAdmin, g_RedTeleport);
			}
			if(!g_bManualTeleportBlue) {
				GetClientAbsOrigin(g_TmpAdmin, g_BlueTeleport);
			}
		}
	} else if(StrEqual(tele, "OFF")) {
		g_RedTeleport = NULL_VECTOR;
		g_BlueTeleport = NULL_VECTOR;
		g_bManualTeleportRed = false;
		g_bManualTeleportBlue = false;
	}

	char nome[64];
	event.GetName(nome, sizeof(nome));

	for(int i = 1; i <= MaxClients; i++) {
		if(Eventinho_IsParticipating(i)) {
			int class = view_as<int>(TF2_GetPlayerClass(i));

			char out[32];
			if(!ClassSupportsEventEx(event, class, out, sizeof(out))) {
				TFClassType needclass = TF2_GetClass(out);
				if(needclass != TFClass_Unknown) {
					TF2_SetPlayerClass(i, needclass, true, true);
					TF2_RegeneratePlayer(i);
				}
			}

			int team = GetClientTeam(i);

			strcopy(out, sizeof(out), "");
			if(!TeamSupportsEventEx(event, team, out, sizeof(out))) {
				int index = GetTeamIndex(out);
				if(index != -1) {
					TeamManager_SetEntityTeam(i, index, true);
				}
			}

			DataPack data = new DataPack();
			data.WriteCell(i);
			data.WriteString(nome);
			RequestFrame(FrameTeleport, data);
		}
	}

	//poe isso em outro lugar
	/*if(StrEqual(nome, "Battle Royale")) {
		for(int i = 1; i <= MaxClients; i++) {
			if(IsClientInGame(i) && !IsFakeClient(i)) {
				if(Eventinho_IsParticipating(i)) {
					TeamManager_SetPlayerFF(i, true);
				}
			}
		}
	}*/

	g_TmpAdmin = -1;
}

stock bool TraceEntityFilterWorld(int entity, int contentsMask, any data)
{
	if(entity != 0 || entity == data) {
		return false;
	}
	
	return true;
}

stock void GetAimPos(int client, float pos[3])
{
	float eyepos[3];
	GetClientEyePosition(client, eyepos);
	
	float eyeangles[3];
	GetClientEyeAngles(client, eyeangles);
	
	TR_TraceRayFilter(eyepos, eyeangles, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceEntityFilterWorld, client);
	if(TR_DidHit())
	{
		float start[3];
		TR_GetEndPosition(start);

		float fwd[3];
		GetAngleVectors(eyeangles, fwd, NULL_VECTOR, NULL_VECTOR);
		
		float newpos[3];
		newpos[0] = start[0] + (fwd[0] * -35.0);
		newpos[1] = start[1] + (fwd[1] * -35.0);
		newpos[2] = start[2] + (fwd[2] * -35.0);

		pos = newpos;
	}
}

stock Action ConCommand_ResetTeleport(int client, int args)
{
	if(args < 1) {
		CReplyToCommand(client, CHAT_PREFIX ... "Usagem: sm_resetteleport <red/blue/both>");
		return Plugin_Handled;
	}

	Evento evento = Eventinho_CurrentEvent();
	
	/*if(!evento) {
		CReplyToCommand(client, CHAT_PREFIX ... "Não há nenhum evento em andamento.");
		return Plugin_Handled;
	}*/

	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));

	if(StrEqual(arg1, "red")) {
		g_RedTeleport = NULL_VECTOR;
		g_bManualTeleportRed = false;
	} else if(StrEqual(arg1, "blue")) {
		g_BlueTeleport = NULL_VECTOR;
		g_bManualTeleportBlue = false;
	} else if(StrEqual(arg1, "both")) {
		g_RedTeleport = NULL_VECTOR;
		g_BlueTeleport = NULL_VECTOR;
		g_bManualTeleportRed = false;
		g_bManualTeleportBlue = false;
	} else {
		CReplyToCommand(client, CHAT_PREFIX ... "Usagem: sm_resetteleport <red/blue/both>");
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

stock Action ConCommand_SetTeleport(int client, int args)
{
	if(client == 0) {
		CReplyToCommand(client, CHAT_PREFIX ... "Você precisa estar presente no jogo.");
		return Plugin_Handled;
	}

	Evento evento = Eventinho_CurrentEvent();
	
	/*if(!evento) {
		CReplyToCommand(client, CHAT_PREFIX ... "Não há nenhum evento em andamento.");
		return Plugin_Handled;
	}*/

	if(args < 1) {
		CReplyToCommand(client, CHAT_PREFIX ... "Usagem: sm_setteleport <red/blue/both>");
		return Plugin_Handled;
	}

	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));

	char nome[64];
	if(evento) {
		evento.GetName(nome, sizeof(nome));
	}

	if(StrEqual(arg1, "red")) {
		GetClientAbsOrigin(client, g_RedTeleport);
		CReplyToCommand(client, CHAT_PREFIX ... "%s RED teleport em %.2f %.2f %.2f.", nome, g_RedTeleport[0], g_RedTeleport[1], g_RedTeleport[2]);
		g_bManualTeleportRed = true;
	} else if(StrEqual(arg1, "blue")) {
		GetClientAbsOrigin(client, g_BlueTeleport);
		CReplyToCommand(client, CHAT_PREFIX ... "%s BLUE teleport em %.2f %.2f %.2f.", nome, g_BlueTeleport[0], g_BlueTeleport[1], g_BlueTeleport[2]);
		g_bManualTeleportBlue = true;
	} else if(StrEqual(arg1, "both")) {
		GetClientAbsOrigin(client, g_RedTeleport);
		GetClientAbsOrigin(client, g_BlueTeleport);
		CReplyToCommand(client, CHAT_PREFIX ... "%s Teleport em %.2f %.2f %.2f.", nome, g_RedTeleport[0], g_RedTeleport[1], g_RedTeleport[2]);
		g_bManualTeleportRed = true;
		g_bManualTeleportBlue = true;
	} else {
		CReplyToCommand(client, CHAT_PREFIX ... "Usagem: sm_setteleport <red/blue/both>");
		return Plugin_Handled;
	}

	if(evento) {
		if(evento.GetState() == EventInProgress) {
			for(int i = 1; i <= MaxClients; i++) {
				if(Eventinho_IsParticipating(i)) {
					Teleport_Player(i, true, nome);
				}
			}
		}
	}

	return Plugin_Handled;
}

stock Action ConCommand_GetPos(int client, int args)
{
	float pos[3];
	if(args == 0) {
		GetClientAbsOrigin(client, pos);
	} else {
		GetAimPos(client, pos);
	}
	
	PrintToChat(client, "%f %f %f", pos[0], pos[1], pos[2]);
	
	return Plugin_Handled;
}

stock Action ConCommand_ReloadAreas(int client, int args)
{
	RemoveAllDoors();
	
	delete kvEventinhoAreas;
	kvEventinhoAreas = new KeyValues("eventinho_areas");
	
	char filepath[64];
	BuildPath(Path_SM, filepath, sizeof(filepath), "data/eventinho_areas.txt");
	
	if(!kvEventinhoAreas.ImportFromFile(filepath)) {
		CReplyToCommand(client, CHAT_PREFIX ... "Faltando arquivo de areas.", filepath);
		delete kvEventinhoAreas;
		iAreasMapKVID = -1;
	} else {
		char map[64];
		GetCurrentMap(map, sizeof(map));
		
		kvEventinhoAreas.Rewind();
		
		if(kvEventinhoAreas.JumpToKey(map)) {
			kvEventinhoAreas.GetSectionSymbol(iAreasMapKVID);
		} else {
			CReplyToCommand(client, CHAT_PREFIX ... "Faltando mapa %s no arquivo de areas.", map);
			iAreasMapKVID = -1;
		}
	}
	
	if(Eventinho_InEvent()) {
		CreateDoorsFromArea(szLastArea);
	}
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	if(kvEventinhoAreas) {
		char map[64];
		GetCurrentMap(map, sizeof(map));
		
		kvEventinhoAreas.Rewind();
		
		if(kvEventinhoAreas.JumpToKey(map)) {
			kvEventinhoAreas.GetSectionSymbol(iAreasMapKVID);
			
			if(Eventinho_InEvent()) {
				CreateDoorsFromArea(szLastArea);
			}
		} else {
			PrintToServer("[Evento] Faltando mapa %s no arquivo de areas.", map);
		}
	}
}

public void OnMapEnd()
{
	iAreasMapKVID = -1;
}

public void OnPluginEnd()
{
	RemoveAllDoors();
}

stock void GetAllAreas(ArrayList list)
{
	if(iAreasMapKVID == -1) {
		PrintToServer("[Evento] Faltando mapa no arquivo de mapas.");
		return;
	}
	
	kvEventinhoAreas.Rewind();
	
	kvEventinhoAreas.JumpToKeySymbol(iAreasMapKVID);
	
	if(!kvEventinhoAreas.GotoFirstSubKey(false)) {
		PrintToServer("[Evento] Mapa faltando areas.");
		return;
	}
	
	while(true)
	{
		char name[64];
		kvEventinhoAreas.GetSectionName(name, sizeof(name));
		
		list.PushString(name);
		
		if(!kvEventinhoAreas.GotoNextKey(false)) {
			break;
		}
	}
}

stock void CreateDoorsFromArea(const char[] area)
{
	if(iAreasMapKVID == -1) {
		PrintToServer("[Evento] Faltando mapa no arquivo de mapas.");
		return;
	}
	
	kvEventinhoAreas.Rewind();
	
	kvEventinhoAreas.JumpToKeySymbol(iAreasMapKVID);
	
	if(!kvEventinhoAreas.JumpToKey(area)) {
		PrintToServer("[Evento] Mapa nao tem area com nome %s.", area);
		return;
	}
	
	if(!kvEventinhoAreas.JumpToKey("doors")) {
		PrintToServer("[Evento] Area %s nao tem portas.", area);
		return;
	}
	
	if(!kvEventinhoAreas.GotoFirstSubKey(false)) {
		PrintToServer("[Evento] %s portas faltando valores.", area);
		return;
	}
	
	RemoveAllDoors();
	
	while(true)
	{
		char name[64];
		kvEventinhoAreas.GetSectionName(name, sizeof(name));
		
		float end[3];
		kvEventinhoAreas.GetVector(NULL_STRING, end);
		
		char buffers[3][sizeof(name)];
		ExplodeString(name, " ", buffers, sizeof(buffers), sizeof(buffers[]));
		
		float start[3];
		start[0] = StringToFloat(buffers[0]);
		start[1] = StringToFloat(buffers[1]);
		start[2] = StringToFloat(buffers[2]);
		
		CreateDoorsFromLine(start, end);
		
		if(!kvEventinhoAreas.GotoNextKey(false)) {
			break;
		}
	}
}

stock void RotateVector(const float vec[3], const float angles[3], float result[3])
{
	float rad[3];
	rad[0] = DegToRad(angles[2]);
	rad[1] = DegToRad(angles[0]);
	rad[2] = DegToRad(angles[1]);

	float cosAlpha = Cosine(rad[0]);
	float sinAlpha = Sine(rad[0]);
	
	float cosBeta = Cosine(rad[1]);
	float sinBeta = Sine(rad[1]);
	
	float cosGamma = Cosine(rad[2]);
	float sinGamma = Sine(rad[2]);

	float x = vec[0];
	float y = vec[1];
	float z = vec[2];
	
	float newX = 0.0;
	float newY = 0.0;
	float newZ = 0.0;
	
	newY = cosAlpha*y - sinAlpha*z;
	newZ = cosAlpha*z + sinAlpha*y;
	y = newY;
	z = newZ;

	newX = cosBeta*x + sinBeta*z;
	newZ = cosBeta*z - sinBeta*x;
	x = newX;
	z = newZ;

	newX = cosGamma*x - sinGamma*y;
	newY = cosGamma*y + sinGamma*x;
	x = newX;
	y = newY;
	
	result[0] = x;
	result[1] = y;
	result[2] = z;
}

stock int SpawnDoor(const float pos[3], const float ang[3])
{
	int door = CreateEntityByName("prop_door_rotating");
	
	float offset[3];
	//offset[0] -= 35.0;
	offset[2] += 50.0;
	RotateVector(offset, ang, offset);
	
	float newpos[3];
	newpos = pos;
	AddVectors(newpos, offset, newpos);
	
	TeleportEntity(door, newpos, ang, NULL_VECTOR);
	
	DispatchKeyValue(door, "model", "models/props_c17/door01_left.mdl");
	DispatchKeyValue(door, "hardware","1");
	DispatchKeyValue(door, "distance","90");
	DispatchKeyValue(door, "speed","100");
	DispatchKeyValue(door, "returndelay","-1");
	DispatchKeyValue(door, "spawnflags","8192");
	DispatchKeyValue(door, "axis", "131.565 1302.86 2569, 131.565 1302.86 2569");
	DispatchSpawn(door);
	ActivateEntity(door);
	return door;
}

stock void CreateDoorsFromLine(const float start[3], const float end[3])
{
	float lastpos[3];
	lastpos = start;
	
	while(true)
	{
		float dist = GetVectorDistance(lastpos, end);
		if(dist <= 30.0) {
			break;
		}
		
		float currpos[3];
		SubtractVectors(end, lastpos, currpos);
		
		float ang[3];
		GetVectorAngles(currpos, ang);
		ang[1] += 90.0;
		
		NormalizeVector(currpos, currpos);
		ScaleVector(currpos, 3200.0 * GetTickInterval());
		AddVectors(currpos, lastpos, currpos);
		
		SpawnDoor(currpos, ang);
		
		lastpos = currpos;
	}
}

stock void RemoveAllDoors()
{
	int door = -1;
	while(true)
	{
		door = FindEntityByClassname(door, "prop_door_rotating");
		if(door == -1) {
			break;
		}
		
		char model[64];
		GetEntPropString(door, Prop_Data, "m_ModelName", model, sizeof(model));
		
		if(StrEqual(model, "models/props_doors/doormainmetal01.mdl") ||
			StrEqual(model, "models/props_c17/door01_left.mdl")) {
			RemoveEntity(door);
		}
	}
}
