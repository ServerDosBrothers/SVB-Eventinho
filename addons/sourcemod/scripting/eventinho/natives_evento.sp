stock void Register_Evento_Natives()
{
	CreateNative("Evento.GetName", Native_Evento_GetName);
	CreateNative("Evento.GetDescription", Native_Evento_GetDescription);
	CreateNative("Evento.GetStartCommands", Native_Evento_GetStartCommands);
	CreateNative("Evento.GetEndCommands", Native_Evento_GetEndCommands);
	CreateNative("Evento.GetRequirements", Native_Evento_GetRequirements);
	CreateNative("Evento.GetRewards", Native_Evento_GetRewards);
	CreateNative("Evento.SetState", Native_Evento_SetState);
	CreateNative("Evento.GetState", Native_Evento_GetState);
	CreateNative("Evento.GetOptions", Native_Evento_GetOptions);
}

stock int Native_Evento_GetName(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);

	int len = GetNativeCell(3);
	char[] nome = new char[len];

#if defined __USING_API
	JSONObject evento_json = view_as<JSONObject>(evento);
	
	evento_json.GetString("nome", nome, len);
#elseif defined __USE_KEYVALUES
	DataPack evento_pack = view_as<DataPack>(evento);
	int id = evento_pack.ReadCell();
	evento_pack.Reset();

	if(kvEventos.JumpToKeySymbol(id)) {
		kvEventos.GetSectionName(nome, len);
		kvEventos.GoBack();
	}
#endif

	SetNativeString(2, nome, len);
	return 1;
}

stock int Native_Evento_GetDescription(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);

	int len = GetNativeCell(3);
	char[] nome = new char[len];

#if defined __USING_API
	JSONObject evento_json = view_as<JSONObject>(evento);
	
	evento_json.GetString("descricao", nome, len);
#elseif defined __USE_KEYVALUES
	DataPack evento_pack = view_as<DataPack>(evento);
	int id = evento_pack.ReadCell();
	evento_pack.Reset();

	if(kvEventos.JumpToKeySymbol(id)) {
		kvEventos.GetString("explain", nome, len);
		kvEventos.GoBack();
	} else if(kvEventos.JumpToKeySymbol(defaultid)) {
		kvEventos.GetString("explain", nome, len);
		kvEventos.GoBack();
	}

	ReplaceString(nome, len, "\\n", "\n");
	ReplaceString(nome, len, "\\t", "\t");
#endif
	
	SetNativeString(2, nome, len);
	return 1;
}

#if defined __USE_KEYVALUES
stock void HandleCommands(const char[] name, ArrayList list)
{
	if(kvEventos.JumpToKey(name)) {
		if(kvEventos.GotoFirstSubKey()) {
			char tmpname[64];
			char tmpvalue[64];
			do {
				kvEventos.GetSectionName(tmpname, sizeof(tmpname));
				kvEventos.GetString(NULL_STRING, tmpvalue, sizeof(tmpvalue));

				DataPack tmp = new DataPack();
				int len = strlen(tmpname)+1;
				tmp.WriteCell(len);
				tmp.WriteString(tmpname);
				len = strlen(tmpvalue)+1;
				tmp.WriteCell(len);
				tmp.WriteString(tmpvalue);
				tmp.Reset();

				list.Push(tmp);
			} while(kvEventos.GotoNextKey());

			kvEventos.GoBack();
		}

		kvEventos.GoBack();
	}
}
#endif

stock int Native_Evento_GetStartCommands(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);
	ArrayList list = GetNativeCell(2);

#if defined __USING_API
	JSONObject evento_json = view_as<JSONObject>(evento);
	JSONArray commands_json = view_as<JSONArray>(evento_json.Get("startCommands"));
	
	JSONArray json = commands_json;
	for(int i = 0; i < json.Length; i++) {
		JSONObject command = view_as<JSONObject>(json.Get(i));
		
		list.Push(command);
	}
	delete json;
#elseif defined __USE_KEYVALUES
	DataPack evento_pack = view_as<DataPack>(evento);
	int id = evento_pack.ReadCell();
	evento_pack.Reset();

	if(kvEventos.JumpToKeySymbol(id)) {
		HandleCommands("cmd_start", list);
		kvEventos.GoBack();
	}

	if(kvEventos.JumpToKeySymbol(defaultid)) {
		HandleCommands("cmd_start", list);
		kvEventos.GoBack();
	}
#endif
	
	return 1;
}

stock int Native_Evento_GetEndCommands(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);
	ArrayList list = GetNativeCell(2);

#if defined __USING_API
	JSONObject evento_json = view_as<JSONObject>(evento);
	JSONArray commands_json = view_as<JSONArray>(evento_json.Get("endCommands"));
	
	JSONArray json = commands_json;
	for(int i = 0; i < json.Length; i++) {
		JSONObject command = view_as<JSONObject>(json.Get(i));
		
		list.Push(command);
	}
	delete json;
