#include <tf2items>
#include <sdktools>
#include <sdkhooks>
#include <eventinho>
#include <tf2_stocks>

#define EF_BONEMERGE 0x001
#define EF_BONEMERGE_FASTCULL 0x080
#define EF_PARENT_ANIMATES 0x200

Handle hDummyItemView = null;
Handle hEquipWearable = null;

ArrayList hPlayerItems[MAXPLAYERS+1] = {null, ...};
ArrayList hPlayerRewards[MAXPLAYERS+1] = {null, ...};
ArrayList hEventRewards = null;

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

	hEventRewards = new ArrayList();

	if(SQL_CheckConfig("eventinho_hats")) {
		Database.Connect(OnConnect, "eventinho_hats");
	}
}

public void OnClientPutInServer(int client)
{
	
}

public void OnPluginEnd()
{
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			OnClientDisconnect(i);
		}
	}
}

public void OnClientDisconnect(int client)
{
	DeleteItems(client);
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

stock void GiveItems(int player)
{
	if(hPlayerRewards[player] == null) {
		return;
	}

	DeleteItems(player);

	hPlayerItems[player] = new ArrayList();

	int len = hPlayerRewards[player].Length;
	for(int i = 0; i < len; i++) {
		EventReward reward = hPlayerRewards[player].Get(i);
		
		TF2Items_SetItemIndex(hDummyItemView, reward.GetItemID());

		ArrayList attributes = new ArrayList();
		reward.GetAttributes(attributes);

		int len2 = attributes.Length;
		for(int j = 0; j < len2; j++) {
			EventRewardAttribute attribute = attributes.Get(j);

			int index = attribute.GetID();
			float value = attribute.GetValue();

			TF2Items_SetAttribute(hDummyItemView, j, index, value);
		}
		TF2Items_SetNumAttributes(hDummyItemView, len2);

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
		if(IsClientInGame(i)) {
			if(GetSteamAccountID(i) == accid) {
				return i;
			}
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

		if(owner == -1) {
			return;
		}

		if(hPlayerItems[owner] == null) {
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
		hEventRewards = new ArrayList();
	}

	int id = hEventRewards.FindString(nome);
	if(id == -1) {
		id = hEventRewards.PushString(nome);
		ArrayList rewards = new ArrayList();
		event.GetRewards(rewards);
		hEventRewards.Push(rewards);
		return rewards;
	} else {
		return hEventRewards.Get(id+1);
	}
}

stock void OnConnect(Database db, const char[] error, any data)
{
	if(db != null) {
		hDB = db;
		
		if(!g_bLateLoaded) {
			hDB.SetCharset("utf8");

			Transaction hTR = new Transaction();

			/*
			static const char table_hats[] = {
				"create table if not exists hats ("
				"	evento varchar(255) not null," ...
				"	itemid int not null," ...
				"	model varchar(255) not null," ...
				"	unusual int not null" ...
				"	primary key (evento,itemid,model,unusual)" ...
				");"
			};
			hTR.AddQuery(table_hats);
			*/

			static const char table_winners[] = {
				"create table if not exists vencedores (" ...
				"	steamid int not null," ...
				"	evento varchar(255) not null," ...
				"	numero int not null" ...
				"	primary key (steamid,evento)" ...
				");"
			};
			hTR.AddQuery(table_winners);

			hDB.Execute(hTR);
		}

		for(int i = 1; i <= MaxClients; i++) {
			if(IsClientInGame(i)) {
				OnClientPutInServer(i);
			}
		}
	}
}

public void Eventinho_OnPlayerWonEvent(int client, Evento event)
{
	char nome[64];
	event.GetName(nome, sizeof(nome));

	if(hPlayerRewards[client] == null) {
		ArrayList rewards = CacheRewards(event, nome);
		hPlayerRewards[client] = rewards;
	}

	GiveItems(client);

	if(hDB != null) {
		int num = 1;

		char auth[64];
		GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));

		int steamid = StringToInt(auth);

		Transaction hTR = new Transaction();

		char query[255];
		/*FormatEx(query, sizeof(query), "select numero from vencedores where steamid=%i and evento=%s", steamid, nome);
		hTR.AddQuery(query);*/

		FormatEx(query, sizeof(query), "delete from vencedores where evento=%s;", nome);
		hTR.AddQuery(query);

		FormatEx(query, sizeof(query), "insert into vencedores values(%i, %s, %i);", steamid, nome, num);
		hTR.AddQuery(query);

		hDB.Execute(hTR);
	}
}
