#include <sourcemod>
#include <keyvalues>
#include <tf2>
#include <tf2_stocks>
#include <colorlib>
#include <teammanager>
#include <sdkhooks>

//#define DEBUG

/*
TODO!!!

adicionar os filtros
terminar de portar o eventos.txt pro eventos2.txt
adicionar visualizaçao do teleport
adicionar o icone
arrumar todos os textos
adicionar todo o codigo da coroa
*/

//game/shared/econ/econ_item_constants.h
#define MAX_ATTRIBUTES_PER_ITEM 15
//game/shared/tf/tf_shareddefs.h
#define TF_CLASS_COUNT_ALL 11

#define EVENTO_NAME_MAX 64
#define EVENTO_REWARD_NAME_MAX 64
#define EVENTO_EXPLAIN_MAX 256

#define CLASS_NAME_MAX 10
#define EVENTO_CLASSES_STR_MAX (CLASS_NAME_MAX * TF_CLASS_COUNT_ALL)

#define CMD_STR_MAX 256
#define INT_STR_MAX 256
#define TIME_STR_MAX 256

#define EVENTO_CHAT_PREFIX "{blue}[Evento]{default} "
#define EVENTO_CON_PREFIX "[Evento] "

#define COROA_ITEM_INDEX 342
#define UNUSUAL_ATTR_IDX 134

#define IDX_FOR_TEAM(%1) (view_as<int>(%1)-2)

#define BIT_FOR_CLASS(%1) (1 << (2 ^ view_as<int>(%1)))
#define BIT_FOR_TEAM(%1) (1 << (2 ^ (view_as<int>(%1)-1)))

#define PACK_2_INTS(%1,%2) ((%1 << 16) | %2)
#define PACKED_2_INTS_1(%1) (%1 >> 16)
#define PACKED_2_INTS_2(%1) (%1 & 32767)

#define AttributePair int

enum struct RewardInfo
{
	char name[EVENTO_REWARD_NAME_MAX]
	int id;
	AttributePair attributes[MAX_ATTRIBUTES_PER_ITEM];
	char model[PLATFORM_MAX_PATH];
}

enum struct EventoInfo
{
	char name[EVENTO_NAME_MAX];
	bool classes_is_whitelist;
	int classes;
	bool weapons_is_whitelist;
	ArrayList weapons;
	int team;
	int min_players;
	bool respawn;
	ArrayList explains;
	ArrayList cmds[2];
	ArrayList rewards;
}

enum EventoPrefabs
{
	PREFAB_COROA
}

enum EventoState
{
	EVENTO_STATE_ENDED,
	EVENTO_STATE_IN_COUNTDOWN_START,
	EVENTO_STATE_IN_COUNTDOWN_END,
	EVENTO_STATE_IN_PROGRESS
}

enum struct ChatListenInfo
{
	int client;
	bool start;
	int idx;
}

static RewardInfo tmprewardinfo;
static EventoInfo tmpeventoinfo;
static ArrayList evento_infos;
static char tmpintstr[INT_STR_MAX];
static char tmptimestr[TIME_STR_MAX];
static char tmpexplainstr[EVENTO_EXPLAIN_MAX];
static char tmpplayername[MAX_NAME_LENGTH];
static char tmpcmdstr[CMD_STR_MAX];

static Handle hud;
static int current_evento = -1;
static EventoState current_state = EVENTO_STATE_ENDED;
static int evento_secs;
static bool participando[33];
static bool vencedor[33];
static int usando_menu = -1;
static Handle countdown_handle;
static ChatListenInfo chat_listen;
static float teleport[2][3];
static int teleport_set;

static char tmpclassnames[TF_CLASS_COUNT_ALL][CLASS_NAME_MAX];
bool parse_classes_str(int &classes, const char[] str, const char[] eventoname)
{
	int num = ExplodeString(str, "|", tmpclassnames, TF_CLASS_COUNT_ALL, CLASS_NAME_MAX);
	for(int i = 0; i < num; ++i) {
		if(strcmp(tmpclassnames[i], "scout") == 0) {
			classes |= BIT_FOR_CLASS(TFClass_Scout);
		} else if(strcmp(tmpclassnames[i], "sniper") == 0) {
			classes |= BIT_FOR_CLASS(TFClass_Sniper);
		} else if(strcmp(tmpclassnames[i], "soldier") == 0) {
			classes |= BIT_FOR_CLASS(TFClass_Soldier);
		} else if(strcmp(tmpclassnames[i], "demoman") == 0) {
			classes |= BIT_FOR_CLASS(TFClass_DemoMan);
		} else if(strcmp(tmpclassnames[i], "medic") == 0) {
			classes |= BIT_FOR_CLASS(TFClass_Medic);
		} else if(strcmp(tmpclassnames[i], "heavy") == 0) {
			classes |= BIT_FOR_CLASS(TFClass_Heavy);
		} else if(strcmp(tmpclassnames[i], "pyro") == 0) {
			classes |= BIT_FOR_CLASS(TFClass_Pyro);
		} else if(strcmp(tmpclassnames[i], "spy") == 0) {
			classes |= BIT_FOR_CLASS(TFClass_Spy);
		} else if(strcmp(tmpclassnames[i], "engineer") == 0) {
			classes |= BIT_FOR_CLASS(TFClass_Engineer);
		} else {
			LogError(EVENTO_CON_PREFIX ... "evento %s tem classe desconhecida %s", eventoname, tmpclassnames[i]);
			return false;
		}
	}
	return true;
}

#if defined DEBUG
static char debugclassesvalue[EVENTO_CLASSES_STR_MAX];
void build_classes_str(int classes)
{
	debugclassesvalue[0] = '\0';

	int len = 0;
	if(classes & BIT_FOR_CLASS(TFClass_Scout)) {
		StrCat(debugclassesvalue, EVENTO_CLASSES_STR_MAX, "scout|");
		len += 5 + 1;
	}
	if(classes & BIT_FOR_CLASS(TFClass_Sniper)) {
		StrCat(debugclassesvalue, EVENTO_CLASSES_STR_MAX, "sniper|");
		len += 6 + 1;
	}
	if(classes & BIT_FOR_CLASS(TFClass_Soldier)) {
		StrCat(debugclassesvalue, EVENTO_CLASSES_STR_MAX, "soldier|");
		len += 7 + 1;
	}
	if(classes & BIT_FOR_CLASS(TFClass_DemoMan)) {
		StrCat(debugclassesvalue, EVENTO_CLASSES_STR_MAX, "demoman|");
		len += 7 + 1;
	}
	if(classes & BIT_FOR_CLASS(TFClass_Medic)) {
		StrCat(debugclassesvalue, EVENTO_CLASSES_STR_MAX, "medic|");
		len += 5 + 1;
	}
	if(classes & BIT_FOR_CLASS(TFClass_Heavy)) {
		StrCat(debugclassesvalue, EVENTO_CLASSES_STR_MAX, "heavy|");
		len += 5 + 1;
	}
	if(classes & BIT_FOR_CLASS(TFClass_Pyro)) {
		StrCat(debugclassesvalue, EVENTO_CLASSES_STR_MAX, "pyro|");
		len += 4 + 1;
	}
	if(classes & BIT_FOR_CLASS(TFClass_Spy)) {
		StrCat(debugclassesvalue, EVENTO_CLASSES_STR_MAX, "spy|");
		len += 3 + 1;
	}
	if(classes & BIT_FOR_CLASS(TFClass_Engineer)) {
		StrCat(debugclassesvalue, EVENTO_CLASSES_STR_MAX, "engineer|");
		len += 8 + 1;
	}

	debugclassesvalue[len-1] = '\0';
}
#endif