#elseif defined __USE_KEYVALUES
	DataPack evento_pack = view_as<DataPack>(evento);
	int id = evento_pack.ReadCell();
	evento_pack.Reset();

	if(kvEventos.JumpToKeySymbol(id)) {
		HandleCommands("cmd_end", list);
		kvEventos.GoBack();
	}

	if(kvEventos.JumpToKeySymbol(defaultid)) {
		HandleCommands("cmd_end", list);
		kvEventos.GoBack();
	}
#endif
	
	return 1;
}

#if defined __USE_KEYVALUES
stock void HandleSubKeys(const char[] name, int id, ArrayList list)
{
	if(kvEventos.JumpToKey(name)) {
		int id2 = -1;
		if(kvEventos.GetSectionSymbol(id2)) {
			if(kvEventos.GotoFirstSubKey()) {
				do {
					int id3 = -1;
					if(kvEventos.GetSectionSymbol(id3)) {
						DataPack tmp = new DataPack();
						tmp.WriteCell(id);
						tmp.WriteCell(id2);
						tmp.WriteCell(id3);
						tmp.Reset();

						list.Push(tmp);
					}
				} while(kvEventos.GotoNextKey());

				kvEventos.GoBack();
			}

			kvEventos.GoBack();
		}
	}
}
#endif

stock int Native_Evento_GetRewards(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);
	ArrayList list = GetNativeCell(2);

#if defined __USING_API
	JSONObject evento_json = view_as<JSONObject>(evento);
	JSONArray rewards_json = view_as<JSONArray>(evento_json.Get("items"));
	
	JSONArray json = rewards_json;
	for(int i = 0; i < json.Length; i++) {
		JSONObject reward = view_as<JSONObject>(json.Get(i));
		
		list.Push(reward);
	}
	delete json;
#elseif defined __USE_KEYVALUES
	DataPack evento_pack = view_as<DataPack>(evento);
	int id = evento_pack.ReadCell();
	evento_pack.Reset();

	if(kvEventos.JumpToKeySymbol(id)) {
		HandleSubKeys("reward_items", id, list);
		kvEventos.GoBack();
	}

	if(kvEventos.JumpToKeySymbol(defaultid)) {
		HandleSubKeys("reward_items", defaultid, list);
		kvEventos.GoBack();
	}
#endif

	return 1;
}

stock int Native_Evento_GetRequirements(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);
	ArrayList list = GetNativeCell(2);

#if defined __USING_API
	JSONObject evento_json = view_as<JSONObject>(evento);
	JSONArray requirements_json = view_as<JSONArray>(evento_json.Get("requirements"));
	
	JSONArray json = requirements_json;
	for(int i = 0; i < json.Length; i++) {
		JSONObject requirement = view_as<JSONObject>(json.Get(i));
		
		list.Push(requirement);
	}
	delete json;
#elseif defined __USE_KEYVALUES
	DataPack evento_pack = view_as<DataPack>(evento);
	int id = evento_pack.ReadCell();
	evento_pack.Reset();

	if(kvEventos.JumpToKeySymbol(id)) {
		HandleSubKeys("requirements", id, list);
		kvEventos.GoBack();
	}

	if(kvEventos.JumpToKeySymbol(defaultid)) {
		HandleSubKeys("requirements", defaultid, list);
		kvEventos.GoBack();
	}
#endif
	
	return 1;
}

stock int Native_Evento_SetState(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);
	EventState state = view_as<EventState>(GetNativeCell(2));
	
#if defined __USING_API
	JSONObject evento_json = view_as<JSONObject>(evento);

	evento_json.SetInt("state", view_as<int>(state));
#elseif defined __USE_KEYVALUES
	kvEventos.SetNum("state", view_as<int>(state));
#endif
	
	Call_StartForward(hOnEventStateChanged);
	Call_PushCell(evento);
	Call_Finish();
	
	return 1;
}

stock int Native_Evento_GetState(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);

#if defined __USING_API
	JSONObject evento_json = view_as<JSONObject>(evento);
	
	EventState state = view_as<EventState>(evento_json.GetInt("state"));
#elseif defined __USE_KEYVALUES
	EventState state = view_as<EventState>(kvEventos.GetNum("state"));
#endif
	
	return view_as<int>(state);
}

stock int Native_Evento_GetOptions(Handle plugin, int params)
{
	return view_as<int>(hTmpOptions);
}

stock int Native_Eventinho_GetAllEvents(Handle plugin, int params)
{
	ArrayList list = GetNativeCell(1);

#if defined __USING_API
	if(jsonEventos == null) {
		return 0;
	}
	
	for(int i = 0; i < jsonEventos.Length; i++) {
		Evento tmp = view_as<Evento>(jsonEventos.Get(i));
		
		list.Push(tmp);
	}
#elseif defined __USE_KEYVALUES
	StringMapSnapshot snapshot = EventoMap.Snapshot();
	int len = snapshot.Length;
	char tmpname[64];
	for(int i = 0; i < len; ++i) {
		snapshot.GetKey(i, tmpname, sizeof(tmpname));
		int id = -1;
		if(EventoMap.GetValue(tmpname, id)) {
			DataPack tmp = new DataPack();
			tmp.WriteCell(id);
			tmp.Reset();
			list.Push(tmp);
		}
	}
	delete snapshot;
#endif
	
	return 1;
}