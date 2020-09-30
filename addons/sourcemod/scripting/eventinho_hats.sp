#include <tf2items>
#include <sdktools>
#include <sdkhooks>
#include <eventinho>
#include <tf2_stocks>
#include <morecolors>
#include <clientprefs>

#define EF_BONEMERGE 0x001
#define EF_BONEMERGE_FASTCULL 0x080
#define EF_PARENT_ANIMATES 0x200

#define CHAT_PREFIX "{dodgerblue}[Evento]{default} "

Handle hDummyItemView = null;
Handle hEquipWearable = null;

#define DISABLE_REWARDS view_as<ArrayList>(-1)
#define RANDOM_REWARDS view_as<ArrayList>(-2)

ArrayList hPlayerItems[MAXPLAYERS+1] = {null, ...};
ArrayList hPlayerRewards[MAXPLAYERS+1] = {null, ...};
StringMap hEventRewards = null;
Handle hCoroaCookie = null;

Database hDB = null;

public Plugin myinfo =
{
	name = "eventinho_hats",
	author = "Arthurdead",
	description = "",
	version = "",
	url = ""
};

bool g_bLateLoaded = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int length)
{
	g_bLateLoaded = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameData hGameConf = new GameData("classmodel");
	if(hGameConf == null) {
		SetFailState("Gamedata not found.");
		return;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CBasePlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	hEquipWearable = EndPrepSDKCall();
	if(hEquipWearable == null) {
		SetFailState("Failed to create SDKCall for CBasePlayer::EquipWearable.");
		delete hGameConf;
		return;
	}
	
	delete hGameConf;
	
	hDummyItemView = TF2Items_CreateItem(OVERRIDE_ALL|PRESERVE_ATTRIBUTES|FORCE_GENERATION);
	TF2Items_SetClassname(hDummyItemView, "tf_wearable");
	TF2Items_SetQuality(hDummyItemView, 0);
	TF2Items_SetLevel(hDummyItemView, 0);

	HookEvent("post_inventory_application", Event_Inventory);
	HookEvent("player_death", Event_PlayerDeath);

	hEventRewards = new StringMap();

	RegConsoleCmd("sm_coroa", ConCommand_Coroa);
	RegAdminCmd("sm_coroas", ConCommand_Coroas, ADMFLAG_ROOT);

	hCoroaCookie = RegClientCookie("coroa_preferida_v3", "Coroa preferida.", CookieAccess_Private);

	if(SQL_CheckConfig("eventinho_hats")) {
		Database.Connect(OnConnect, "eventinho_hats");
	}

	for(int i = 1; i <= MaxClients; i++) {
		if(AreClientCookiesCached(i)) {
			OnClientCookiesCached(i);
		}
	}
}

public void OnClientCookiesCached(int client)
{
	char value[64];
	GetClientCookie(client, hCoroaCookie, value, sizeof(value));
	
	if(value[0] == '\0'){
		return;
	}

	if(StrEqual(value, "aleatoria")) {
		hPlayerRewards[client] = RANDOM_REWARDS;
	} else if(StrEqual(value, "remover")) {
		hPlayerRewards[client] = DISABLE_REWARDS;
	} else {
		Evento event = null;
		Eventinho_FindEvento(value, event);

		ArrayList rewards = CacheRewards(event, value);
		
		delete event;
		
		hPlayerRewards[client] = rewards;
	}
}

public void OnClientPutInServer(int client)
{
	
}

public void OnPluginEnd()
{
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) &&
			!IsFakeClient(i)) {
			OnClientDisconnect(i);
		}
	}
}

public void OnClientDisconnect(int client)
{
	DeleteItems(client);
	delete hPlayerItems[client];
	hPlayerRewards[client] = null;
}

stock void DeleteItems(int player)
{
	if(hPlayerItems[player] == null) {
		return;
	}

	int len = hPlayerItems[player].Length;
	for(int i = 0; i < len; i++) {
		int entity = hPlayerItems[player].Get(i);
		if(IsValidEntity(entity)) {
			RemoveEntity(entity);
		}
	}
	delete hPlayerItems[player];
}

