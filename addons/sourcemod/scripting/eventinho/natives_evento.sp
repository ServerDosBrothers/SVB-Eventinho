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
	JSONObject evento_json = view_as<JSONObject>(evento);
	
	int len = GetNativeCell(3);
	char[] nome = new char[len];
	
	evento_json.GetString("nome", nome, len);
	
	SetNativeString(2, nome, len);
	return 1;
}

stock int Native_Evento_GetDescription(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);
	JSONObject evento_json = view_as<JSONObject>(evento);
	
	int len = GetNativeCell(3);
	char[] nome = new char[len];
	
	evento_json.GetString("descricao", nome, len);
	
	SetNativeString(2, nome, len);
	return 1;
}

stock int Native_Evento_GetStartCommands(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);
	JSONObject evento_json = view_as<JSONObject>(evento);
	JSONArray commands_json = view_as<JSONArray>(evento_json.Get("startCommands"));
	
	ArrayList list = GetNativeCell(2);
	
	JSONArray json = commands_json;
	for(int i = 0; i < json.Length; i++) {
		JSONObject command = view_as<JSONObject>(json.Get(i));
		
		list.Push(command);
	}
	delete json;
	
	return 1;
}

stock int Native_Evento_GetEndCommands(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);
	JSONObject evento_json = view_as<JSONObject>(evento);
	JSONArray commands_json = view_as<JSONArray>(evento_json.Get("endCommands"));
	
	ArrayList list = GetNativeCell(2);
	
	JSONArray json = commands_json;
	for(int i = 0; i < json.Length; i++) {
		JSONObject command = view_as<JSONObject>(json.Get(i));
		
		list.Push(command);
	}
	delete json;
	
	return 1;
}

stock int Native_Evento_GetRewards(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);
	JSONObject evento_json = view_as<JSONObject>(evento);
	JSONArray rewards_json = view_as<JSONArray>(evento_json.Get("items"));
	
	ArrayList list = GetNativeCell(2);
	
	JSONArray json = rewards_json;
	for(int i = 0; i < json.Length; i++) {
		JSONObject reward = view_as<JSONObject>(json.Get(i));
		
		list.Push(reward);
	}
	delete json;
	
	return 1;
}

stock int Native_Evento_GetRequirements(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);
	JSONObject evento_json = view_as<JSONObject>(evento);
	JSONArray requirements_json = view_as<JSONArray>(evento_json.Get("requirements"));
	
	ArrayList list = GetNativeCell(2);
	
	JSONArray json = requirements_json;
	for(int i = 0; i < json.Length; i++) {
		JSONObject requirement = view_as<JSONObject>(json.Get(i));
		
		list.Push(requirement);
	}
	delete json;
	
	return 1;
}

stock int Native_Evento_SetState(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);
	JSONObject evento_json = view_as<JSONObject>(evento);
	
	EventState state = view_as<EventState>(GetNativeCell(2));
	
	evento_json.SetInt("state", view_as<int>(state));
	
	Call_StartForward(hOnEventStateChanged);
	Call_PushCell(evento);
	Call_Finish();
	
	return 1;
}

stock int Native_Evento_GetState(Handle plugin, int params)
{
	Evento evento = GetNativeCell(1);
	JSONObject evento_json = view_as<JSONObject>(evento);
	
	EventState state = view_as<EventState>(evento_json.GetInt("state"));
	
	return view_as<int>(state);
}

stock int Native_Evento_GetOptions(Handle plugin, int params)
{
	return view_as<int>(hTmpOptions);
}

stock int Native_Eventinho_GetAllEvents(Handle plugin, int params)
{
	if(jsonEventos == null) {
		return 0;
	}
	
	ArrayList list = GetNativeCell(1);
	
	for(int i = 0; i < jsonEventos.Length; i++) {
		Evento tmp = view_as<Evento>(jsonEventos.Get(i));
		
		list.Push(tmp);
	}
	
	return 1;
}