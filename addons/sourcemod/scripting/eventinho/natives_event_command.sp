stock void Register_EventCommand_Natives()
{
	CreateNative("EventCommand.GetName", Native_EventCommand_GetName);
	CreateNative("EventCommand.GetValue", Native_EventCommand_GetValue);
}

stock int Native_EventCommand_GetName(Handle plugin, int params)
{
	EventCommand command = GetNativeCell(1);
	JSONObject command_json = view_as<JSONObject>(command);
	
	int len = GetNativeCell(3);
	char[] nome = new char[len];
	
	command_json.GetString("name", nome, len);
	
	SetNativeString(2, nome, len);
	return 1;
}

stock int Native_EventCommand_GetValue(Handle plugin, int params)
{
	EventCommand command = GetNativeCell(1);
	JSONObject command_json = view_as<JSONObject>(command);
	
	int len = GetNativeCell(3);
	char[] nome = new char[len];
	
	command_json.GetString("value", nome, len);
	
	SetNativeString(2, nome, len);
	return 1;
}