stock void Register_EventCommand_Natives()
{
	CreateNative("EventCommand.GetName", Native_EventCommand_GetName);
	CreateNative("EventCommand.GetValue", Native_EventCommand_GetValue);
}

stock int Native_EventCommand_GetName(Handle plugin, int params)
{
	EventCommand command = GetNativeCell(1);

	int len = GetNativeCell(3);
	char[] nome = new char[len];

#if defined __USING_API
	JSONObject command_json = view_as<JSONObject>(command);
	
	command_json.GetString("name", nome, len);
#elseif defined __USE_KEYVALUES
	DataPack command_pack = view_as<DataPack>(command);
	command_pack.ReadCell();
	command_pack.ReadString(nome, len);
	command_pack.Reset();
#endif
	
	SetNativeString(2, nome, len);
	return 1;
}

stock int Native_EventCommand_GetValue(Handle plugin, int params)
{
	EventCommand command = GetNativeCell(1);

	int len = GetNativeCell(3);
	char[] nome = new char[len];

#if defined __USING_API
	JSONObject command_json = view_as<JSONObject>(command);
	
	command_json.GetString("value", nome, len);
#elseif defined __USE_KEYVALUES
	DataPack command_pack = view_as<DataPack>(command);
	command_pack.ReadCell();
	command_pack.ReadString(nome, len);
	command_pack.ReadCell();
	command_pack.ReadString(nome, len);
	command_pack.Reset();
#endif
	
	SetNativeString(2, nome, len);
	return 1;
}