void handle_prefab(EventoPrefabs prefab, float value
#if defined DEBUG
, const char[] spaces
#endif
)
{
	switch(prefab) {
		case PREFAB_COROA: {
			int value_int = RoundToFloor(value);

			AttributePair attr = PACK_2_INTS(UNUSUAL_ATTR_IDX, value_int);

		#if defined DEBUG
			PrintToServer(EVENTO_CON_PREFIX ... "%sitem id = %i", spaces, COROA_ITEM_INDEX);
			PrintToServer(EVENTO_CON_PREFIX ... "%sattr id = %i", spaces, UNUSUAL_ATTR_IDX);
			PrintToServer(EVENTO_CON_PREFIX ... "%svalue = %f", spaces, value);
			PrintToServer(EVENTO_CON_PREFIX ... "%svalue_int = %i", spaces, value_int);
			PrintToServer(EVENTO_CON_PREFIX ... "%spair packed = %i", spaces, attr);
			PrintToServer(EVENTO_CON_PREFIX ... "%spair unpacked = %i, %i", spaces, PACKED_2_INTS_1(attr), PACKED_2_INTS_2(attr));
		#endif

			strcopy(tmprewardinfo.name, EVENTO_REWARD_NAME_MAX, "coroa");
			tmprewardinfo.id = COROA_ITEM_INDEX;
			tmprewardinfo.attributes[0] = attr;
			tmprewardinfo.attributes[1] = -1;
			tmprewardinfo.model[0] = '\0';

			tmpeventoinfo.rewards.PushArray(tmprewardinfo, sizeof(RewardInfo));
		}
	}
}

void handle_str_array(KeyValues kvEventos, const char[] name, ArrayList &arr, char[] str, int size)
{
	if(kvEventos.JumpToKey(name)) {
		if(kvEventos.GotoFirstSubKey(false)) {
		#if defined DEBUG
			PrintToServer(EVENTO_CON_PREFIX ... "  %s", name);
		#endif

			arr = new ArrayList(size);

			do {
				kvEventos.GetString(NULL_STRING, str, size);
			#if defined DEBUG
				PrintToServer(EVENTO_CON_PREFIX ... "    %s", str);
			#endif

				arr.PushString(str);
			} while(kvEventos.GotoNextKey(false));

			kvEventos.GoBack();
		} else {
			arr = null;
		}

		kvEventos.GoBack();
	} else {
		arr = null;
	}
}

void unload_eventos()
{
	int len = evento_infos.Length;
	for(int i = 0; i < len; ++i) {
		evento_infos.GetArray(i, tmpeventoinfo, sizeof(EventoInfo));

		delete tmpeventoinfo.explains;
		delete tmpeventoinfo.cmds[0];
		delete tmpeventoinfo.cmds[1];
		delete tmpeventoinfo.rewards;
	}

	delete evento_infos;
}

