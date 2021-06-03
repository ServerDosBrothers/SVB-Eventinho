stock void Register_EventReward_Natives()
{
	CreateNative("EventReward.GetItemID", Native_EventReward_GetItemID);
	CreateNative("EventReward.GetModel", Native_EventReward_GetModel);
	CreateNative("EventReward.GetAttributes", Native_EventReward_GetAttributes);
}

stock int Native_EventReward_GetModel(Handle plugin, int params)
{
	EventReward reward = GetNativeCell(1);

	int len = GetNativeCell(3);
	char[] nome = new char[len];

#if defined __USING_API
	JSONObject reward_json = view_as<JSONObject>(reward);
	
	reward_json.GetString("model", nome, len);
#elseif defined __USE_KEYVALUES
	DataPack reward_pack = view_as<DataPack>(reward);
	int id = reward_pack.ReadCell();
	int id2 = reward_pack.ReadCell();
	int id3 = reward_pack.ReadCell();
	reward_pack.Reset();

	if(kvEventos.JumpToKeySymbol(id)) {
		if(kvEventos.JumpToKeySymbol(id2)) {
			if(kvEventos.JumpToKeySymbol(id3)) {
				kvEventos.GetString("model", nome, len);

				kvEventos.GoBack();
			}
			kvEventos.GoBack();
		}
		kvEventos.GoBack();
	}
#endif
	
	SetNativeString(2, nome, len);
	return 1;
}

stock int Native_EventReward_GetItemID(Handle plugin, int params)
{
	EventReward reward = GetNativeCell(1);

#if defined __USING_API
	JSONObject reward_json = view_as<JSONObject>(reward);

	return reward_json.GetInt("itemid");
#elseif defined __USE_KEYVALUES
	DataPack reward_pack = view_as<DataPack>(reward);
	int id = reward_pack.ReadCell();
	int id2 = reward_pack.ReadCell();
	int id3 = reward_pack.ReadCell();
	reward_pack.Reset();

	int item = -1;

	if(kvEventos.JumpToKeySymbol(id)) {
		if(kvEventos.JumpToKeySymbol(id2)) {
			if(kvEventos.JumpToKeySymbol(id3)) {
				char nome[64];
				kvEventos.GetSectionName(nome, sizeof(nome));

				item = StringToInt(nome);

				kvEventos.GoBack();
			}
			kvEventos.GoBack();
		}
		kvEventos.GoBack();
	}

	return item;
#endif
}

stock int Native_EventReward_GetAttributes(Handle plugin, int params)
{
	EventReward reward = GetNativeCell(1);
	ArrayList list = GetNativeCell(2);

#if defined __USING_API
	JSONObject reward_json = view_as<JSONObject>(reward);
	JSONArray attributes_json = view_as<JSONArray>(reward_json.Get("attributes"));

	JSONArray json = attributes_json;
	for(int i = 0; i < json.Length; i++) {
		JSONObject attribute = view_as<JSONObject>(json.Get(i));

		list.Push(attribute);
	}
	delete json;
#elseif defined __USE_KEYVALUES
	DataPack reward_pack = view_as<DataPack>(reward);
	int id = reward_pack.ReadCell();
	int id2 = reward_pack.ReadCell();
	int id3 = reward_pack.ReadCell();
	reward_pack.Reset();

	if(kvEventos.JumpToKeySymbol(id)) {
		if(kvEventos.JumpToKeySymbol(id2)) {
			if(kvEventos.JumpToKeySymbol(id3)) {
				char tmpname[64];
				char tmpvalue[64];
				do {
					kvEventos.GetSectionName(tmpname, sizeof(tmpname));
					kvEventos.GetString(NULL_STRING, tmpvalue, sizeof(tmpvalue));

					int attrid = StringToInt(tmpname);
					float attrval = StringToFloat(tmpvalue);

					DataPack tmp = new DataPack();
					tmp.WriteCell(attrid);
					tmp.WriteFloat(attrval);
					tmp.Reset();

					list.Push(tmp);
				} while(kvEventos.GotoNextKey());

				kvEventos.GoBack();
			}
			kvEventos.GoBack();
		}
		kvEventos.GoBack();
	}
#endif

	return 1;
}