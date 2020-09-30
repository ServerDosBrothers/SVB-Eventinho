stock void Register_Core_Natives()
{
	CreateNative("Eventinho_FindEvento", Native_Eventinho_FindEvento);
	CreateNative("Eventinho_GetAllEvents", Native_Eventinho_GetAllEvents);
	CreateNative("Eventinho_CurrentEvent", Native_Eventinho_CurrentEvent);
	CreateNative("Eventinho_StartEvent", Native_Eventinho_StartEvent);
	CreateNative("Eventinho_EndEvent", Native_Eventinho_EndEvent);
	CreateNative("Eventinho_Participate", Native_Eventinho_Participate);
	CreateNative("Eventinho_IsParticipating", Native_Eventinho_IsParticipating);
	CreateNative("Eventinho_ReDisplayOptionsMenu", Native_Eventinho_ReDisplayOptionsMenu);
}

stock void ChatAndHUD(int client, const char[] format, any ...)
{
	char buffer[255];
	VFormat(buffer, sizeof(buffer), format, 3);

	CPrintToChat(client, buffer);

	CRemoveTags(buffer, sizeof(buffer));

	SetHudTextParams(-1.0, 0.2, 5.0, 30, 144, 255, 255, 1, 0.5, 0.5, 0.5);
	ShowHudText(client, -1, buffer);
}

stock void ChatAndHUDAll(const char[] format, any ...)
{
	char buffer[255];
	VFormat(buffer, sizeof(buffer), format, 2);

	char buffer2[255];
	strcopy(buffer2, sizeof(buffer2), buffer);

	CRemoveTags(buffer2, sizeof(buffer2));

	SetHudTextParams(-1.0, 0.2, 5.0, 30, 144, 255, 255, 1, 0.5, 0.5, 0.5);

	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			ShowHudText(i, -1, buffer2);
			CPrintToChat(i, buffer);
		}
	}
}

stock int Native_Eventinho_CurrentEvent(Handle plugin, int params)
{
	return view_as<int>(hCurrentEvent);
}

stock bool __Eventinho_StartEvent_IMPL(const char[] nome, StringMap options, float countdown)
{
	if(Eventinho_InEvent()) {
		Eventinho_CancelEvent();
	}

	CloseTimers();
	
	Eventinho_FindEvento(nome, hCurrentEvent);
	if(hCurrentEvent == null) {
		PrintToServer("[Evento] %s não encontrado.", nome);
		return false;
	}
	
	if(!MapSupportsEvent(hCurrentEvent)) {
		hCurrentEvent.SetState(EventEnded);
		PrintToServer("[Evento] Mapa não supporta %s.", nome);
		delete hCurrentEvent;
		return false;
	}
	
	if(options != null) {
		char value[64];
		if(options.GetString("Preparaçao", value, sizeof(value))) {
			if(StrEqual(value, "OFF")) {
				countdown = 0.0;
			}
		}
	}
	
	if(countdown > 0.1) {
		hCurrentEvent.SetState(EventStartCountdown);
		DataPack data = null;
		hCountdownTimer = CreateDataTimer(countdown, Timer_StartEvent, data);
		data.WriteCell(view_as<int>(hCurrentEvent));
		data.WriteCell(view_as<int>(options));

		data = null;
		hWarmTimer = CreateDataTimer(0.0, Timer_EventWarn, data);
		data.WriteCell(view_as<int>(hCurrentEvent));
		data.WriteFloat(countdown);
		data.WriteFloat(DEFAULT_WARN_COUNTDOWN);
		data.WriteCell(1);
	} else {
		__Internal_StartEvent(hCurrentEvent, options);
	}
	
	return true;
}

stock void TimeName(float time, char[] spec, int size)
{
	if(time >= 60) {
		if(time == 1) {
			strcopy(spec, size, "minuto");
		} else {
			strcopy(spec, size, "minutos");
		}
	} else {
		if(time == 1) {
			strcopy(spec, size, "segundo");
		} else {
			strcopy(spec, size, "segundos");
		}
	}
}