void load_eventos()
{
	char eventofilepath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, eventofilepath, PLATFORM_MAX_PATH, "data/eventos2.txt");

	if(FileExists(eventofilepath)) {
		KeyValues kvEventos = new KeyValues("Eventos");
		kvEventos.ImportFromFile(eventofilepath);

		if(kvEventos.GotoFirstSubKey()) {
			evento_infos = new ArrayList(sizeof(EventoInfo));

			char tmpclassesvalue[EVENTO_CLASSES_STR_MAX];

			do {
				kvEventos.GetSectionName(tmpeventoinfo.name, EVENTO_NAME_MAX);
			#if defined DEBUG
				PrintToServer(EVENTO_CON_PREFIX ... " %s", tmpeventoinfo.name);
			#endif

				tmpeventoinfo.respawn = view_as<bool>(kvEventos.GetNum("respawn"));
				tmpeventoinfo.team = kvEventos.GetNum("team");
				tmpeventoinfo.min_players = kvEventos.GetNum("min_players");

				bool valid = true;

				if(kvEventos.JumpToKey("classes_whitelist")) {
					if(kvEventos.JumpToKey("classes_blacklist")) {
						LogError(EVENTO_CON_PREFIX ... " evento %s tem classes_blacklist junto com classes_whitelist", tmpeventoinfo.name);
						valid = false;
						kvEventos.GoBack();
					} else {
						tmpeventoinfo.classes_is_whitelist = true;
						kvEventos.GetString(NULL_STRING, tmpclassesvalue, EVENTO_CLASSES_STR_MAX);
					}
					kvEventos.GoBack();
				} else if(kvEventos.JumpToKey("classes_blacklist")) {
					if(kvEventos.JumpToKey("classes_whitelist")) {
						LogError(EVENTO_CON_PREFIX ... " evento %s tem classes_whitelist junto com classes_blacklist", tmpeventoinfo.name);
						valid = false;
						kvEventos.GoBack();
					} else {
						tmpeventoinfo.classes_is_whitelist = false;
						kvEventos.GetString(NULL_STRING, tmpclassesvalue, EVENTO_CLASSES_STR_MAX);
					}
					kvEventos.GoBack();
				}

				if(!valid) {
					continue;
				}

				if(tmpclassesvalue[0] != '\0') {
					if(!parse_classes_str(tmpeventoinfo.classes, tmpclassesvalue, tmpeventoinfo.name)) {
						continue;
					}
				} else {
					tmpeventoinfo.classes = 0;
				}

			#if defined DEBUG
				PrintToServer(EVENTO_CON_PREFIX ... "  classes");
				if(tmpeventoinfo.classes_is_whitelist) {
					PrintToServer(EVENTO_CON_PREFIX ... "    type = whitelist");
				} else {
					PrintToServer(EVENTO_CON_PREFIX ... "    type = blacklist");
				}
				PrintToServer(EVENTO_CON_PREFIX ... "    raw value = %i", tmpeventoinfo.classes);
				PrintToServer(EVENTO_CON_PREFIX ... "    raw str value = %s", tmpclassesvalue);
				build_classes_str(tmpeventoinfo.classes);
				PrintToServer(EVENTO_CON_PREFIX ... "    counstructed str value = %s", debugclassesvalue);
			#endif

				tmpeventoinfo.rewards = new ArrayList(sizeof(RewardInfo));

				if(kvEventos.JumpToKey("coroa_unusual")) {
				#if defined DEBUG
					PrintToServer(EVENTO_CON_PREFIX ... "  coroa_unusual");
				#endif

					float value = kvEventos.GetFloat(NULL_STRING, 0.0);
					handle_prefab(PREFAB_COROA, value
				#if defined DEBUG
					,"    "
				#endif
					);

					kvEventos.GoBack();
				}

				if(kvEventos.JumpToKey("rewards_prefab")) {
					if(kvEventos.GotoFirstSubKey(false)) {
					#if defined DEBUG
						PrintToServer(EVENTO_CON_PREFIX ... "  rewards_prefab");
					#endif

						do {
							kvEventos.GetSectionName(tmprewardinfo.name, EVENTO_REWARD_NAME_MAX);
						#if defined DEBUG
							PrintToServer(EVENTO_CON_PREFIX ... "    %s", tmprewardinfo.name);
						#endif

							if(strcmp(tmprewardinfo.name, "coroa") == 0) {
								float value = kvEventos.GetFloat(NULL_STRING, 0.0);
								handle_prefab(PREFAB_COROA, value
							#if defined DEBUG
								,"      "
							#endif
								);
							} else {
								LogError(EVENTO_CON_PREFIX ... " evento %s tem reward_prefab desconhecido %s", tmpeventoinfo.name, tmprewardinfo.name);
								valid = false;
								break;
							}

						} while(kvEventos.GotoNextKey(false));

						kvEventos.GoBack();
					}

					kvEventos.GoBack();
				}

				if(!valid) {
					continue;
				}

				if(kvEventos.JumpToKey("rewards")) {
					if(kvEventos.GotoFirstSubKey()) {
					#if defined DEBUG
						PrintToServer(EVENTO_CON_PREFIX ... "  rewards");
					#endif

						do {
							kvEventos.GetSectionName(tmprewardinfo.name, EVENTO_REWARD_NAME_MAX);
						#if defined DEBUG
							PrintToServer(EVENTO_CON_PREFIX ... "    %s", tmprewardinfo.name);
						#endif

							tmprewardinfo.id = kvEventos.GetNum("id", -1);
							if(tmprewardinfo.id < 0) {
								LogError(EVENTO_CON_PREFIX ... " evento %s reward %s tem id negativo", tmpeventoinfo.name, tmprewardinfo.name);
								continue;
							}

							tmprewardinfo.model[0] = '\0';

						#if defined DEBUG
							PrintToServer(EVENTO_CON_PREFIX ... "      id = %i", tmprewardinfo.id);
						#endif

							if(kvEventos.JumpToKey("attributes")) {
								if(kvEventos.GotoFirstSubKey(false)) {
								#if defined DEBUG
									PrintToServer(EVENTO_CON_PREFIX ... "      attributes");
								#endif

									int attr_idx = 0;

									do {
										kvEventos.GetSectionName(tmpintstr, INT_STR_MAX);
									#if defined DEBUG
										PrintToServer(EVENTO_CON_PREFIX ... "        id str = %s", tmpintstr);
									#endif

										int id = StringToInt(tmpintstr);
										if(id < 0) {
											LogError(EVENTO_CON_PREFIX ... " evento %s reward %s tem attrbuto com id negativo", tmpeventoinfo.name, tmprewardinfo.name);
											valid = false;
											break;
										}

										float value = kvEventos.GetFloat(NULL_STRING, 0.0);
										int value_int = RoundToFloor(value);

										AttributePair attr = PACK_2_INTS(id, value_int);

									#if defined DEBUG
										PrintToServer(EVENTO_CON_PREFIX ... "          id = %i", id);
										PrintToServer(EVENTO_CON_PREFIX ... "          value = %f", value);
										PrintToServer(EVENTO_CON_PREFIX ... "          value int = %i", value_int);
										PrintToServer(EVENTO_CON_PREFIX ... "          pair packed = %i", attr);
										PrintToServer(EVENTO_CON_PREFIX ... "          pair unpacked = %i, %i", PACKED_2_INTS_1(attr), PACKED_2_INTS_2(attr));
									#endif

										tmprewardinfo.attributes[attr_idx++] = attr;
									} while(kvEventos.GotoNextKey(false));

									tmprewardinfo.attributes[attr_idx] = -1;

									kvEventos.GoBack();
								}

								kvEventos.GoBack();
							}

							if(!valid) {
								break;
							}

							tmpeventoinfo.rewards.PushArray(tmprewardinfo, sizeof(RewardInfo));
						} while(kvEventos.GotoNextKey());

						kvEventos.GoBack();
					}

					kvEventos.GoBack();
				}

				if(!valid) {
					continue;
				}

				if(tmpeventoinfo.rewards.Length == 0) {
					delete tmpeventoinfo.rewards;
				}

				handle_str_array(kvEventos, "explains", tmpeventoinfo.explains, tmpexplainstr, EVENTO_EXPLAIN_MAX);

				handle_str_array(kvEventos, "cmd_start", tmpeventoinfo.cmds[0], tmpcmdstr, CMD_STR_MAX);
				handle_str_array(kvEventos, "cmd_end", tmpeventoinfo.cmds[1], tmpcmdstr, CMD_STR_MAX);

				evento_infos.PushArray(tmpeventoinfo, sizeof(EventoInfo));
			} while(kvEventos.GotoNextKey());

			kvEventos.GoBack();
		}

		delete kvEventos;
	}
}

public void OnPluginStart()
{
	load_eventos();

	RegConsoleCmd("sm_explain", sm_explain);
	RegConsoleCmd("sm_evento", sm_evento);

	RegAdminCmd("sm_leventos", sm_leventos, ADMFLAG_ROOT);
	RegAdminCmd("sm_reventos", sm_reventos, ADMFLAG_ROOT);

	RegAdminCmd("sm_mevento", sm_mevento, ADMFLAG_ROOT);

	HookEvent("player_say", player_say);

	HookEvent("player_spawn", player_spawn);
	HookEvent("player_death", player_death);

	for(int i = 1; i <= MaxClients; ++i) {
		if(IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

void player_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(current_evento != -1) {
		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			if(participando[client]) {
				evento_infos.GetArray(current_evento, tmpeventoinfo, sizeof(EventoInfo));

				if(tmpeventoinfo.respawn) {
					int team = GetClientTeam(client);
					if(teleport_set & BIT_FOR_TEAM(team)) {
						TeleportEntity(client, teleport[IDX_FOR_TEAM(team)]);
					}
				}
			}
		}
	}
}

void player_death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(current_evento != -1) {
		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			if(participando[client]) {
				evento_infos.GetArray(current_evento, tmpeventoinfo, sizeof(EventoInfo));

				if(!tmpeventoinfo.respawn) {
					set_participando(client, false);
				}
			}
		}
	}
}