stock void GetRewards(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	if(!IsClientInGame(data) || IsFakeClient(data)) {
		return;
	}
	
	if(numQueries > 0) {
		DBResultSet set = results[0];

		if(!set.HasResults ||
			!set.FetchRow() ||
			set.FieldCount == 0) {
			return;
		}

		char nome[64];
		set.FetchString(0, nome, sizeof(nome));

		Evento event = null;
		Eventinho_FindEvento(nome, event);

		ArrayList rewards = CacheRewards(event, nome);
		
		delete event;
		
		hPlayerRewards[data] = rewards;

		GiveItems(data);
	}
}

stock int MenuHandler_Coroa(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		char nome[32];
		menu.GetItem(param2, nome, sizeof(nome));

		SetClientCookie(param1, hCoroaCookie, nome);

		DeleteItems(param1);

		if(StrEqual(nome, "remover")) {
			hPlayerRewards[param1] = DISABLE_REWARDS;
		} else {
			if(StrEqual(nome, "aleatoria")) {
				hPlayerRewards[param1] = RANDOM_REWARDS;
			} else {
				Evento event = null;
				Eventinho_FindEvento(nome, event);

				ArrayList rewards = CacheRewards(event, nome);
				
				delete event;
				
				hPlayerRewards[param1] = rewards;
			}

			GiveItems(param1);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}
	
	return 0;
}

