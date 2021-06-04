stock void Register_EventRewardAttribute_Natives()
{
	CreateNative("EventRewardAttribute.GetID", Native_EventRewardAttribute_GetID);
	CreateNative("EventRewardAttribute.GetValue", Native_EventRewardAttribute_GetValue);
}

stock int Native_EventRewardAttribute_GetID(Handle plugin, int params)
{
	EventRewardAttribute attribute = GetNativeCell(1);

#if defined __USING_API
	JSONObject attribute_json = view_as<JSONObject>(attribute);

	return attribute_json.GetInt("id");
#elseif defined __USE_KEYVALUES
	DataPack attribute_pack = view_as<DataPack>(attribute);
	int id = attribute_pack.ReadCell();
	attribute_pack.Reset();

	return id;
#endif
}

stock int Native_EventRewardAttribute_GetValue(Handle plugin, int params)
{
	EventRewardAttribute attribute = GetNativeCell(1);

#if defined __USING_API
	JSONObject attribute_json = view_as<JSONObject>(attribute);

	int value_int = attribute_json.GetInt("value");
	float value_float = float(value_int);
	return view_as<int>(value_float);
#elseif defined __USE_KEYVALUES
	DataPack attribute_pack = view_as<DataPack>(attribute);
	attribute_pack.ReadCell();
	float val = attribute_pack.ReadFloat();
	attribute_pack.Reset();

	return view_as<int>(val);
#endif
}