public Action TeamManager_CanChangeTeam(int entity, int team)
{
	if(current_evento != -1) {
		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			if(participando[entity]) {
				evento_infos.GetArray(current_evento, tmpeventoinfo, sizeof(EventoInfo));

				if(tmpeventoinfo.team > 0 && tmpeventoinfo.team != team) {
					CPrintToChat(entity, EVENTO_CHAT_PREFIX ... "nao e permitido %s no evento %s", "", tmpeventoinfo.name);
					return Plugin_Handled;
				}
			}
		}
	}
	return Plugin_Continue;
}

bool is_class_valid(int class)
{
	bool valid = true;

	if(tmpeventoinfo.classes > 0) {
		if(tmpeventoinfo.classes_is_whitelist) {
			if(!(tmpeventoinfo.classes & BIT_FOR_CLASS(class))) {
				valid = false;
			}
		} else {
			if(tmpeventoinfo.classes & BIT_FOR_CLASS(class)) {
				valid = false;
			}
		}
	}

	return valid;
}

public Action TeamManager_CanChangeClass(int entity, int class)
{
	if(current_evento != -1) {
		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			if(participando[entity]) {
				evento_infos.GetArray(current_evento, tmpeventoinfo, sizeof(EventoInfo));

				if(!is_class_valid(class)) {
					CPrintToChat(entity, EVENTO_CHAT_PREFIX ... "nao e permitido %s no evento %s", "", tmpeventoinfo.name);
					return Plugin_Handled;
				}
			}
		}
	}
	return Plugin_Continue;
}

Action sm_evento(int client, int args)
{
	if(client == 0) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "sai do console");
		return Plugin_Handled;
	}

	if(IsFakeClient(client)) {
		return Plugin_Handled;
	}

	if(current_evento == -1) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "nao ha nenhum evento no momento");
		return Plugin_Handled;
	}

	if(current_state == EVENTO_STATE_IN_PROGRESS ||
		current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "nao e possivel participar de um evento em progresso");
		return Plugin_Handled;
	}

	set_participando(client, !participando[client]);

	evento_infos.GetArray(current_evento, tmpeventoinfo, sizeof(EventoInfo));

	if(participando[client]) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "voce ira participar do evento %s", tmpeventoinfo.name);
		CPrintToChatAll(EVENTO_CHAT_PREFIX ... "%N vai participar do evento %s digite !evento para participar tbm", client, tmpeventoinfo.name);
	} else {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "voce nao vai mais participando do evento %s", tmpeventoinfo.name);
	}

	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client)) {
		return;
	}

	
}

bool handle_time(int &secs, int num, const char[] singular, const char[] plural)
{
	if(secs >= num) {
		int hours = (secs / num);
		IntToString(hours, tmpintstr, INT_STR_MAX);
		StrCat(tmptimestr, TIME_STR_MAX, tmpintstr);
		if(hours == 1) {
			StrCat(tmptimestr, TIME_STR_MAX, singular);
		} else {
			StrCat(tmptimestr, TIME_STR_MAX, plural);
		}
		int remainder = (secs % num);
		secs = remainder;
		return true;
	} else {
		return false;
	}
}

static char tmptimesstr[7][INT_STR_MAX];
int parse_time_string(const char[] str)
{
	int ret = 0;
	if(strcmp(str, "-1") == 0) {
		ret = -1;
	} else {
		int num = ExplodeString(str, ":", tmptimesstr, 7, INT_STR_MAX);
		switch(num) {
			case 1: {
				ret += StringToInt(tmptimesstr[0]);
			}
			case 2: {
				ret += StringToInt(tmptimesstr[1]);
				ret += (StringToInt(tmptimesstr[0]) * 60);
			}
			case 3: {
				ret += StringToInt(tmptimesstr[2]);
				ret += (StringToInt(tmptimesstr[1]) * 60);
				ret += (StringToInt(tmptimesstr[0]) * 3600);
			}
			default: {
				ret = -1;
			}
		}
	}
	return ret;
}

void format_seconds(int secs)
{
	tmptimestr[0] = '\0';

	do {
		if(handle_time(secs, 31557600, " ano ", " anos ")) {
		} else if(handle_time(secs, 2629800, " mes ", " meses ")) {
		} else if(handle_time(secs, 604800, " semana ", " semanas ")) {
		} else if(handle_time(secs, 86400, " dia ", " dias ")) {
		} else if(handle_time(secs, 3600, " hora ", " horas ")) {
		} else if(handle_time(secs, 60, " minuto ", " minutos ")) {
		} else {
			IntToString(secs, tmpintstr, INT_STR_MAX);
			StrCat(tmptimestr, TIME_STR_MAX, tmpintstr);
			if(secs == 1) {
				StrCat(tmptimestr, TIME_STR_MAX, " segundo ");
			} else {
				StrCat(tmptimestr, TIME_STR_MAX, " segundos ");
			}
			secs = 0;
		}
	} while(secs > 0);
}

public void OnClientDisconnected(int client)
{
	if(client == usando_menu) {
		usando_menu = -1;
	}
	if(client == chat_listen.client) {
		chat_listen.client = -1;
	}

	participando[client] = false;
	vencedor[client] = false;
}

int classes_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			menu.GetItem(0, tmpintstr, INT_STR_MAX);

			int idx = StringToInt(tmpintstr);

			evento_explain_menu(param1, idx);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