stock void GetRewardsMenu(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	int client = data;

	Handle style = GetMenuStyleHandle(MenuStyle_Default);
	
	Menu menu = CreateMenuEx(style, MenuHandler_Coroa, MENU_ACTIONS_DEFAULT);
	menu.SetTitle("Coroa");

	if(numQueries > 0) {
		DBResultSet set = results[0];
		if(set.HasResults) {
			while(set.MoreRows) {
				if(!set.FetchRow() ||
					set.FieldCount == 0) {
					break;
				}

				char nome[64];
				set.FetchString(0, nome, sizeof(nome));

				menu.AddItem(nome, nome, ITEMDRAW_DEFAULT);
			}
		}
	}

	menu.AddItem("aleatoria", "aleatoria", ITEMDRAW_DEFAULT);
	menu.AddItem("remover", "remover", ITEMDRAW_DEFAULT);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

stock Action ConCommand_Coroas(int client, int args)
{
	if(client != 0) {
		CPrintToChat(client, CHAT_PREFIX ... "Olhe no console");
	}
	
	PrintToConsole(client, "===============================");
	
	if(hDB != null) {
		PrintToConsole(client, "Lista de vencedores:");
		
		Transaction hTR = new Transaction();

		char query[255];
		hDB.Format(query, sizeof(query), "select evento, steamid from vencedores;");
		hTR.AddQuery(query);

		hDB.Execute(hTR, PrintCoroas, OnError, client);
	} else {
		PrintToConsole(client, "Database nao esta conectada.");
		PrintToConsole(client, "===============================");
	}
	
	return Plugin_Handled;
}

stock void PrintCoroas(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	if(numQueries > 0) {
		DBResultSet set = results[0];
		if(set.HasResults) {
			while(set.MoreRows) {
				if(!set.FetchRow() ||
					set.FieldCount == 0) {
					break;
				}

				char nome[64];
				set.FetchString(0, nome, sizeof(nome));

				int steamid = set.FetchInt(1);

				PrintToConsole(data, "%i - %s", steamid, nome);
			}
		}
	}
	
	PrintToConsole(data, "===============================");
}

stock Action ConCommand_Coroa(int client, int args)
{
	if(hDB != null) {
		Transaction hTR = new Transaction();

		int steamid = GetSteamAccountID(client);

		char query[255];
		hDB.Format(query, sizeof(query), "select evento from vencedores where steamid=%i;", steamid);
		hTR.AddQuery(query);

		hDB.Execute(hTR, GetRewardsMenu, OnError, client);
	}

	return Plugin_Handled;
}

stock void GiveItems(int player)
{
	if(hPlayerRewards[player] == null) {
		if(hDB != null) {
			Transaction hTR = new Transaction();

			int steamid = GetSteamAccountID(player);

			char query[255];
			hDB.Format(query, sizeof(query), "select evento from vencedores where steamid=%i;", steamid);
			hTR.AddQuery(query);

			hDB.Execute(hTR, GetRewards, OnError, player);
		}
		return;
	} else if(hPlayerRewards[player] == DISABLE_REWARDS) {
		return;
	} else if(hPlayerRewards[player] == RANDOM_REWARDS) {
		return;
	}

	DeleteItems(player);

	if(hPlayerItems[player] == null) {
		hPlayerItems[player] = new ArrayList();
	}

	int len = hPlayerRewards[player].Length;
	for(int i = 0; i < len; i++) {
		EventReward reward = hPlayerRewards[player].Get(i);
		
		TF2Items_SetItemIndex(hDummyItemView, reward.GetItemID());

		ArrayList attributes = new ArrayList();
		reward.GetAttributes(attributes);
		
		//delete reward;

		int len2 = attributes.Length;
		TF2Items_SetNumAttributes(hDummyItemView, len2);
		for(int j = 0; j < len2; j++) {
			EventRewardAttribute attribute = attributes.Get(j);

			int index = attribute.GetID();
			float value = attribute.GetValue();
			
			delete attribute;

			TF2Items_SetAttribute(hDummyItemView, j, index, value);
		}
		
		delete attributes;

		int entity = TF2Items_GiveNamedItem(player, hDummyItemView);
		DispatchSpawn(entity);
		ActivateEntity(entity);
		
		SDKCall(hEquipWearable, player, entity);

		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", player);
		
		SetVariantString("head");
		AcceptEntityInput(entity, "SetParentAttachment");
		
		float offset[3];
		offset[2] += 0.0;
		SetEntPropVector(entity, Prop_Data, "m_vecOrigin", offset);
		
		int effects = GetEntProp(entity, Prop_Send, "m_fEffects");
		effects |= EF_PARENT_ANIMATES;
		effects &= ~(EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
		SetEntProp(entity, Prop_Send, "m_fEffects", effects);
		
		SetEntProp(entity, Prop_Send, "m_bInitialized", 1);
		SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", 1);
		
		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", player);
		int accid = GetSteamAccountID(player);
		SetEntProp(entity, Prop_Send, "m_iAccountID", accid);

		/*char model[64];
		reward.GetModel(model, sizeof(model));
		
		if(!StrEqual(model, "")) {
			SetEntityModel(entity, model);
		}*/

		hPlayerItems[player].Push(entity);
	}
}

stock void Event_Inventory(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("userid"));
	
	GiveItems(player);
}

stock void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("userid"));
	int flags = event.GetInt("death_flags");
	
	if(!(flags & TF_DEATHFLAG_DEADRINGER)) {
		DeleteItems(player);
	}
}

stock int PlayerBySteamID(int accid)
{
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) &&
			!IsFakeClient(i) &&
			GetSteamAccountID(i) == accid) {
			return i;
		}
	}
	return -1;
}

public void OnEntityDestroyed(int entity)
{
	if(entity <= -1) {
		return;
	}
	
	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	if(StrEqual(classname, "tf_wearable")) {
		int accid = GetEntProp(entity, Prop_Send, "m_iAccountID");
		int owner = PlayerBySteamID(accid);

		if(owner == -1 ||
			hPlayerItems[owner] == null) {
			return;
		}
		
		int len = hPlayerItems[owner].Length;
		for(int i = 0; i < len; i++) {
			int item = hPlayerItems[owner].Get(i);
			if(entity == item) {
				hPlayerItems[owner].Erase(i);
				return;
			}
		}
	}
}

