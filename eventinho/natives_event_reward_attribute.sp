stock void Register_EventRewardAttribute_Natives()
{
    CreateNative("EventRewardAttribute.GetID", Native_EventRewardAttribute_GetID);
    CreateNative("EventRewardAttribute.GetValue", Native_EventRewardAttribute_GetValue);
}

stock int Native_EventRewardAttribute_GetID(Handle plugin, int params)
{
    EventRewardAttribute attribute = GetNativeCell(1);
    JSONObject attribute_json = view_as<JSONObject>(attribute);

    return attribute_json.GetInt("id");
}

stock int Native_EventRewardAttribute_GetValue(Handle plugin, int params)
{
    EventRewardAttribute attribute = GetNativeCell(1);
    JSONObject attribute_json = view_as<JSONObject>(attribute);

    return view_as<int>(attribute_json.GetFloat("value"));
}