void display_classes_menu(int client, int idx)
{
	evento_infos.GetArray(idx, tmpeventoinfo, sizeof(EventoInfo));

	Menu menu = CreateMenu(classes_menu_handler);
	if(tmpeventoinfo.classes_is_whitelist) {
		menu.SetTitle("permitidas");
	} else {
		menu.SetTitle("bloqueadas");
	}
	menu.ExitBackButton = true;

	IntToString(idx, tmpintstr, INT_STR_MAX);
	menu.AddItem(tmpintstr, "", ITEMDRAW_IGNORE);

	if(tmpeventoinfo.classes & BIT_FOR_CLASS(TFClass_Scout)) {
		menu.AddItem("", "scout", ITEMDRAW_DISABLED);
	}
	if(tmpeventoinfo.classes & BIT_FOR_CLASS(TFClass_Sniper)) {
		menu.AddItem("", "sniper", ITEMDRAW_DISABLED);
	}
	if(tmpeventoinfo.classes & BIT_FOR_CLASS(TFClass_Soldier)) {
		menu.AddItem("", "soldier", ITEMDRAW_DISABLED);
	}
	if(tmpeventoinfo.classes & BIT_FOR_CLASS(TFClass_DemoMan)) {
		menu.AddItem("", "demoman", ITEMDRAW_DISABLED);
	}
	if(tmpeventoinfo.classes & BIT_FOR_CLASS(TFClass_Medic)) {
		menu.AddItem("", "medic", ITEMDRAW_DISABLED);
	}
	if(tmpeventoinfo.classes & BIT_FOR_CLASS(TFClass_Heavy)) {
		menu.AddItem("", "heavy", ITEMDRAW_DISABLED);
	}
	if(tmpeventoinfo.classes & BIT_FOR_CLASS(TFClass_Pyro)) {
		menu.AddItem("", "pyro", ITEMDRAW_DISABLED);
	}
	if(tmpeventoinfo.classes & BIT_FOR_CLASS(TFClass_Spy)) {
		menu.AddItem("", "spy", ITEMDRAW_DISABLED);
	}
	if(tmpeventoinfo.classes & BIT_FOR_CLASS(TFClass_Engineer)) {
		menu.AddItem("", "engineer", ITEMDRAW_DISABLED);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

int evento_explain_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		menu.GetItem(0, tmpintstr, INT_STR_MAX);
		int idx = StringToInt(tmpintstr);

		menu.GetItem(param2, tmpintstr, INT_STR_MAX);
		param2 = StringToInt(tmpintstr);

		switch(param2) {
			case 0: {
				display_classes_menu(param1, idx);
			}
		}
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			menu.GetItem(0, tmpintstr, INT_STR_MAX);

			int idx = StringToInt(tmpintstr);

			explain_menu(param1, idx);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

void evento_explain_menu(int client, int idx)
{
	evento_infos.GetArray(idx, tmpeventoinfo, sizeof(EventoInfo));

	Menu menu = CreateMenu(evento_explain_menu_handler);
	menu.SetTitle(tmpeventoinfo.name);
	menu.ExitBackButton = true;

	IntToString(idx, tmpintstr, INT_STR_MAX);
	menu.AddItem(tmpintstr, "", ITEMDRAW_IGNORE);

	if(tmpeventoinfo.classes > 0) {
		menu.AddItem("0", "classes");
		menu.AddItem("", "", ITEMDRAW_SPACER);
	}

	int len = tmpeventoinfo.explains.Length;
	for(int i = 0; i < len; ++i) {
		tmpeventoinfo.explains.GetString(i, tmpexplainstr, EVENTO_EXPLAIN_MAX);

		menu.AddItem("", tmpexplainstr, ITEMDRAW_DISABLED);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

int explain_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		menu.GetItem(param2, tmpintstr, INT_STR_MAX);
		int idx = StringToInt(tmpintstr);

		evento_explain_menu(param1, idx);
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

void explain_menu(int client, int item)
{
	Menu menu = CreateMenu(explain_menu_handler);
	menu.SetTitle("Eventos");

	int len = evento_infos.Length;
	for(int i = 0; i < len; ++i) {
		evento_infos.GetArray(i, tmpeventoinfo, sizeof(EventoInfo));

		IntToString(i, tmpintstr, INT_STR_MAX);
		menu.AddItem(tmpintstr, tmpeventoinfo.name);
	}

	if(item == -1) {
		menu.Display(client, MENU_TIME_FOREVER);
	} else {
		menu.DisplayAt(client, item, MENU_TIME_FOREVER);
	}
}

Action sm_explain(int client, int args)
{
	if(client == 0) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "sai do console");
		return Plugin_Handled;
	}

	if(current_evento == -1) {
		explain_menu(client, -1);
	} else {
		evento_explain_menu(client, current_evento);
	}

	return Plugin_Handled;
}

void set_participando(int client, bool value)
{
	if(!value) {
		vencedor[client] = false;
	}

	participando[client] = value;
}

int player_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		menu.GetItem(1, tmpintstr, INT_STR_MAX);
		int idx = StringToInt(tmpintstr);

		menu.GetItem(0, tmpintstr, INT_STR_MAX);
		int player = StringToInt(tmpintstr);
		player = GetClientOfUserId(player);
		if(player == 0) {
			CPrintToChat(param1, EVENTO_CHAT_PREFIX ... "o jogador foi desconectado");
			players_menu(param1, idx);
			return 0;
		}

		if(param2 == 2) {
			set_participando(player, false);
		} else if(param2 == 3) {
			vencedor[player] = !vencedor[player];
		}

		players_menu(param1, idx);
	} else if(action == MenuAction_DisplayItem) {
		menu.GetItem(0, tmpintstr, INT_STR_MAX);
		int player = StringToInt(tmpintstr);
		player = GetClientOfUserId(player);
		if(player == 0) {
			menu.GetItem(1, tmpintstr, INT_STR_MAX);
			int idx = StringToInt(tmpintstr);
			CPrintToChat(param1, EVENTO_CHAT_PREFIX ... "o jogador foi desconectado");
			players_menu(param1, idx);
			return 0;
		}

		if(vencedor[player]) {
			return RedrawMenuItem("desmarcar como vencedor");
		} else {
			return RedrawMenuItem("marcar como vencedor");
		}
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			menu.GetItem(1, tmpintstr, INT_STR_MAX);
			int idx = StringToInt(tmpintstr);

			players_menu(param1, idx);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

void player_menu(int client, int player, int idx)
{
	GetClientName(player, tmpplayername, MAX_NAME_LENGTH);

	Menu menu = CreateMenu(player_menu_handler, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);
	menu.SetTitle(tmpplayername);
	menu.ExitBackButton = true;

	IntToString(GetClientUserId(player), tmpintstr, INT_STR_MAX);
	menu.AddItem(tmpintstr, "", ITEMDRAW_IGNORE);

	IntToString(idx, tmpintstr, INT_STR_MAX);
	menu.AddItem(tmpintstr, "", ITEMDRAW_IGNORE);

	menu.AddItem("0", "remover");
	if(current_state == EVENTO_STATE_IN_PROGRESS) {
		menu.AddItem("1", "marcar como vencedor");
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

int players_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		menu.GetItem(0, tmpintstr, INT_STR_MAX);
		int idx = StringToInt(tmpintstr);

		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			if(param2 == 1) {
				for(int i = 1; i <= MaxClients; ++i) {
					if(!IsClientInGame(i) ||
						IsFakeClient(i) ||
						!participando[i]) {
						continue;
					}

					vencedor[i] = true;
				}

				evento_menu(param1, idx);
				return 0;
			}
		}

		menu.GetItem(param2, tmpintstr, INT_STR_MAX);
		param2 = StringToInt(tmpintstr);
		param2 = GetClientOfUserId(param2);

		if(param2 == 0) {
			CPrintToChat(param1, EVENTO_CHAT_PREFIX ... "o jogador foi desconectado");
			players_menu(param1, idx);
		} else {
			player_menu(param1, param2, idx);
		}
	} else if(action == MenuAction_DrawItem) {
		if(param2 == 0) {
			return ITEMDRAW_IGNORE;
		}

		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			if(param2 == 1) {
				return ITEMDRAW_DEFAULT;
			} else if(param2 == 2) {
				return ITEMDRAW_SPACER;
			}
		}

		menu.GetItem(param2, tmpintstr, INT_STR_MAX);
		param2 = StringToInt(tmpintstr);
		param2 = GetClientOfUserId(param2);

		if(param2 == 0) {
			return ITEMDRAW_DISABLED;
		} else {
			return ITEMDRAW_DEFAULT;
		}
	} else if(action == MenuAction_DisplayItem) {
		if(param2 == 0) {
			return RedrawMenuItem("");
		}

		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			if(param2 == 2) {
				return RedrawMenuItem("");
			} else if(param2 == 1) {
				return RedrawMenuItem("marcar todos como vencedores");
			}
		}

		menu.GetItem(param2, tmpintstr, INT_STR_MAX);
		param2 = StringToInt(tmpintstr);
		param2 = GetClientOfUserId(param2);

		if(param2 == 0) {
			return RedrawMenuItem("disconnected");
		} else {
			GetClientName(param2, tmpplayername, MAX_NAME_LENGTH);
			return RedrawMenuItem(tmpplayername);
		}
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			menu.GetItem(0, tmpintstr, INT_STR_MAX);
			int idx = StringToInt(tmpintstr);

			evento_menu(param1, idx);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

void players_menu(int client, int idx)
{
	int num_clients = 0;
	int[] clients = new int[MaxClients];

	int num_added = 0;

	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i) ||
			IsFakeClient(i) ||
			!participando[i]) {
			continue;
		}

		clients[num_clients++] = i;
	}

	if(num_clients > 0) {
		Menu menu = CreateMenu(players_menu_handler, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem|MenuAction_DrawItem);
		menu.SetTitle("Particicpantes");
		menu.ExitBackButton = true;

		IntToString(idx, tmpintstr, INT_STR_MAX);
		menu.AddItem(tmpintstr, "", ITEMDRAW_IGNORE);

		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			menu.AddItem("", "marcar todos como vencedores");
			menu.AddItem("", "", ITEMDRAW_SPACER);
		}

		for(int i = 0; i < num_clients; ++i) {
			IntToString(GetClientUserId(clients[i]), tmpintstr, INT_STR_MAX);
			menu.AddItem(tmpintstr, "player", ITEMDRAW_DISABLED);
		}

		menu.Display(client, MENU_TIME_FOREVER);
	} else {
		evento_menu(client, current_evento);
	}
}