stock ArrayList CacheRewards(Evento event, const char[] nome)
{
	if(hEventRewards == null) {
		hEventRewards = new StringMap();
	}

	ArrayList rewards = null;
	if(!hEventRewards.GetValue(nome, rewards) || rewards == null) {
		rewards = new ArrayList();
		event.GetRewards(rewards);
		hEventRewards.SetValue(nome, rewards);
	}

	return rewards;
}

stock void OnConnect(Database db, const char[] error, any data)
{
	if(db != null) {
		hDB = db;
		
		//if(!g_bLateLoaded)
		{
			hDB.SetCharset("utf8");

			Transaction hTR = new Transaction();

			/*
			static const char table_hats[] = {
				"create table if not exists hats ("
				"	evento varchar(255) not null," ...
				"	itemid int not null," ...
				"	model varchar(255) not null," ...
				"	unusual int not null," ...
				"	primary key (evento,itemid,model,unusual)" ...
				");"
			};
			hTR.AddQuery(table_hats);
			*/

			static const char table_winners[] = {
				"create table if not exists vencedores (" ...
				"	steamid int not null," ...
				"	evento varchar(255) not null," ...
				"	numero int not null," ...
				"	primary key (steamid,evento)" ...
				");"
			};
			hTR.AddQuery(table_winners);

			hDB.Execute(hTR, INVALID_FUNCTION, OnError);
		}

		for(int i = 1; i <= MaxClients; i++) {
			if(IsClientInGame(i) &&
				!IsFakeClient(i) &&
				IsPlayerAlive(i) &&
				GetClientTeam(i) > 1) {
				GiveItems(i);
			}
		}
	}
}

public void Eventinho_OnPlayersWonEvent(ArrayList players, Evento event)
{
	char nome[64];
	event.GetName(nome, sizeof(nome));

	if(hDB != null) {
		Transaction hTR = new Transaction();

		char query[255];
		hDB.Format(query, sizeof(query), "select steamid from vencedores where evento='%s';", nome);
		hTR.AddQuery(query);

		hDB.Execute(hTR, OnGetLastWinners, OnError);

		hTR = new Transaction();

		hDB.Format(query, sizeof(query), "delete from vencedores where evento='%s';", nome);
		hTR.AddQuery(query);

		hDB.Execute(hTR, INVALID_FUNCTION, OnError);
	}

	int len = players.Length;
	for(int i = 0; i < len; i++) {
		int client = players.Get(i);
		
		if(hDB != null) {
			int num = 1;
			int steamid = GetSteamAccountID(client);

			Transaction hTR = new Transaction();

			/*hDB.Format(query, sizeof(query), "select numero from vencedores where steamid=%i and evento='%s';", steamid, nome);
			hTR.AddQuery(query);*/

			char query[255];
			hDB.Format(query, sizeof(query), "insert into vencedores values(%i, '%s', %i);", steamid, nome, num);
			hTR.AddQuery(query);

			hDB.Execute(hTR, INVALID_FUNCTION, OnError);
		}

		if(hPlayerRewards[client] == null) {
			ArrayList rewards = CacheRewards(event, nome);
			hPlayerRewards[client] = rewards;

			SetClientCookie(client, hCoroaCookie, "");
		} else if(hPlayerRewards[client] == DISABLE_REWARDS) {
			continue;
		} else if(hPlayerRewards[client] == RANDOM_REWARDS) {
			continue;
		}

		GiveItems(client);
	}
}

stock void OnGetLastWinners(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	if(numQueries > 0) {
		DBResultSet set = results[0];
		if(set.HasResults) {
			while(set.MoreRows) {
				if(!set.FetchRow() ||
					set.FieldCount == 0) {
					break;
				}

				int steamid = set.FetchInt(0);
				int owner = PlayerBySteamID(steamid);
				if(owner != -1) {
					OnClientDisconnect(owner);
					SetClientCookie(owner, hCoroaCookie, "");
				}
			}
		}
	}
}

stock void OnError(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Deu erro: %s", error);
}