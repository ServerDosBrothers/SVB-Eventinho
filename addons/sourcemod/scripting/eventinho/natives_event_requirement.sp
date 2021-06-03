stock void Register_EventRequirement_Natives()
{
	CreateNative("EventRequirement.GetType", Native_EventRequirement_GetType);
	CreateNative("EventRequirement.GetValues", Native_EventRequirement_GetValues);
}

stock int Native_EventRequirement_GetType(Handle plugin, int params)
{
	EventRequirement requirement = GetNativeCell(1);

#if defined __USING_API
	JSONObject requirement_json = view_as<JSONObject>(requirement);

	char nome[64];
	requirement_json.GetString("type", nome, sizeof(nome));

	if(StrEqual(nome, "blacklist_map")) {
		return view_as<int>(ReqBlacklistMaps);
	} else if(StrEqual(nome, "whitelist_map")) {
		return view_as<int>(ReqWhitelistMaps);
	} else if(StrEqual(nome, "player_class")) {
		return view_as<int>(ReqPlayerClass);
	} else if(StrEqual(nome, "player_team")) {
		return view_as<int>(ReqPlayerTeam);
	}
#elseif defined __USE_KEYVALUES
	
#endif

	return view_as<int>(ReqUnknown);
}

stock int Native_EventRequirement_GetValues(Handle plugin, int params)
{
	EventRequirement requirement = GetNativeCell(1);
	ArrayList list = GetNativeCell(2);

#if defined __USING_API
	JSONObject requirement_json = view_as<JSONObject>(requirement);
	JSONArray values_json = view_as<JSONArray>(requirement_json.Get("values"));

	JSONArray json = values_json;
	for(int i = 0; i < json.Length; i++) {
		char value[64];
		json.GetString(i, value, sizeof(value));

		list.PushString(value);
	}
	delete json;
#elseif defined __USE_KEYVALUES
	
#endif

	return 1;
}