int winner_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		menu.GetItem(1, tmpintstr, INT_STR_MAX);
		int idx = StringToInt(tmpintstr);

		menu.GetItem(0, tmpintstr, INT_STR_MAX);
		int player = StringToInt(tmpintstr);
		player = GetClientOfUserId(player);
		if(player == 0) {
			CPrintToChat(param1, EVENTO_CHAT_PREFIX ... "o jogador foi desconectado");
			winners_menu(param1, idx);
			return 0;
		}

		if(param2 == 2) {
			vencedor[player] = false;
		}

		winners_menu(param1, idx);
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			menu.GetItem(1, tmpintstr, INT_STR_MAX);
			int idx = StringToInt(tmpintstr);

			winners_menu(param1, idx);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

void winner_menu(int client, int player, int idx)
{
	GetClientName(player, tmpplayername, MAX_NAME_LENGTH);

	Menu menu = CreateMenu(winner_menu_handler);
	menu.SetTitle(tmpplayername);
	menu.ExitBackButton = true;

	IntToString(GetClientUserId(player), tmpintstr, INT_STR_MAX);
	menu.AddItem(tmpintstr, "", ITEMDRAW_IGNORE);

	IntToString(idx, tmpintstr, INT_STR_MAX);
	menu.AddItem(tmpintstr, "", ITEMDRAW_IGNORE);

	menu.AddItem("0", "remover");

	menu.Display(client, MENU_TIME_FOREVER);
}

int winners_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		menu.GetItem(0, tmpintstr, INT_STR_MAX);
		int idx = StringToInt(tmpintstr);

		if(param2 == 1) {
			end_evento();
			return 0;
		}

		menu.GetItem(param2, tmpintstr, INT_STR_MAX);
		param2 = StringToInt(tmpintstr);
		param2 = GetClientOfUserId(param2);

		if(param2 == 0) {
			CPrintToChat(param1, EVENTO_CHAT_PREFIX ... "o jogador foi desconectado");
			winners_menu(param1, idx);
		} else {
			winner_menu(param1, param2, idx);
		}
	} else if(action == MenuAction_DrawItem) {
		if(param2 == 0) {
			return ITEMDRAW_IGNORE;
		} else if(param2 == 1) {
			return ITEMDRAW_DEFAULT;
		} else if(param2 == 2) {
			return ITEMDRAW_SPACER;
		}

		menu.GetItem(param2, tmpintstr, INT_STR_MAX);
		param2 = StringToInt(tmpintstr);
		param2 = GetClientOfUserId(param2);

		if(param2 == 0) {
			return ITEMDRAW_DISABLED;
		} else {
			return ITEMDRAW_DEFAULT;
		}
	} else if(action == MenuAction_DisplayItem) {
		if(param2 == 0 || param2 == 2) {
			return RedrawMenuItem("");
		} else if(param2 == 1) {
			return RedrawMenuItem("terminar");
		}

		menu.GetItem(param2, tmpintstr, INT_STR_MAX);
		param2 = StringToInt(tmpintstr);
		param2 = GetClientOfUserId(param2);

		if(param2 == 0) {
			return RedrawMenuItem("disconnected");
		} else {
			GetClientName(param2, tmpplayername, MAX_NAME_LENGTH);
			return RedrawMenuItem(tmpplayername);
		}
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			menu.GetItem(0, tmpintstr, INT_STR_MAX);
			int idx = StringToInt(tmpintstr);

			evento_menu(param1, idx);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

void winners_menu(int client, int idx)
{
	int num_clients = 0;
	int[] clients = new int[MaxClients];

	int num_added = 0;

	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i) ||
			IsFakeClient(i) ||
			!vencedor[i]) {
			continue;
		}

		clients[num_clients++] = i;
	}

	if(num_clients > 0) {
		Menu menu = CreateMenu(winners_menu_handler, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem|MenuAction_DrawItem);
		menu.SetTitle("Marcados para vencer");
		menu.ExitBackButton = true;

		IntToString(idx, tmpintstr, INT_STR_MAX);
		menu.AddItem(tmpintstr, "", ITEMDRAW_IGNORE);

		menu.AddItem("", "terminar");
		menu.AddItem("", "", ITEMDRAW_SPACER);

		for(int i = 0; i < num_clients; ++i) {
			IntToString(GetClientUserId(clients[i]), tmpintstr, INT_STR_MAX);
			menu.AddItem(tmpintstr, "player", ITEMDRAW_DISABLED);
		}

		menu.Display(client, MENU_TIME_FOREVER);
	} else {
		evento_menu(client, current_evento);
	}
}

void stop_countdown()
{
	evento_secs = 0;
	delete countdown_handle;
	if(hud) {
		for(int i = 1; i <= MaxClients; ++i) {
			if(!IsClientInGame(i) ||
				IsFakeClient(i)) {
				continue;
			}
			ClearSyncHud(i, hud);
		}
	}
	delete hud;
}

