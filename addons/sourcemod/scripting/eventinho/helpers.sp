stock bool FindStrInArrayEx(ArrayList list, const char[] str, char[] out, int len)
{
	int length = list.Length;
	if(length > 0) {
		for(int i = 0; i < length; i++) {
			list.GetString(i, out, len);

			if(StrEqual(out, str)) {
				return true;
			}
		}
	}
	
	return false;
}

stock bool FindStrInArray(ArrayList list, const char[] str)
{
	char out[32];
	return FindStrInArrayEx(list, str, out, sizeof(out));
}

stock bool MapSupportsEvent(Evento event)
{
	bool supports = true;
	
	ArrayList requirements = new ArrayList();
	event.GetRequirements(requirements);
	int length = requirements.Length;
	if(length > 0) {
		char map[64];
		GetCurrentMap(map, sizeof(map));
		
		for(int i = 0; i < length; i++) {
			EventRequirement requirement = requirements.Get(i);
			EventRequirementType type = requirement.GetType();

			if(type == ReqBlacklistMaps || type == ReqWhitelistMaps) {
				ArrayList values = new ArrayList(64);
				requirement.GetValues(values);

				bool found = FindStrInArray(values, map);

				delete values;

				if(type == ReqBlacklistMaps) {
					if(found) {
						supports = false;
						break;
					}
				} else if(type == ReqWhitelistMaps) {
					if(!found) {
						supports = false;
						break;
					}
				}
			}
			
			delete requirement;
		}
	}
	
	delete requirements;
	
	return supports;
}

stock bool TeamSupportsEvent(Evento event, const char[] team, char[] out, int len)
{
	bool supports = true;
	
	ArrayList requirements = new ArrayList();
	event.GetRequirements(requirements);
	int length = requirements.Length;
	if(length > 0) {
		for(int i = 0; i < length; i++) {
			EventRequirement requirement = requirements.Get(i);
			EventRequirementType type = requirement.GetType();

			if(type == ReqPlayerTeam) {
				ArrayList values = new ArrayList(64);
				requirement.GetValues(values);

				bool found = FindStrInArrayEx(values, team, out, len);

				delete values;

				if(!found) {
					supports = false;
					break;
				}
			}
			
			delete requirement;
		}
	}
	
	delete requirements;
	
	return supports;
}

stock bool TeamSupportsEventEx(Evento event, int team, char[] out, int len)
{
	if(team == -1) {
		return false;
	}

	char name[32];
	GetTeamName(team, name, sizeof(name));

	if(TeamSupportsEvent(event, name, out, len)) {
		return true;
	}

	if(team == 2) {
		return TeamSupportsEvent(event, "red", out, len) ||
				TeamSupportsEvent(event, "2", out, len);
	} else if(team == 3) {
		return TeamSupportsEvent(event, "blu", out, len) ||
				TeamSupportsEvent(event, "blue", out, len) ||
				TeamSupportsEvent(event, "3", out, len);
	} else if(team == 1) {
		return TeamSupportsEvent(event, "spectate", out, len) ||
				TeamSupportsEvent(event, "spec", out, len) ||
				TeamSupportsEvent(event, "spectator", out, len) ||
				TeamSupportsEvent(event, "1", out, len);
	}

	return false;
}

stock bool ClassSupportsEvent(Evento event, const char[] class, char[] out, int len)
{
	bool supports = true;
	
	ArrayList requirements = new ArrayList();
	event.GetRequirements(requirements);
	int length = requirements.Length;
	if(length > 0) {
		for(int i = 0; i < length; i++) {
			EventRequirement requirement = requirements.Get(i);
			EventRequirementType type = requirement.GetType();

			if(type == ReqPlayerClass) {
				ArrayList values = new ArrayList(64);
				requirement.GetValues(values);

				bool found = FindStrInArrayEx(values, class, out, len);

				delete values;

				if(!found) {
					supports = false;
					break;
				}
			}
			
			delete requirement;
		}
	}
	
	delete requirements;
	
	return supports;
}

stock bool ClassToClassname(TFClassType type, char[] name, int length)
{
	switch(type)
	{
		case TFClass_Scout: { strcopy(name, length, "scout"); return true; }
		case TFClass_Soldier: { strcopy(name, length, "soldier"); return true; }
		case TFClass_Sniper: { strcopy(name, length, "sniper"); return true; }
		case TFClass_Spy: { strcopy(name, length, "spy"); return true; }
		case TFClass_Medic: { strcopy(name, length, "medic"); return true; }
		case TFClass_DemoMan: { strcopy(name, length, "demoman"); return true; }
		case TFClass_Pyro: { strcopy(name, length, "pyro"); return true; }
		case TFClass_Engineer: { strcopy(name, length, "engineer"); return true; }
		case TFClass_Heavy: { strcopy(name, length, "heavy"); return true; }
	}

	return false;
}

stock bool ClassSupportsEventEx(Evento event, int class, char[] out, int len)
{
	char str[32];
	if(!ClassToClassname(view_as<TFClassType>(class), str, sizeof(str))) {
		return false;
	}

	return ClassSupportsEvent(event, str, out, len);
}

stock void FindSubstr(const char[] source, const char[] check, char[] dest, int destlen)
{
	int index = StrContains(source, check);
	if(index == -1) {
		return;
	}
	
	int len = strlen(check);
	strcopy(dest, destlen, source[index+len]);
}

stock void FindSubstrReverse(const char[] source, const char[] check, char[] dest, int destlen)
{
	strcopy(dest, destlen, "");
	
	int len = strlen(source)-strlen(check);
	len++;
	
	strcopy(dest, len, source);
}

stock bool StrEmpty(const char[] str)
{
	if(strlen(str) == 0 || StrEqual(str, "")) {
		return true;
	}
	
	return false;
}

stock void AddMenuItemFormated(Menu menu, const char[] format, any ...)
{
	char buffer[64];
	VFormat(buffer, sizeof(buffer), format, 3);
	menu.AddItem(buffer, buffer, ITEMDRAW_DEFAULT);
}

stock void DrawTextFormated(Panel menu, const char[] format, any ...)
{
	char buffer[64];
	VFormat(buffer, sizeof(buffer), format, 3);
	menu.DrawText(buffer);
}

stock void AddMenuItemFormatedDisplay(Menu menu, const char[] display, const char[] format, any ...)
{
	char buffer[64];
	VFormat(buffer, sizeof(buffer), format, 4);
	menu.AddItem(buffer, display, ITEMDRAW_DEFAULT);
}

stock void SetMenuTitleFormated(Menu menu, const char[] format, any ...)
{
	char buffer[64];
	VFormat(buffer, sizeof(buffer), format, 3);
	menu.SetTitle(buffer);
}

stock void SetPanelTitleFormated(Panel menu, const char[] format, any ...)
{
	char buffer[64];
	VFormat(buffer, sizeof(buffer), format, 3);
	menu.SetTitle(buffer);
}

stock void MergeStringMaps(StringMap map1, StringMap map2)
{
	StringMapSnapshot snapshot = map1.Snapshot();
	
	for(int i = 0; i < snapshot.Length; i++) {
		char key[64];
		snapshot.GetKey(i, key, sizeof(key));
		
		char value[64];
		map1.GetString(key, value, sizeof(value));
		
		map2.SetString(key, value);
	}
	
	delete snapshot;
}

stock void CloseTimers()
{
	if(hCountdownTimer != null) {
		KillTimer(hCountdownTimer);
		hCountdownTimer = null;
	}

	if(hWarmTimer != null) {
		KillTimer(hWarmTimer);
		hWarmTimer = null;
	}
}
