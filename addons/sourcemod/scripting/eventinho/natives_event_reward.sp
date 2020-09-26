stock void Register_EventReward_Natives()
{
	CreateNative("EventReward.GetItemID", Native_EventReward_GetItemID);
	CreateNative("EventReward.GetModel", Native_EventReward_GetModel);
	CreateNative("EventReward.GetAttributes", Native_EventReward_GetAttributes);
}

stock int Native_EventReward_GetModel(Handle plugin, int params)
{
	EventReward reward = GetNativeCell(1);
	JSONObject reward_json = view_as<JSONObject>(reward);
	
	int len = GetNativeCell(3);
	char[] nome = new char[len];
	
	reward_json.GetString("model", nome, len);
	
	SetNativeString(2, nome, len);
	return 1;
}

stock int Native_EventReward_GetItemID(Handle plugin, int params)
{
	EventReward reward = GetNativeCell(1);
	JSONObject reward_json = view_as<JSONObject>(reward);

	return reward_json.GetInt("itemid");
}

stock int Native_EventReward_GetAttributes(Handle plugin, int params)
{
	EventReward reward = GetNativeCell(1);
	JSONObject reward_json = view_as<JSONObject>(reward);
	JSONArray attributes_json = view_as<JSONArray>(reward_json.Get("attributes"));

	ArrayList list = GetNativeCell(2);

	JSONArray json = attributes_json;
	for(int i = 0; i < json.Length; i++) {
		JSONObject attribute = view_as<JSONObject>(json.Get(i));

		list.Push(attribute);
	}

	return 1;
}