void start_countdown(int secs)
{
	hud = CreateHudSynchronizer();
	evento_secs = secs;
	if(!countdown_tick()) {
		countdown_handle = CreateTimer(1.0, timer_countdown, 0, TIMER_REPEAT);
	}
}

void clear_evento_vars()
{
	stop_countdown();

	current_evento = -1;
	current_state = EVENTO_STATE_ENDED;

	teleport[0][0] = 0.0;
	teleport[0][1] = 0.0;
	teleport[0][2] = 0.0;

	teleport[1][0] = 0.0;
	teleport[1][1] = 0.0;
	teleport[1][2] = 0.0;

	teleport_set = 0;

	for(int i = 1; i <= MaxClients; ++i) {
		set_participando(i, false);
	}
}

void cancel_evento()
{
	clear_evento_vars();

	CPrintToChatAll(EVENTO_CHAT_PREFIX ... "evento cancelado");
}

void end_evento()
{
	evento_infos.GetArray(current_evento, tmpeventoinfo, sizeof(EventoInfo));

	int len = tmpeventoinfo.cmds[1].Length;
	for(int i = 0; i < len; ++i) {
		tmpeventoinfo.cmds[1].GetString(i, tmpcmdstr, CMD_STR_MAX);
		ServerCommand("%s", tmpcmdstr);
	}

	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i) ||
			IsFakeClient(i) ||
			!vencedor[i]) {
			continue;
		}

		CPrintToChatAll(EVENTO_CHAT_PREFIX ... "%N ganhou", i);
	}

	CPrintToChatAll(EVENTO_CHAT_PREFIX ... "evento terminado");

	clear_evento_vars();
}

void start_evento()
{
	stop_countdown();
	current_state = EVENTO_STATE_IN_PROGRESS;

	evento_infos.GetArray(current_evento, tmpeventoinfo, sizeof(EventoInfo));

	int len = tmpeventoinfo.cmds[0].Length;
	for(int i = 0; i < len; ++i) {
		tmpeventoinfo.cmds[0].GetString(i, tmpcmdstr, CMD_STR_MAX);
		ServerCommand("%s", tmpcmdstr);
	}

	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i) ||
			IsFakeClient(i) ||
			!participando[i]) {
			continue;
		}

		int class = view_as<int>(TF2_GetPlayerClass(i));
		if(!is_class_valid(class)) {
			int j = 1;
			for(; j < TF_CLASS_COUNT_ALL; ++j) {
				if(is_class_valid(j)) {
					break;
				}
			}
			TF2_SetPlayerClass(i, view_as<TFClassType>(j), _, false);
			TF2_RespawnPlayer(i);
		}

		int team = GetClientTeam(i);
		if(tmpeventoinfo.team > 0 && tmpeventoinfo.team != team) {
			team = (tmpeventoinfo.team == 2 ? 3 : 2);
			ChangeClientTeam(i, team);
		}

		if(teleport_set & BIT_FOR_TEAM(team)) {
			TeleportEntity(i, teleport[IDX_FOR_TEAM(team)]);
		}
	}

	CPrintToChatAll(EVENTO_CHAT_PREFIX ... "evento inciado");
}

bool countdown_tick()
{
	if(evento_secs == 0 || --evento_secs == 0) {
		switch(current_state) {
			case EVENTO_STATE_IN_COUNTDOWN_START:
			{ start_evento(); }
			case EVENTO_STATE_IN_COUNTDOWN_END:
			{ end_evento(); }
		}
		return true;
	} else {
		evento_infos.GetArray(current_evento, tmpeventoinfo, sizeof(EventoInfo));

		format_seconds(evento_secs);

		for(int i = 1; i <= MaxClients; ++i) {
			if(!IsClientInGame(i) ||
				IsFakeClient(i)) {
				continue;
			}

			ClearSyncHud(i, hud);
			SetHudTextParams(0.05, 0.1, 1.0, 0, 0, 255, 255);

			switch(current_state) {
				case EVENTO_STATE_IN_COUNTDOWN_START:
				{ ShowSyncHudText(i, hud, EVENTO_CON_PREFIX ... "%s começa em %s", tmpeventoinfo.name, tmptimestr); }
				case EVENTO_STATE_IN_COUNTDOWN_END:
				{ ShowSyncHudText(i, hud, EVENTO_CON_PREFIX ... "%s termina em %s", tmpeventoinfo.name, tmptimestr); }
			}
		}
	}
	return false;
}

Action timer_countdown(Handle timer, any data)
{
	if(countdown_tick()) {
		countdown_handle = null;
		return Plugin_Stop;
	} else {
		return Plugin_Continue;
	}
}

void queue_evento_end(int secs)
{
	current_state = EVENTO_STATE_IN_COUNTDOWN_END;
	start_countdown(secs);
}

void cancel_evento_end()
{
	stop_countdown();
	current_state = EVENTO_STATE_IN_PROGRESS;
}

void queue_evento_start(int idx, int secs)
{
	current_evento = idx;
	current_state = EVENTO_STATE_IN_COUNTDOWN_START;
	start_countdown(secs);
}

void cancel_evento_start()
{
	cancel_evento();
}