stock Action Timer_EventWarn(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	
	Evento event = view_as<Evento>(pack.ReadCell());
	float countdown = pack.ReadFloat();
	float repeat = pack.ReadFloat();
	bool start = pack.ReadCell();

	if(countdown >= 1) {
		float time = countdown;

		char spec_min[10];
		TimeName(time, spec_min, sizeof(spec_min));

		if(time >= 60) {
			time /= 60;
		}

		int time_min = RoundToFloor(time);

		char nome[64];
		event.GetName(nome, sizeof(nome));

		if(start) {
			ChatAndHUDAll(CHAT_PREFIX ... "%s começa em %i %s digite !evento para participar", nome, time_min, spec_min);
		} else {
			CPrintToChatAll(CHAT_PREFIX ... "%s termina em %i %s", nome, time_min, spec_min);
		}

		countdown -= repeat;

		pack = null;
		hWarmTimer = CreateDataTimer(repeat, Timer_EventWarn, pack);
		pack.WriteCell(view_as<int>(event));
		pack.WriteFloat(countdown);
		pack.WriteFloat(repeat);
		pack.WriteCell(start);
	} else {
		KillTimer(hWarmTimer);
		hWarmTimer = null;
	}
	
	return Plugin_Continue;
}

stock int Native_Eventinho_StartEvent(Handle plugin, int params)
{
	int len = 0;
	GetNativeStringLength(1, len);
	len++;
	
	char[] nome = new char[len];
	GetNativeString(1, nome, len);
	
	float countdown = GetNativeCell(3);
	
	StringMap options = view_as<StringMap>(GetNativeCell(2));
	
	if(!__Eventinho_StartEvent_IMPL(nome, options, countdown)) {
		return 0;
	}
	
	return 1;
}

stock Action Timer_StartEvent(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	
	Evento event = view_as<Evento>(pack.ReadCell());
	StringMap options = view_as<StringMap>(pack.ReadCell());
	
	__Internal_StartEvent(event, options);
	
	hCountdownTimer = null;
	
	return Plugin_Continue;
}

stock void FindOptionCommand(const char[] option, char[] command, int len)
{
	StringMapSnapshot snapshot = hOptionsMap.Snapshot();
	
	bool found = false;
	
	for(int i = 0; i < snapshot.Length; i++) {
		char key[64];
		snapshot.GetKey(i, key, sizeof(key));
		
		char value[64];
		hOptionsMap.GetString(key, value, sizeof(value));
		
		if(StrEqual(value, option)) {
			found = true;
			strcopy(command, len, key);
			break;
		}
	}
	
	delete snapshot;
	
	if(!found) {
		strcopy(command, len, "");
	}
}

stock void Get0Or1(const char[] value, char[] res, int len)
{
	if(StrEqual(value, "ON")) {
		strcopy(res, len, "1");
	} else if(StrEqual(value, "OFF")) {
		strcopy(res, len, "0");
	}
}

stock void __Internal_StartEvent(Evento event, StringMap options)
{
	event.SetState(EventInProgress);
	
	char nome[64];
	event.GetName(nome, sizeof(nome));
	
	ArrayList commands = new ArrayList();
	hCurrentEvent.GetStartCommands(commands);
	
	int length = commands.Length;
	for(int i = 0; i < length; i++) {
		EventCommand command = commands.Get(i);

		char key[64];
		command.GetName(key, sizeof(key));
		
		char value[64];
		command.GetValue(value, sizeof(value));
		
		delete command;
		
		Get0Or1(value, value, sizeof(value));
		
		FindOptionCommand(key, key, sizeof(key));
		
		if(StrEmpty(key)) {
			continue;
		}

		ServerCommand("%s %s", key, value);
	}
	
	delete commands;

	bool countdown = false;

	char value[64];
	if(options.GetString("Preparaçao", value, sizeof(value))) {
		if(!StrEqual(value, "OFF")) {
			countdown = true;
		}
	}
	
	if(countdown) {
		CPrintToChatAll(CHAT_PREFIX ... "%s começado.", nome);
	} else {
		ChatAndHUDAll(CHAT_PREFIX ... "%s começado digite !evento para participar.", nome);
	}

	Call_StartForward(hOnEventStarted);
	Call_PushCell(event);
	Call_PushCell(options);
	Call_PushCell(g_TmpAdmin);
	Call_Finish();
}

