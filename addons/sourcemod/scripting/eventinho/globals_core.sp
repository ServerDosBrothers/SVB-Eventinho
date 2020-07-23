#define CHAT_PREFIX "{dodgerblue}[Evento]{default} "
#define CONS_PREFIX "[Evento] "

#define DEFAULT_START_COUNTDOWN 10.0
#define DEFAULT_WARN_COUNTDOWN countdown / 3

bool bParticipating[MAXPLAYERS+1] = {false,...};
Evento hCurrentEvent = null;
Handle hCountdownTimer = null;
Handle hWarmTimer = null;
StringMap hOptionsMap = null;
StringMap hTmpOptions = null;
float g_tmpStartCountdown = DEFAULT_START_COUNTDOWN;
int PlayerSprite[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE,...};
ArrayList g_Time[MAXPLAYERS+1] = {null, ...};
int g_TimeEntrado[MAXPLAYERS+1] = {-1, ...};
int g_TmpAdmin = -1;
int g_tmpConvidarPlayer[MAXPLAYERS+1] = {-1, ...};
ConVar API_URL = null;
ConVar API_KEY = null;

stock void Core_Init()
{
	API_URL = CreateConVar("sm_eventinho_api", "http://api.svdosbrothers.com/v1/eventinho");
	API_KEY = CreateConVar("sm_eventinho_key", "teste");

	hOptionsMap = new StringMap();
	hOptionsMap.SetString("tf_weapon_criticals", "Crits");

	hTmpOptions = new StringMap();

	HookEvent("player_death", Event_PlayerDeath);

	AddMultiTargetFilter("@evento", FilterEvento, "Todos participando do evento.", false);
	AddMultiTargetFilter("@!evento", FilterEvento, "Todos não paticipando do evento.", false);

	static const char teams[][3] = {
		"red",
		"blu"
	};

	for(int i = 0; i < sizeof(teams); i++) {
		int len = 3+8;
		char[] name = new char[len];
		Format(name, len, "@%sevento", teams[i]);
		AddMultiTargetFilter(name, FilterEvento, "Todos participando do evento.", false);
		Format(name, len, "@!%sevento", teams[i]);
		AddMultiTargetFilter(name, FilterEvento, "Todos não paticipando do evento.", false);
	}

	/*static const char classes[][] = {
		"sco",
		"sol",
		"dem",
		"med",
		"spy",
		"eng",
	};*/
}

stock bool FilterEvento(const char[] filter, ArrayList clients)
{
	bool opposite = false;
	if(StrContains(filter, "!") != -1) {
		opposite = true;
	}
	
	TFTeam team = TFTeam_Spectator;
	if(StrContains(filter, "red") != -1) {
		team = TFTeam_Red;
	} else if(StrContains(filter, "blu") != -1) {
		team = TFTeam_Blue;
	}

	TFClassType class = TFClass_Unknown;

	for(int i = 1; i <= MaxClients; i++) {
		if(opposite && bParticipating[i]) {
			continue;
		} else if(!opposite && !bParticipating[i]) {
			continue;
		}

		if(team != TFTeam_Spectator) {
			if(TF2_GetClientTeam(i) != team) {
				continue;
			}
		}

		if(class != TFClass_Unknown) {
			if(TF2_GetPlayerClass(i) != class) {
				continue;
			}
		}

		clients.Push(i);
	}

	return true;
}

stock void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("userid"));
	int flags = event.GetInt("death_flags");

	if(!(flags & TF_DEATHFLAG_DEADRINGER)) {
		Evento evento = Eventinho_CurrentEvent();
		if(evento && evento.GetState() == EventInProgress) {
			char nome[64];
			evento.GetName(nome, sizeof(nome));

			if(StrEqual(name, "Color Wars") ||
				StrEqual(name, "Only One")) {
				return;
			}

			Eventinho_Participate(player, false);
		}
	}
}

public Action TeamManager_CanChangeTeam(int entity, int team, bool &result)
{
	if(Eventinho_IsParticipating(entity)) {
		Evento evento = Eventinho_CurrentEvent();

		char out[32];
		if(!TeamSupportsEventEx(evento, team, out, sizeof(out))) {
			char nome[64];
			evento.GetName(nome, sizeof(nome));

			CPrintToChat(entity, CHAT_PREFIX ... "Evento %s requer que você seja do time %s", nome, out);

			result = false;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

public Action TeamManager_CanChangeClass(int entity, int class, bool &result)
{
	if(Eventinho_IsParticipating(entity)) {
		Evento evento = Eventinho_CurrentEvent();

		char out[32];
		if(!ClassSupportsEventEx(evento, class, out, sizeof(out))) {
			char nome[64];
			evento.GetName(nome, sizeof(nome));

			CPrintToChat(entity, CHAT_PREFIX ... "Evento %s requer que você seja da classe %s", nome, out);

			result = false;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

stock bool MesmoTime(int player1, int player2)
{
	if(g_TimeEntrado[player1] != -1) {
		if(g_TimeEntrado[player1] == player2) {
			return true;
		}

		if(g_TimeEntrado[player2] != -1) {
			if(g_TimeEntrado[player1] == g_TimeEntrado[player2]) {
				return true;
			}
		}
	}

	return false;
}

stock bool IsPlayer(int entity)
{
	return (entity >= 1 && entity <= MaxClients);
}

public Action TeamManager_CanDamage(int entity, int other, bool &result)
{
	if(IsPlayer(entity) && IsPlayer(other))
	{
		if(MesmoTime(entity, other)) {
			result = false;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}