Action player_say(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client == chat_listen.client) {
		event.GetString("text", tmpintstr, INT_STR_MAX);

		int secs = parse_time_string(tmpintstr);
		if(secs >= 0) {
			if(chat_listen.start) {
				queue_evento_start(chat_listen.idx, secs);
			} else {
				queue_evento_end(secs);
			}
		} else {
			CPrintToChat(client, EVENTO_CHAT_PREFIX ... "tempo invalido");
		}

		chat_listen.client = -1;

		event.BroadcastDisabled = true;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

int teleport_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		menu.GetItem(0, tmpintstr, INT_STR_MAX);
		int idx = StringToInt(tmpintstr);

		char c[2];
		menu.GetItem(param2, c, 2);

		switch(c[0]) {
			case 'b': {
				float pos[3];
				GetClientAbsOrigin(param1, pos);

				static const int team = 3;
				teleport[IDX_FOR_TEAM(team)][0] = pos[0];
				teleport[IDX_FOR_TEAM(team)][1] = pos[1];
				teleport[IDX_FOR_TEAM(team)][2] = pos[2];
				teleport_set |= BIT_FOR_TEAM(team);
			}
			case 'r': {
				float pos[3];
				GetClientAbsOrigin(param1, pos);

				static const int team = 2;
				teleport[IDX_FOR_TEAM(team)][0] = pos[0];
				teleport[IDX_FOR_TEAM(team)][1] = pos[1];
				teleport[IDX_FOR_TEAM(team)][2] = pos[2];
				teleport_set |= BIT_FOR_TEAM(team);
			}
			case 'a': {
				float pos[3];
				GetClientAbsOrigin(param1, pos);

				int team = 2;
				teleport[IDX_FOR_TEAM(team)][0] = pos[0];
				teleport[IDX_FOR_TEAM(team)][1] = pos[1];
				teleport[IDX_FOR_TEAM(team)][2] = pos[2];
				teleport_set |= BIT_FOR_TEAM(team);

				team = 3;
				teleport[IDX_FOR_TEAM(team)][0] = pos[0];
				teleport[IDX_FOR_TEAM(team)][1] = pos[1];
				teleport[IDX_FOR_TEAM(team)][2] = pos[2];
				teleport_set |= BIT_FOR_TEAM(team);
			}
			case 't': {
				for(int i = 1; i <= MaxClients; ++i) {
					if(!IsClientInGame(i) ||
						IsFakeClient(i) ||
						!participando[i]) {
						continue;
					}

					int team = GetClientTeam(i);
					if(teleport_set & BIT_FOR_TEAM(team)) {
						TeleportEntity(i, teleport[IDX_FOR_TEAM(team)]);
					}
				}
			}
		}

		teleport_menu(param1, idx);
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			menu.GetItem(0, tmpintstr, INT_STR_MAX);
			int idx = StringToInt(tmpintstr);

			evento_menu(param1, idx);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

public void OnGameFrame()
{
	
}

void teleport_menu(int client, int idx)
{
	Menu menu = CreateMenu(teleport_menu_handler);
	menu.SetTitle("Teleport");
	menu.ExitBackButton = true;

	IntToString(idx, tmpintstr, INT_STR_MAX);
	menu.AddItem(tmpintstr, "", ITEMDRAW_IGNORE);

	menu.AddItem("b", "blue");
	menu.AddItem("r", "red");
	menu.AddItem("a", "ambos");
	menu.AddItem("t", "teleportar");

	menu.Display(client, MENU_TIME_FOREVER);
}

int evento_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Display) {
		usando_menu = param1;
	} else if(action == MenuAction_Select) {
		menu.GetItem(0, tmpintstr, INT_STR_MAX);
		int idx = StringToInt(tmpintstr);

		menu.GetItem(param2, tmpintstr, INT_STR_MAX);
		param2 = StringToInt(tmpintstr);

		switch(param2) {
			case 0: {
				chat_listen.client = param1;
				chat_listen.start = true;
				chat_listen.idx = idx;
				CPrintToChat(param1, EVENTO_CHAT_PREFIX ... "digite o tempo no chat");
			}
			case 1: {
				cancel_evento_start();
			}
			case 2: {
				chat_listen.client = param1;
				chat_listen.start = false;
				chat_listen.idx = idx;
				CPrintToChat(param1, EVENTO_CHAT_PREFIX ... "digite o tempo no chat");
			}
			case 3: {
				cancel_evento_end();
			}
			case 4: {
				cancel_evento();
			}
			case 5: {
				players_menu(param1, idx);
			}
			case 6: {
				winners_menu(param1, idx);
			}
			case 7: {
				teleport_menu(param1, idx);
			}
		}
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			menu.GetItem(0, tmpintstr, INT_STR_MAX);

			int idx = StringToInt(tmpintstr);

			eventos_menu(param1, idx);
		}
	} else if(action == MenuAction_End) {
		usando_menu = -1;
		delete menu;
	}

	return 0;
}

void evento_menu(int client, int idx)
{
	evento_infos.GetArray(idx, tmpeventoinfo, sizeof(EventoInfo));

	Menu menu = CreateMenu(evento_menu_handler);
	menu.SetTitle(tmpeventoinfo.name);
	if(current_evento == -1) {
		menu.ExitBackButton = true;
	}

	IntToString(idx, tmpintstr, INT_STR_MAX);
	menu.AddItem(tmpintstr, "", ITEMDRAW_IGNORE);

	if(current_evento == idx) {
		menu.AddItem("5", "participantes");
		if(current_state == EVENTO_STATE_IN_PROGRESS) {
			menu.AddItem("6", "marcados para vencer");
		}
	}

	menu.AddItem("7", "teleport");

	if(current_evento == -1) {
		menu.AddItem("0", "marcar inicio");
	} else {
		switch(current_state) {
			case EVENTO_STATE_IN_COUNTDOWN_END:
			{ menu.AddItem("3", "cancelar termino"); }
			case EVENTO_STATE_IN_COUNTDOWN_START:
			{ menu.AddItem("1", "cancelar inicio"); }
			case EVENTO_STATE_IN_PROGRESS: {
				menu.AddItem("2", "marcar termino");
				menu.AddItem("4", "cancelar");
			}
		}
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

int eventos_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Display) {
		usando_menu = param1;
	} else if(action == MenuAction_Select) {
		menu.GetItem(param2, tmpintstr, INT_STR_MAX);
		int idx = StringToInt(tmpintstr);

		evento_menu(param1, idx);
	} else if(action == MenuAction_End) {
		usando_menu = -1;
		delete menu;
	}

	return 0;
}

void eventos_menu(int client, int item)
{
	Menu menu = CreateMenu(eventos_menu_handler);
	menu.SetTitle("Eventos");

	int len = evento_infos.Length;
	for(int i = 0; i < len; ++i) {
		evento_infos.GetArray(i, tmpeventoinfo, sizeof(EventoInfo));

		IntToString(i, tmpintstr, INT_STR_MAX);
		menu.AddItem(tmpintstr, tmpeventoinfo.name);
	}

	if(item == -1) {
		menu.Display(client, MENU_TIME_FOREVER);
	} else {
		menu.DisplayAt(client, item, MENU_TIME_FOREVER);
	}
}

Action sm_mevento(int client, int args)
{
	if(evento_infos == null) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "nao ha nenhum evento carregado");
		return Plugin_Handled;
	}

	if(client == 0) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "sai do console");
		return Plugin_Handled;
	}

	if(usando_menu != -1) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "manda o %N sair do menu de evento", usando_menu);
		return Plugin_Handled;
	}

	if(current_evento == -1) {
		eventos_menu(client, -1);
	} else {
		evento_menu(client, current_evento);
	}

	return Plugin_Handled;
}

Action sm_reventos(int client, int args)
{
	unload_eventos();
	load_eventos();
	return Plugin_Handled;
}

Action sm_leventos(int client, int args)
{
	if(evento_infos == null) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "nao ha nenhum evento carregado");
		return Plugin_Handled;
	}
	int len = evento_infos.Length;
	int buffer_len = (EVENTO_NAME_MAX * len);
	char[] buffer = new char[buffer_len];
	for(int i = 0; i < len; ++i) {
		evento_infos.GetArray(i, tmpeventoinfo, sizeof(EventoInfo));
		StrCat(buffer, buffer_len, tmpeventoinfo.name[i]);
		StrCat(buffer, buffer_len, "\n");
	}
	PrintToConsole(client, "%s", buffer);
	return Plugin_Handled;
}