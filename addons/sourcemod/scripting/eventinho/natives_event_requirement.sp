stock void Register_EventRequirement_Natives()
{
	CreateNative("EventRequirement.GetType", Native_EventRequirement_GetType);
	CreateNative("EventRequirement.GetValues", Native_EventRequirement_GetValues);
}

stock int Native_EventRequirement_GetType(Handle plugin, int params)
{
	EventRequirement requirement = GetNativeCell(1);

	char nome[64];

#if defined __USING_API
	JSONObject requirement_json = view_as<JSONObject>(requirement);

	requirement_json.GetString("type", nome, sizeof(nome));
#elseif defined __USE_KEYVALUES
	DataPack req_pack = view_as<DataPack>(requirement);
	int id = req_pack.ReadCell();
	int id2 = req_pack.ReadCell();
	int id3 = req_pack.ReadCell();
	req_pack.Reset();

	if(kvEventos.JumpToKeySymbol(id)) {
		if(kvEventos.JumpToKeySymbol(id2)) {
			if(kvEventos.JumpToKeySymbol(id3)) {
				kvEventos.GetString("type", nome, sizeof(nome));

				kvEventos.GoBack();
			}
			kvEventos.GoBack();
		}
		kvEventos.GoBack();
	}
#endif

	if(StrEqual(nome, "blacklist_map")) {
		return view_as<int>(ReqBlacklistMaps);
	} else if(StrEqual(nome, "whitelist_map")) {
		return view_as<int>(ReqWhitelistMaps);
	} else if(StrEqual(nome, "player_class")) {
		return view_as<int>(ReqPlayerClass);
	} else if(StrEqual(nome, "player_team")) {
		return view_as<int>(ReqPlayerTeam);
	}

	return view_as<int>(ReqUnknown);
}

stock int Native_EventRequirement_GetValues(Handle plugin, int params)
{
	EventRequirement requirement = GetNativeCell(1);
	ArrayList list = GetNativeCell(2);

	char value[64];

#if defined __USING_API
	JSONObject requirement_json = view_as<JSONObject>(requirement);
	JSONArray values_json = view_as<JSONArray>(requirement_json.Get("values"));

	JSONArray json = values_json;
	for(int i = 0; i < json.Length; i++) {
		json.GetString(i, value, sizeof(value));

		list.PushString(value);
	}
	delete json;
#elseif defined __USE_KEYVALUES
	DataPack req_pack = view_as<DataPack>(requirement);
	int id = req_pack.ReadCell();
	int id2 = req_pack.ReadCell();
	int id3 = req_pack.ReadCell();
	req_pack.Reset();

	if(kvEventos.JumpToKeySymbol(id)) {
		if(kvEventos.JumpToKeySymbol(id2)) {
			if(kvEventos.JumpToKeySymbol(id3)) {
				if(kvEventos.JumpToKey("values")) {
					if(kvEventos.GotoFirstSubKey(false)) {
						do {
							kvEventos.GetString(NULL_STRING, value, sizeof(value));

							list.PushString(value);
						} while(kvEventos.GotoNextKey(false));

						kvEventos.GoBack();
					}

					kvEventos.GoBack();
				}

				kvEventos.GoBack();
			}
			kvEventos.GoBack();
		}
		kvEventos.GoBack();
	}
#endif

	return 1;
}