stock int Native_Eventinho_EndEvent(Handle plugin, int params)
{
	if(!Eventinho_InEvent()) {
		return 0;
	}
	
	ArrayList winners = GetNativeCell(1);
	float countdown = GetNativeCell(2);
	
	CloseTimers();

	if(countdown > 0.1) {
		hCurrentEvent.SetState(EventEndCountdown);
		DataPack data = null;
		hCountdownTimer = CreateDataTimer(countdown, Timer_EndEvent, data);
		data.WriteCell(view_as<int>(hCurrentEvent));
		data.WriteCell(view_as<int>(winners));

		data = null;
		hWarmTimer = CreateDataTimer(0.0, Timer_EventWarn, data);
		data.WriteCell(view_as<int>(hCurrentEvent));
		data.WriteFloat(countdown);
		data.WriteFloat(DEFAULT_WARN_COUNTDOWN);
		data.WriteCell(0);
	} else {
		__Internal_EndEvent(hCurrentEvent, winners);
	}
	
	return 1;
}

stock Action Timer_EndEvent(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	
	Evento event = view_as<Evento>(pack.ReadCell());
	ArrayList winners = view_as<ArrayList>(pack.ReadCell());
	
	__Internal_EndEvent(event, winners);
	
	hCountdownTimer = null;
	
	return Plugin_Continue;
}

//tira isso dps
#include <stocksoup/tf/tempents_stocks.inc>

stock void __Internal_EndEvent(Evento event, ArrayList winners)
{
	event.SetState(EventEnded);
	
	ArrayList commands = new ArrayList();
	hCurrentEvent.GetStartCommands(commands);
	
	int length = commands.Length;
	for(int i = 0; i < length; i++) {
		EventCommand command = commands.Get(i);

		char key[64];
		command.GetName(key, sizeof(key));
		
		char value[64];
		command.GetValue(value, sizeof(value));
		
		delete command;
		
		ServerCommand("%s %s", key, value);
	}
	
	delete commands;
	
	char nome[64];
	event.GetName(nome, sizeof(nome));
	
	if(winners != null) {
		bool found = false;
		
		length = winners.Length;
		for(int i = 0; i < length; i++) {
			int client = winners.Get(i);
			
			if(!Eventinho_IsParticipating(client)) {
				winners.Erase(i);
				continue;
			}

			float origin[3];
			GetClientAbsOrigin(client, origin);

			TE_SetupTFParticleEffect("achieved", origin, NULL_VECTOR, NULL_VECTOR, client, PATTACH_POINT_FOLLOW, 1, false);
			TE_SendToAll();

			EmitGameSoundToAll("Achievement.Earned", client, SND_NOFLAGS, -1, origin, NULL_VECTOR, true, 0.0);
			
			found = true;
		}

		if(found) {
			Call_StartForward(hOnPlayersWonEvent);
			Call_PushCell(winners);
			Call_PushCell(event);
			Call_Finish();
		}
		
		if(!found) {
			CPrintToChatAll(CHAT_PREFIX ... "%s terminou sem vencedores.", nome);
		} else {
			CPrintToChatAll(CHAT_PREFIX ... "%s terminado.", nome);
		}
	} else {
		CPrintToChatAll(CHAT_PREFIX ... "%s foi cancelado.", nome);
	}

	for(int i = 1; i <= MaxClients; i++) {
		Eventinho_Participate(i, false);
	}
	
	delete hCurrentEvent;
}

stock Action SetTransmit(int entity, int client)
{
	if(CheckCommandAccess(client, "eventinho_ver_participantes", ADMFLAG_GENERIC)) {
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}

stock int Native_Eventinho_Participate(Handle plugin, int params)
{
	bool is = GetNativeCell(2);
	int client = GetNativeCell(1);

	bParticipating[client] = is;

	if(!is) {
		SairTime(client, false, -1);
		DeletarTime(client, false, -1);
		
		if(PlayerSprite[client] != -1) {
			RemoveEntity(PlayerSprite[client]);
			PlayerSprite[client] = -1;
		}

		g_tmpConvidarPlayer[client] = -1;
	} else {
		PlayerSprite[client] = CreateEntityByName("env_sprite_oriented");
		DispatchKeyValue(PlayerSprite[client], "framerate", "10.0");
		DispatchKeyValue(PlayerSprite[client], "scale", "");
		DispatchKeyValue(PlayerSprite[client], "model", "materials/sprites/minimap_icons/voiceicon.vmt");
		//DispatchKeyValue(PlayerSprite[client], "model", "materials/sprites/obj_icons/icon_obj_e.vmt");
		DispatchKeyValue(PlayerSprite[client], "spawnflags", "1");
		DispatchKeyValueFloat(PlayerSprite[client], "GlowProxySize", 2.0);
		DispatchKeyValueFloat(PlayerSprite[client], "HDRColorScale", 1.0);
		DispatchSpawn(PlayerSprite[client]);
		ActivateEntity(PlayerSprite[client]);
		
		AcceptEntityInput(PlayerSprite[client], "ShowSprite");
		
		SetEntityRenderColor(PlayerSprite[client], 255, 0, 0, 255);
		
		//SetVariantString("!activator");
		//AcceptEntityInput(PlayerSprite[client], "SetParent", client);
		
		//SetVariantString("head");
		//AcceptEntityInput(PlayerSprite[client], "SetParentAttachment");
		
		SDKHook(PlayerSprite[client], SDKHook_SetTransmit, SetTransmit);
	}

	Call_StartForward(hOnPlayerParticipating);
	Call_PushCell(client);
	Call_PushCell(Eventinho_CurrentEvent());
	Call_PushCell(is);
	Call_Finish();

	return 1;
}

stock int Native_Eventinho_IsParticipating(Handle plugin, int params)
{
	int client = GetNativeCell(1);
	return bParticipating[client];
}

stock int Native_Eventinho_FindEvento(Handle plugin, int params)
{
	ArrayList eventos = new ArrayList();
	Eventinho_GetAllEvents(eventos);
	
	int len = 0;
	GetNativeStringLength(1, len);
	len++;
	
	char[] nome = new char[len];
	GetNativeString(1, nome, len);
	
	Evento evento = null;
	
	for(int i = 0; i < eventos.Length; i++) {
		Evento tmp = view_as<Evento>(eventos.Get(i));
		
		char tmp_nome[64];
		tmp.GetName(tmp_nome, sizeof(tmp_nome));
		
		if(StrEqual(tmp_nome, nome)) {
			evento = tmp;
			break;
		}
		
		delete tmp;
	}
	
	delete eventos;
	
	SetNativeCellRef(2, evento);
	if(!evento) {
		return 0;
	} else {
		return 1;
	}
}

stock int Native_Eventinho_ReDisplayOptionsMenu(Handle plugin, int params)
{
	int client = GetNativeCell(1);
	
	int len = 0;
	GetNativeStringLength(2, len);
	len++;
	
	char[] name = new char[len];
	GetNativeString(2, name, len);
	
	StringMap options = GetNativeCell(3);
	
	DisplayEventOptionsMenu(client, name, options);
	return 1;
}
