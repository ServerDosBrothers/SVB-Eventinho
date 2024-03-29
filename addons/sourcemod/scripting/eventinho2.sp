#include <sourcemod>
#include <keyvalues>
#include <clientprefs>
#include <tf2>
#include <tf2_stocks>
#include <dhooks>
#include <morecolors>
#include <teammanager>
#include <sdkhooks>
#include <tf2items>
#include <achivmissions>
#include <tf2utils>
#include "eventinho2"

#undef REQUIRE_PLUGIN
#include <svb-godmode>
#include <svb-randomcrits>
#include <tf2-weapons-api>

//#define DEBUG

//game/shared/econ/econ_item_constants.h
#define MAX_ATTRIBUTES_PER_ITEM 15
//game/shared/tf/tf_shareddefs.h
#define TF_CLASS_COUNT_ALL 10

#define COLLISION_GROUP_PLAYER_MOVEMENT 8
#define CONTENTS_REDTEAM CONTENTS_TEAM1
#define CONTENTS_BLUETEAM CONTENTS_TEAM2

#define EF_BONEMERGE 0x001
#define EF_BONEMERGE_FASTCULL 0x080
#define EF_PARENT_ANIMATES 0x200

#define EVENTO_NAME_MAX 64
#define EVENTO_REWARD_NAME_MAX 64
#define EVENTO_EXPLAIN_MAX 256
#define EVENTO_CONFIG_NAME_MAX 32
#define EVENTO_CONFIG_VALUE_MAX 32

#define CLASS_NAME_MAX 10
#define EVENTO_CLASSES_STR_MAX (CLASS_NAME_MAX * TF_CLASS_COUNT_ALL)

#define MENU_ITEM_DISPLAY_MAX 64
#define MENU_ITEM_INFO_MAX 64

#define ENTITY_CLASSNAME_MAX 64

#define QUERY_STR_MAX 256
#define CMD_STR_MAX 256
#define INT_STR_MAX 10
#define TIME_STR_MAX 256
#define TIME_INPUT_STR_MAX ((INT_STR_MAX+1) * 7)

#define EVENTO_CHAT_PREFIX "{dodgerblue}[Evento]{default} "
#define EVENTO_CON_PREFIX "[Evento] "

#define COROA_ITEM_INDEX 342
#define UNUSUAL_ATTR_IDX 134

#define IDX_FOR_TEAM(%1) (view_as<int>(%1)-2)

#define BIT_FOR_CLASS(%1) (1 << (view_as<int>(%1)-1))
#define BIT_FOR_TEAM(%1) (1 << (view_as<int>(%1)-1))

#define PACK_2_INTS(%1,%2) ((%1 << 16) | %2)
#define PACKED_2_INTS_1(%1) (%1 >> 16)
#define PACKED_2_INTS_2(%1) (%1 & 32767)

#define AttributePair int

enum struct RewardInfo
{
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
	bool maps_is_whitelist;
	ArrayList maps;
	int team;
	int min_players;
	ArrayList explains;
	ArrayList cmds[2];
	ArrayList rewards;
	StringMap default_config;
}

enum struct EventoConfig
{
	bool respawn;
	bool bhop;
	bool melee; 
	bool random_crits;
	bool damage;
	bool infinite_ammo;
	bool infinite_metal;
	bool friendly_fire;
	bool show_sprite;

	void Init(EventoInfo event) {
		this.respawn = false;
		this.bhop = false;
		this.melee = false;
		this.random_crits = false;
		this.damage = true;
		this.show_sprite = false;

		StringMap default_config = event.default_config;
		char config_value[EVENTO_CONFIG_VALUE_MAX];

		if(default_config.GetString("respawn", config_value, sizeof(config_value))) {
			this.respawn = view_as<bool>(StringToInt(config_value));
		}

		if(default_config.GetString("bhop", config_value, sizeof(config_value))) {
			this.bhop = view_as<bool>(StringToInt(config_value));
		}

		if(default_config.GetString("melee", config_value, sizeof(config_value))) {
			this.melee = view_as<bool>(StringToInt(config_value));
		}

		if(default_config.GetString("random_crits", config_value, sizeof(config_value))) {
			this.random_crits = view_as<bool>(StringToInt(config_value));
		}

		if(default_config.GetString("damage", config_value, sizeof(config_value))) {
			this.damage = view_as<bool>(StringToInt(config_value));
		}

		if(default_config.GetString("infinite_ammo", config_value, sizeof(config_value))) {
			this.infinite_ammo = view_as<bool>(StringToInt(config_value));
		}

		if(default_config.GetString("infinite_metal", config_value, sizeof(config_value))) {
			this.infinite_metal = view_as<bool>(StringToInt(config_value));
		}

		if(default_config.GetString("friendly_fire", config_value, sizeof(config_value))) {
			this.friendly_fire = view_as<bool>(StringToInt(config_value));
		}

		if(default_config.GetString("show_sprite", config_value, sizeof(config_value))) {
			this.show_sprite = view_as<bool>(StringToInt(config_value));
		}
	}
}
enum struct EventoMenus
{
	Menu explain;
	Menu ranking;
	Menu classes;
}

enum EventoPrefabs
{
	PREFAB_COROA
}

enum struct ChatListenInfo
{
	int client;
	bool start;
	int idx;
}

static ConVar mp_friendlyfire;
static ConVar tf_avoidteammates;
DynamicHook wants_lag_compensation = null;
int wants_lag_compensation_hook_id[MAXPLAYERS + 1] = { INVALID_HOOK_ID, ... };

static ArrayList evento_infos;
static StringMap eventoidmap;
static Handle hud;
static Handle hud_participating;
static int current_evento_idx = -1;
static EventoInfo current_evento;
static EventoConfig current_config;
static EventoState current_state = EVENTO_STATE_ENDED;
static int selected_evento_idx[MAXPLAYERS+1];
static int evento_secs;
static bool participando[MAXPLAYERS+1];
static bool vencedor[MAXPLAYERS+1];
static int usando_menu = -1;
static Handle countdown_handle;
static ChatListenInfo chat_listen;
static float teleport[2][3];
static float teleport_angles[2][3];
static int teleport_set;
static Handle dummy_item_view;
static Database thedb;
static ArrayList winned_eventos[MAXPLAYERS+1];
static ArrayList reward_entrefs[MAXPLAYERS+1];
static StringMap eventomenus;
static Menu explainmenu;
static Menu rankglobal;
static Menu rankmenu;
static int laserbeam;
static int playersprite[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};
static bool nukealguemorreu;
static Handle timerpodesematar;
static bool podesematar = true;
static Handle timer20seg;
static bool semato[MAXPLAYERS+1];
static bool morreu[MAXPLAYERS+1];
static bool godmode_loaded = false;
static Achievement achiv_rei1 = Achievement_Null;
static Achievement achiv_rei2 = Achievement_Null;
//static Achievement achiv_rei3 = Achievement_Null;
//static Achievement achiv_rei4 = Achievement_Null;
static Achievement achiv_rei5 = Achievement_Null;
//static Achievement achiv_rei6 = Achievement_Null;
static Achievement achiv_rng = Achievement_Null;
static Achievement achiv_nuke = Achievement_Null;
//static Achievement achiv_hhh = Achievement_Null;
static Achievement achiv_parkour = Achievement_Null;
static Achievement achiv_nezay = Achievement_Null;
static Achievement achiv_bind = Achievement_Null;
static Achievement achiv_domin = Achievement_Null;
static Achievement achiv_color = Achievement_Null;
static Handle reward_preference_cookie = null;

public void OnAchievementsLoaded()
{
	achiv_rei1 = Achievement.FindByName("rei iniciante");
	achiv_rei2 = Achievement.FindByName("rei-streak");
	//achiv_rei3 = Achievement.FindByName("rei supremo");
	//achiv_rei4 = Achievement.FindByName("rei profissional");
	achiv_rei5 = Achievement.FindByName("reis unidos");
	//achiv_rei6 = Achievement.FindByName("rei mediano");
	achiv_rng = Achievement.FindByName("rng god");
	achiv_nuke = Achievement.FindByName("war, war never changes");
	//achiv_hhh = Achievement.FindByName("a-besta-do");
	achiv_parkour = Achievement.FindByName("hardcore parkour");
	achiv_nezay = Achievement.FindByName("nezay junior");
	achiv_bind = Achievement.FindByName("bind errada burror");
	achiv_domin = Achievement.FindByName("tryhard");
	achiv_color = Achievement.FindByName("daltonico");
}

static bool parse_classes_str(int &classes, const char[] str, const char[] eventoname)
{
	char classnames[TF_CLASS_COUNT_ALL][CLASS_NAME_MAX];

	int num = ExplodeString(str, "|", classnames, TF_CLASS_COUNT_ALL, CLASS_NAME_MAX);
	for(int i = 0; i < num; ++i) {
		if(StrEqual(classnames[i], "scout")) {
			classes |= BIT_FOR_CLASS(TFClass_Scout);
		} else if(StrEqual(classnames[i], "sniper")) {
			classes |= BIT_FOR_CLASS(TFClass_Sniper);
		} else if(StrEqual(classnames[i], "soldier")) {
			classes |= BIT_FOR_CLASS(TFClass_Soldier);
		} else if(StrEqual(classnames[i], "demoman")) {
			classes |= BIT_FOR_CLASS(TFClass_DemoMan);
		} else if(StrEqual(classnames[i], "medic")) {
			classes |= BIT_FOR_CLASS(TFClass_Medic);
		} else if(StrEqual(classnames[i], "heavy")) {
			classes |= BIT_FOR_CLASS(TFClass_Heavy);
		} else if(StrEqual(classnames[i], "pyro")) {
			classes |= BIT_FOR_CLASS(TFClass_Pyro);
		} else if(StrEqual(classnames[i], "spy")) {
			classes |= BIT_FOR_CLASS(TFClass_Spy);
		} else if(StrEqual(classnames[i], "engineer")) {
			classes |= BIT_FOR_CLASS(TFClass_Engineer);
		} else {
			LogError(EVENTO_CON_PREFIX ... "evento %s tem classe desconhecida %s", eventoname, classnames[i]);
			return false;
		}
	}
	return true;
}

#if defined DEBUG
static void build_classes_str(int classes, char debugclassesvalue[EVENTO_CLASSES_STR_MAX])
{
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

	if(len > 0) {
		debugclassesvalue[len-1] = '\0';
	}
}
#endif

static void handle_prefab(EventoPrefabs prefab, float value, EventoInfo eventoinfo
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

			RewardInfo rewardinfo

			rewardinfo.id = COROA_ITEM_INDEX;
			rewardinfo.attributes[0] = attr;
			rewardinfo.attributes[1] = -1;

			eventoinfo.rewards.PushArray(rewardinfo, sizeof(RewardInfo));
		}
	}
}

static void handle_str_array(KeyValues kvEventos, const char[] name, ArrayList &arr, char[] str, int size)
{
	if(kvEventos.JumpToKey(name)) {
		if(kvEventos.GotoFirstSubKey(false)) {
		#if defined DEBUG
			PrintToServer(EVENTO_CON_PREFIX ... "  %s", name);
		#endif

			arr = new ArrayList(ByteCountToCells(size));

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

static void unload_eventos()
{
	for(int i = 1; i <= MaxClients; ++i) {
		if(IsClientInGame(i)) {
			OnClientDisconnect(i);
		}
	}

	cancel_evento();

	EventoInfo eventinfo;

	int len = evento_infos.Length;
	for(int i = 0; i < len; ++i) {
		evento_infos.GetArray(i, eventinfo, sizeof(EventoInfo));

		delete eventinfo.explains;
		delete eventinfo.default_config;
		delete eventinfo.cmds[0];
		delete eventinfo.cmds[1];
		delete eventinfo.rewards;
	}

	char name[EVENTO_NAME_MAX];

	EventoMenus menus;

	StringMapSnapshot snap = eventomenus.Snapshot();
	len = snap.Length;
	for(int i = 0; i < len; ++i) {
		snap.GetKey(i, name, EVENTO_NAME_MAX);

		eventomenus.GetArray(name, menus, sizeof(EventoMenus));

		delete menus.ranking;
		delete menus.classes;
		delete menus.explain;
	}
	delete snap;

	delete explainmenu;
	delete rankmenu;
	delete rankglobal;
	delete eventomenus;
	delete evento_infos;
	delete eventoidmap;
}

static void load_eventos()
{
	char eventofilepath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, eventofilepath, PLATFORM_MAX_PATH, "data/eventos2.txt");

	if(FileExists(eventofilepath)) {
		KeyValues kvEventos = new KeyValues("Eventos");
		kvEventos.ImportFromFile(eventofilepath);

		if(kvEventos.GotoFirstSubKey()) {
			evento_infos = new ArrayList(sizeof(EventoInfo));
			eventoidmap = new StringMap();
			explainmenu = new Menu(explain_menu_handler);
			explainmenu.SetTitle("Eventos");
			rankmenu = new Menu(rank_menu_handler);
			rankmenu.SetTitle("Eventos");
			rankmenu.AddItem("-1", "Todos");
			eventomenus = new StringMap();
			rankglobal = new Menu(rankglobal_menu_handler);
			rankglobal.SetTitle("Rank global");
			rankglobal.ExitBackButton = true;
			rankglobal.AddItem("n", "<<nenhum jogador>>", ITEMDRAW_DISABLED);

			char classesvalue[EVENTO_CLASSES_STR_MAX];
			char cmdstr[CMD_STR_MAX];
			char explain[EVENTO_EXPLAIN_MAX];
			char intstr[INT_STR_MAX];
			char rewardname[EVENTO_REWARD_NAME_MAX];

			RewardInfo rewardinfo;
			EventoInfo eventinfo;
			EventoMenus menus;

			do {
				kvEventos.GetSectionName(eventinfo.name, EVENTO_NAME_MAX);
			#if defined DEBUG
				PrintToServer(EVENTO_CON_PREFIX ... " %s", eventinfo.name);
			#endif

				eventinfo.team = kvEventos.GetNum("team");
				eventinfo.min_players = kvEventos.GetNum("min_players");

				bool valid = true;

				classesvalue[0] = '\0';

				if(kvEventos.JumpToKey("classes_whitelist")) {
					if(kvEventos.JumpToKey("classes_blacklist")) {
						LogError(EVENTO_CON_PREFIX ... " evento %s tem classes_blacklist junto com classes_whitelist", eventinfo.name);
						valid = false;
						kvEventos.GoBack();
					} else {
						eventinfo.classes_is_whitelist = true;
						kvEventos.GetString(NULL_STRING, classesvalue, EVENTO_CLASSES_STR_MAX);
					}
					kvEventos.GoBack();
				} else if(kvEventos.JumpToKey("classes_blacklist")) {
					if(kvEventos.JumpToKey("classes_whitelist")) {
						LogError(EVENTO_CON_PREFIX ... " evento %s tem classes_whitelist junto com classes_blacklist", eventinfo.name);
						valid = false;
						kvEventos.GoBack();
					} else {
						eventinfo.classes_is_whitelist = false;
						kvEventos.GetString(NULL_STRING, classesvalue, EVENTO_CLASSES_STR_MAX);
					}
					kvEventos.GoBack();
				}

				if(!valid) {
					continue;
				}

				eventinfo.classes = 0;

				if(classesvalue[0] != '\0') {
					if(!parse_classes_str(eventinfo.classes, classesvalue, eventinfo.name)) {
						continue;
					}
				}

			#if defined DEBUG
				PrintToServer(EVENTO_CON_PREFIX ... "  classes");
				if(eventinfo.classes_is_whitelist) {
					PrintToServer(EVENTO_CON_PREFIX ... "    type = whitelist");
				} else {
					PrintToServer(EVENTO_CON_PREFIX ... "    type = blacklist");
				}
				PrintToServer(EVENTO_CON_PREFIX ... "    raw value = %i", eventinfo.classes);
				PrintToServer(EVENTO_CON_PREFIX ... "    raw str value = %s", classesvalue);
				char debugclassesvalue[EVENTO_CLASSES_STR_MAX]
				build_classes_str(eventinfo.classes, debugclassesvalue);
				PrintToServer(EVENTO_CON_PREFIX ... "    counstructed str value = %s", debugclassesvalue);
			#endif

				eventinfo.rewards = new ArrayList(sizeof(RewardInfo));

				if(kvEventos.JumpToKey("coroa_unusual")) {
				#if defined DEBUG
					PrintToServer(EVENTO_CON_PREFIX ... "  coroa_unusual");
				#endif

					float value = kvEventos.GetFloat(NULL_STRING, 0.0);
					handle_prefab(PREFAB_COROA, value, eventinfo
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
							kvEventos.GetSectionName(rewardname, EVENTO_REWARD_NAME_MAX);
						#if defined DEBUG
							PrintToServer(EVENTO_CON_PREFIX ... "    %s", rewardname);
						#endif

							if(StrEqual(rewardname, "coroa")) {
								float value = kvEventos.GetFloat(NULL_STRING, 0.0);
								handle_prefab(PREFAB_COROA, value, eventinfo
							#if defined DEBUG
								,"      "
							#endif
								);
							} else {
								LogError(EVENTO_CON_PREFIX ... " evento %s tem reward_prefab desconhecido %s", eventinfo.name, rewardname);
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
							kvEventos.GetSectionName(rewardname, EVENTO_REWARD_NAME_MAX);
						#if defined DEBUG
							PrintToServer(EVENTO_CON_PREFIX ... "    %s", rewardname);
						#endif

							rewardinfo.id = kvEventos.GetNum("id", -1);
							if(rewardinfo.id < 0) {
								LogError(EVENTO_CON_PREFIX ... " evento %s reward %s tem id negativo", eventinfo.name, rewardname);
								continue;
							}

							rewardinfo.model[0] = '\0';

						#if defined DEBUG
							PrintToServer(EVENTO_CON_PREFIX ... "      id = %i", rewardinfo.id);
						#endif

							if(kvEventos.JumpToKey("attributes")) {
								if(kvEventos.GotoFirstSubKey(false)) {
								#if defined DEBUG
									PrintToServer(EVENTO_CON_PREFIX ... "      attributes");
								#endif

									int attr_idx = 0;

									do {
										kvEventos.GetSectionName(intstr, INT_STR_MAX);
									#if defined DEBUG
										PrintToServer(EVENTO_CON_PREFIX ... "        id str = %s", intstr);
									#endif

										int id = StringToInt(intstr);
										if(id < 0) {
											LogError(EVENTO_CON_PREFIX ... " evento %s reward %s tem attrbuto com id negativo", eventinfo.name, rewardname);
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

										rewardinfo.attributes[attr_idx++] = attr;
									} while(kvEventos.GotoNextKey(false));

									rewardinfo.attributes[attr_idx] = -1;

									kvEventos.GoBack();
								}

								kvEventos.GoBack();
							}

							if(!valid) {
								break;
							}

							eventinfo.rewards.PushArray(rewardinfo, sizeof(RewardInfo));
						} while(kvEventos.GotoNextKey());

						kvEventos.GoBack();
					}

					kvEventos.GoBack();
				}

				if(!valid) {
					continue;
				}

				if(eventinfo.rewards.Length == 0) {
					delete eventinfo.rewards;
				}

				eventinfo.default_config = new StringMap();

				if(kvEventos.JumpToKey("default_config")) {
					if(kvEventos.GotoFirstSubKey(false)) {
						do {
							char config_name[EVENTO_CONFIG_NAME_MAX];
							kvEventos.GetSectionName(config_name, sizeof(config_name));

							char config_value[EVENTO_CONFIG_VALUE_MAX];
							kvEventos.GetString(NULL_STRING, config_value, sizeof(config_value));

							eventinfo.default_config.SetString(config_name, config_value);
						} while(kvEventos.GotoNextKey(false));
						kvEventos.GoBack();
					}
					kvEventos.GoBack();
				}

				handle_str_array(kvEventos, "explains", eventinfo.explains, explain, EVENTO_EXPLAIN_MAX);

				handle_str_array(kvEventos, "cmd_start", eventinfo.cmds[0], cmdstr, CMD_STR_MAX);
				handle_str_array(kvEventos, "cmd_end", eventinfo.cmds[1], cmdstr, CMD_STR_MAX);

				int idx = evento_infos.PushArray(eventinfo, sizeof(EventoInfo));
				eventoidmap.SetValue(eventinfo.name, idx);

				menus.classes = create_classes_menu(eventinfo, idx);
				menus.explain = create_explain_menu(eventinfo, idx);

				menus.ranking = new Menu(evento_rank_menu_handler);
				menus.ranking.SetTitle(eventinfo.name);
				menus.ranking.ExitBackButton = true;
				IntToString(idx, intstr, INT_STR_MAX);
				menus.ranking.AddItem(intstr, "", ITEMDRAW_IGNORE);
				menus.ranking.AddItem("n", "<<nenhum jogador>>", ITEMDRAW_DISABLED);

				eventomenus.SetArray(eventinfo.name, menus, sizeof(EventoMenus));

				IntToString(idx, intstr, INT_STR_MAX);
				explainmenu.AddItem(intstr, eventinfo.name);

				IntToString(idx, intstr, INT_STR_MAX);
				rankmenu.AddItem(intstr, eventinfo.name);
			} while(kvEventos.GotoNextKey());

			kvEventos.GoBack();
		}

		delete kvEventos;
	}
}

static void on_tr_error(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("%s", error);
}

static void on_query_error(Database db, DBResultSet results, const char[] error, any data)
{
	if(!results) {
		LogError("%s", error);
	}
}

static void on_winner_query(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null) {
		LogError("%s", error);
		return;
	}

	int client = GetClientOfUserId(data);
	if(client == 0) {
		return;
	}

	if(results.HasResults) {
		if(winned_eventos[client] == null) {
			winned_eventos[client] = new ArrayList();
		}

		char name[EVENTO_NAME_MAX];

		do {
			do {
				if(!results.FetchRow()) {
					continue;
				}

				results.FetchString(0, name, EVENTO_NAME_MAX);

				int idx = -1;
				if(eventoidmap.GetValue(name, idx)) {
					if(winned_eventos[client].FindValue(idx) == -1) {
						winned_eventos[client].Push(idx);
					}
				}
			} while(results.MoreRows);
		} while(results.FetchMoreResults());
	}
}

static void delete_reward_ents(int client)
{
	if(reward_entrefs[client] == null) {
		return;
	}

	int len = reward_entrefs[client].Length;
	for(int i = 0; i < len; ++i) {
		int entity = reward_entrefs[client].Get(i);
		entity = EntRefToEntIndex(entity);

		if(entity != -1) {
			TF2_RemoveWearable(client, entity);
			RemoveEntity(entity);
		}
	}

	delete reward_entrefs[client];
}

static void give_reward(int client, RewardInfo reward)
{
	TF2Items_SetItemIndex(dummy_item_view, reward.id);

	int attr_len = 0;
	while(reward.attributes[attr_len] != -1) {
		AttributePair attr = reward.attributes[attr_len];

		int idx = PACKED_2_INTS_1(attr);
		int value = PACKED_2_INTS_2(attr);

		TF2Items_SetAttribute(dummy_item_view, attr_len, idx, float(value));
		++attr_len;
	}

	TF2Items_SetNumAttributes(dummy_item_view, attr_len);

	int entity = TF2Items_GiveNamedItem(client, dummy_item_view);
	DispatchSpawn(entity);
	TF2Util_EquipPlayerWearable(client, entity);
	SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", 1);

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", client);

	SetVariantString("head");
	AcceptEntityInput(entity, "SetParentAttachment");

	float offset[3];
	offset[2] += 0.0;
	SetEntPropVector(entity, Prop_Data, "m_vecOrigin", offset);

	int effects = GetEntProp(entity, Prop_Send, "m_fEffects");
	effects |= EF_PARENT_ANIMATES;
	effects &= ~(EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
	SetEntProp(entity, Prop_Send, "m_fEffects", effects);

	if(reward.model[0] != '\0') {
		SetEntityModel(entity, reward.model);
	}

	reward_entrefs[client].Push(EntIndexToEntRef(entity));
}

static void give_rewards_ex(int client, int idx)
{
	EventoInfo eventoinfo;
	evento_infos.GetArray(idx, eventoinfo, sizeof(EventoInfo));

	delete_reward_ents(client);

	if(eventoinfo.rewards != null) {
		int len = eventoinfo.rewards.Length;
		if(len > 0) {
			reward_entrefs[client] = new ArrayList();
		}

		RewardInfo reward;
		for(int i = 0; i < len; ++i) {
			eventoinfo.rewards.GetArray(i, reward, sizeof(RewardInfo));

			give_reward(client, reward);
		}
	}
}

static void give_rewards(int client)
{
	delete_reward_ents(client);

	if(winned_eventos[client] == null) {
		return;
	}

	int len = winned_eventos[client].Length;
	if(len == 0) {
		return;
	}

	int idx = GetRandomInt(0, len-1);
	idx = winned_eventos[client].Get(idx);

	if(AreClientCookiesCached(client)) {
		char cookie_value[EVENTO_NAME_MAX];
		GetClientCookie(client, reward_preference_cookie, cookie_value, sizeof(cookie_value));

		if(StrEqual(cookie_value, "none")) {
			return;
		}

		if(cookie_value[0] != '\0' && !StrEqual(cookie_value, "random")) {
			int desired_evento_idx = get_evento_idx_by_name(cookie_value);
			if(desired_evento_idx != -1) {
				bool winned_desired_evento = winned_eventos[client].FindValue(desired_evento_idx) != -1;
				if(winned_desired_evento) {
					idx = desired_evento_idx;
				}
			}
		}
	}

	give_rewards_ex(client, idx);
}

static int get_evento_idx_by_name(const char[] name)
{
	for(int i = 0; i < evento_infos.Length; i++) {
		EventoInfo eventoinfo;
		evento_infos.GetArray(i, eventoinfo, sizeof(EventoInfo));
		if(StrEqual(eventoinfo.name, name)) {
			return i;
		}
	}

	return -1;
}

static void query_rewards(int client)
{
	int accid = GetSteamAccountID(client);
	char query[QUERY_STR_MAX];
	thedb.Format(query, QUERY_STR_MAX,
		"select evento from last_winners where accountid=%i;"
		,accid
	);

	int usrid = GetClientUserId(client);
	thedb.Query(on_winner_query, query, usrid);
}

static void db_connect(Database db, const char[] error, any data)
{
	if(db == null) {
		return;
	}

	thedb = db;

	thedb.SetCharset("utf8");

	Transaction tr = new Transaction();

	char query[QUERY_STR_MAX];
	thedb.Format(query, sizeof(query),
		"create table if not exists last_winners ( " ...
		" accountid int not null, " ...
		" evento varchar(%i) not null, " ...
		" primary key (accountid,evento) " ...
		");"
		,EVENTO_NAME_MAX
	);
	tr.AddQuery(query);

#if defined DEBUG
	PrintToServer("last_winners table query:");
	PrintToServer("\n%s\n", query);
#endif

	thedb.Format(query, sizeof(query),
		"create table if not exists winners_rank ( " ...
		" accountid int not null, " ...
		" last_name varchar(%i) not null, " ...
		" evento varchar(%i) not null, " ...
		" count int not null, " ...
		" primary key (accountid,evento) " ...
		");"
		,MAX_NAME_LENGTH,
		EVENTO_NAME_MAX
	);
	tr.AddQuery(query);

#if defined DEBUG
	PrintToServer("winners_rank table query:");
	PrintToServer("\n%s\n", query);
#endif

	tr.AddQuery(
		"select * from winners_rank order by count desc;"
	);

	tr.AddQuery(
		"select accountid,evento from last_winners;"
	);

	thedb.Execute(tr, db_connect_query, on_tr_error);

	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i) ||
			!IsPlayerAlive(i) ||
			GetClientTeam(i) < 2) {
			continue;
		}

		give_rewards(i);
	}
}

static int client_of_accid(int accid)
{
	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientConnected(i) ||
			IsFakeClient(i)) {
			continue;
		}

		if(GetSteamAccountID(i) == accid) {
			return i;
		}
	}

	return -1;
}

static int rankglobal_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			rank_menu(param1);
		}
	}

	return 0;
}

static void query_create_rankmenus_impl(Database db, DBResultSet set)
{
	if(set.HasResults) {
		char name[EVENTO_NAME_MAX];
		char plrname[MAX_NAME_LENGTH];

		char query[QUERY_STR_MAX];

		Transaction tr[MAXPLAYERS+1];

	#if defined DEBUG
		PrintToServer("ranks:");
	#endif

		EventoMenus menus;

		StringMap addedmap = new StringMap();
		ArrayList globaladded = new ArrayList(ByteCountToCells(MAX_NAME_LENGTH));

		delete rankglobal;

		rankglobal = new Menu(rankglobal_menu_handler);
		rankglobal.SetTitle("Rank global");
		rankglobal.ExitBackButton = true;

		char display[MAX_NAME_LENGTH+5+INT_STR_MAX];
		char intstr[INT_STR_MAX];

		do {
			do {
				if(!set.FetchRow()) {
					continue;
				}

				int accid = set.FetchInt(0);
				set.FetchString(1, plrname, MAX_NAME_LENGTH);

				int client = client_of_accid(accid);
				if(client != -1) {
					GetClientName(client, plrname, MAX_NAME_LENGTH);

					if(tr[client] == null) {
						tr[client] = new Transaction();
						db.Format(query, QUERY_STR_MAX, 
							"update winners_rank set " ...
							" last_name='%s' " ...
							" where " ...
							" accountid=%i " ...
							";"
							,plrname,
							accid
						);

						tr[client].AddQuery(query);
					}
				}

				set.FetchString(2, name, EVENTO_NAME_MAX);

				int count = set.FetchInt(3);

				if(count >= 5) {
					if(client != -1) {
						if(achiv_rei2 != Achievement_Null) {
							achiv_rei2.AwardProgress(client, 5);
						}
					}
				}

			#if defined DEBUG
				PrintToServer("  %i %s %s %i", accid, plrname, name, count);
			#endif

				ArrayList plrsadded = null;
				if(!addedmap.GetValue(name, plrsadded)) {
					plrsadded = new ArrayList(ByteCountToCells(MAX_NAME_LENGTH));
					eventomenus.GetArray(name, menus, sizeof(EventoMenus));
					menus.ranking = new Menu(evento_rank_menu_handler);
					eventomenus.SetArray(name, menus, sizeof(EventoMenus));
					menus.ranking.SetTitle(name);
					menus.ranking.ExitBackButton = true;
					int idx = -1;
					if(eventoidmap.GetValue(name, idx)) {
						IntToString(idx, intstr, INT_STR_MAX);
						menus.ranking.AddItem(intstr, "", ITEMDRAW_IGNORE);
					}
					addedmap.SetValue(name, plrsadded);
				}

				if(plrsadded.FindString(plrname) == -1) {
					Format(display, sizeof(display), "%s (%i)", plrname, count);
					IntToString(accid, intstr, INT_STR_MAX);
					eventomenus.GetArray(name, menus, sizeof(EventoMenus));
					menus.ranking.AddItem(intstr, display, ITEMDRAW_DISABLED);
					plrsadded.PushString(plrname);
				}

				if(globaladded.FindString(plrname) == -1) {
					Format(display, sizeof(display), "%s (%i)", plrname, count);
					IntToString(accid, intstr, INT_STR_MAX);
					rankglobal.AddItem(intstr, display, ITEMDRAW_DISABLED);
					globaladded.PushString(plrname);
				}
			} while(set.MoreRows);
		} while(set.FetchMoreResults());

		StringMapSnapshot snap = addedmap.Snapshot();
		int len = snap.Length;
		for(int i = 0; i < len; ++i) {
			snap.GetKey(i, name, EVENTO_NAME_MAX);

			ArrayList plrsadded = null;
			addedmap.GetValue(name, plrsadded);

			delete plrsadded;
		}
		delete snap;

		delete addedmap;
		delete globaladded;

		for(int i = 1; i <= MaxClients; ++i) {
			if(tr[i] != null) {
				thedb.Execute(tr[i], INVALID_FUNCTION, on_tr_error);
			}
		}
	}
}

static void db_connect_query(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	query_create_rankmenus_impl(db, results[2]);

	DBResultSet set = results[3];
	if(set.HasResults) {
		char name[EVENTO_NAME_MAX];

		do {
			do {
				if(!set.FetchRow()) {
					continue;
				}

				int accid = set.FetchInt(0);
				int client = client_of_accid(accid);
				if(client == -1) {
					continue;
				}

				set.FetchString(1, name, EVENTO_NAME_MAX);

				if(winned_eventos[client] == null) {
					winned_eventos[client] = new ArrayList();
				}

				int idx = -1;
				if(eventoidmap.GetValue(name, idx)) {
					if(winned_eventos[client].FindValue(idx) == -1) {
						winned_eventos[client].Push(idx);
					}
				}
			} while(set.MoreRows);
		} while(set.FetchMoreResults());
	}
}

static void query_recreate_rankmenus(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	for(int i = 0; i < numQueries; ++i) {
		if(queryData[i] == -1) {
			query_create_rankmenus_impl(db, results[i]);
			break;
		}
	}
}

static int evento_rank_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			char intstr[INT_STR_MAX];
			menu.GetItem(0, intstr, INT_STR_MAX);

			int idx = StringToInt(intstr);

			//rank_menu(param1, -1);
			evento_explain_menu(param1, idx);
		}
	}

	return 0;
}

public void OnMapStart()
{
	laserbeam = PrecacheModel("materials/sprites/laserbeam.vmt");

	PrecacheModel("materials/sprites/minimap_icons/voiceicon.vmt");
	PrecacheModel("materials/sprites/obj_icons/icon_obj_e.vmt");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("eventinho2");
	CreateNative("Eventinho_GetCurrentState", native_get_current_state);
	CreateNative("Eventinho_IsParticipating", native_is_participating);
	CreateNative("Eventinho_IsBhopEnabled", native_is_bhop_enabled);
	return APLRes_Success;
}

public void OnPluginStart()
{
	load_eventos();

	if(SQL_CheckConfig("eventinho2")) {
		Database.Connect(db_connect, "eventinho2");
	}

	reward_preference_cookie = RegClientCookie("eventinho2_reward_preference", "Eventinho reward preference", CookieAccess_Private);

	dummy_item_view = TF2Items_CreateItem(OVERRIDE_ALL|PRESERVE_ATTRIBUTES|FORCE_GENERATION);
	TF2Items_SetClassname(dummy_item_view, "tf_wearable");
	TF2Items_SetQuality(dummy_item_view, 0);
	TF2Items_SetLevel(dummy_item_view, 0);

	RegConsoleCmd("sm_explain", sm_explain);
	RegConsoleCmd("sm_evento", sm_evento);
	RegConsoleCmd("sm_rankevento", sm_rankevento);
	RegConsoleCmd("sm_coroas", sm_coroas);
	RegConsoleCmd("sm_coroa", sm_coroas);

	RegAdminCmd("sm_leventos", sm_leventos, ADMFLAG_ROOT);
	RegAdminCmd("sm_reventos", sm_reventos, ADMFLAG_ROOT);
	RegAdminCmd("sm_split", sm_split, ADMFLAG_ROOT);
	RegAdminCmd("sm_fevento", sm_fevento, ADMFLAG_ROOT);

	RegAdminCmd("sm_mevento", sm_mevento, ADMFLAG_ROOT);

	HookEvent("player_say", player_say);

	HookEvent("player_spawn", player_spawn);
	HookEvent("player_death", player_death);

	HookEvent("player_domination", player_domination);

	HookEvent("post_inventory_application", post_inventory_application);

	AddMultiTargetFilter("@evento", filter_evento, "Todos participando do evento", false);
	AddMultiTargetFilter("@!evento", filter_evento, "Todos não paticipando do evento", false);

	AddMultiTargetFilter("@redevento", filter_evento, "Todos participando do evento", false);
	AddMultiTargetFilter("@!redevento", filter_evento, "Todos não paticipando do evento", false);

	AddMultiTargetFilter("@bluevento", filter_evento, "Todos participando do evento", false);
	AddMultiTargetFilter("@!bluevento", filter_evento, "Todos não paticipando do evento", false);

	for(int i = 1; i <= MaxClients; ++i) {
		if(IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}

	OnAchievementsLoaded();

	mp_friendlyfire = FindConVar("mp_friendlyfire");
	tf_avoidteammates = FindConVar("tf_avoidteammates");

	GameData gamedata = new GameData("eventinho2");
	if(gamedata == null) {
		SetFailState("Gamedata file not found");
		return;
	}

	wants_lag_compensation= DynamicHook.FromConf(gamedata, "CTFPlayer::WantsLagCompensationOnEntity");
	if(wants_lag_compensation == null) {
		SetFailState("Failed to setup hook for CTFPlayer::WantsLagCompensationOnEntity");
	}

	AddCommandListener(cmd_block_for_participants, "autoteam");
	AddCommandListener(cmd_block_for_participants, "spectate");
}

public void OnAllPluginsLoaded()
{
	godmode_loaded = LibraryExists("svb-godmode");
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "svb-godmode")) {
		godmode_loaded = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "svb-godmode")) {
		godmode_loaded = false;
	}
}

static bool filter_evento(const char[] filter, ArrayList clients)
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

	for(int i = 1; i <= MaxClients; i++) {
		if(opposite && participando[i]) {
			continue;
		} else if(!opposite && !participando[i]) {
			continue;
		}

		if(team != TFTeam_Spectator) {
			if(TF2_GetClientTeam(i) != team) {
				continue;
			}
		}

		clients.Push(i);
	}

	return true;
}

static Action cmd_block_for_participants(int client, const char[] command, int argc)
{
	if(is_participating_in_in_progress_event(client)) {
		CPrintToChat(client, EVENTO_CHAT_PREFIX ... "Não é permitido mudar de time durante eventos");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

static void post_inventory_application_frame(int usrid)
{
	int client = GetClientOfUserId(usrid);
	if(client == 0) {
		return;
	}

	give_rewards(client);
}

static void post_inventory_application(Event event, const char[] name, bool dontBroadcast)
{
	RequestFrame(post_inventory_application_frame, event.GetInt("userid"));
}

static void player_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(current_evento_idx != -1) {
		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			if(participando[client]) {
				if(current_config.respawn) {
					int team = GetClientTeam(client);
					if(teleport_set & BIT_FOR_TEAM(team)) {
						TeleportEntity(client, teleport[IDX_FOR_TEAM(team)], teleport_angles[IDX_FOR_TEAM(team)]);
					}
				}
			}
		}
	}

	CreateTimer(1.0, timer_show_participating_hud, GetClientUserId(client));
}

static Action timer_show_participating_hud(Handle timer, int userid) {
	int client = GetClientOfUserId(userid);
	if(client == 0) {
		return Plugin_Handled;
	}
	show_participating_hud(client);
	return Plugin_Handled;
}

static void player_domination(Event event, const char[] name, bool dontBroadcast)
{
	int dominator = GetClientOfUserId(event.GetInt("dominator"));

	if(current_evento_idx != -1) {
		if(current_state == EVENTO_STATE_IN_COUNTDOWN_START ||
			current_state == EVENTO_STATE_ENDED) {

			if(achiv_domin != Achievement_Null) {
				achiv_domin.Award(dominator);
			}
		}
	}
}

static void player_death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(current_evento_idx != -1) {
		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			if(participando[client]) {
				if(!nukealguemorreu) {
					if(StrEqual(current_evento.name, "Nuke")) {
						if(achiv_nuke != Achievement_Null) {
							achiv_nuke.Award(client);
						}
					}
					nukealguemorreu = true;
				}

				if(podesematar) {
					if(!semato[client]) {
						if(achiv_bind != Achievement_Null) {
							achiv_bind.Award(client);
						}
						semato[client] = true;
					}
				}

				morreu[client] = true;

				if(!current_config.respawn) {
					set_participando(client, false, true);
				}
			}
		}
	}
}

public Action TeamManager_CanChangeTeam(int entity, int team)
{
	if(is_participating_in_in_progress_event(entity)) {
		CPrintToChat(entity, EVENTO_CHAT_PREFIX ... "Não é permitido mudar de time durante eventos");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action TeamManager_CanDamage(int entity, int other)
{
	if(!is_player(entity) || !is_player(other)) {
		return Plugin_Continue;
	}

	if(current_state != EVENTO_STATE_IN_PROGRESS && current_state != EVENTO_STATE_IN_COUNTDOWN_END) {
		return Plugin_Continue;
	}

	if(!participando[entity]) {
		return Plugin_Continue;
	}

	if(!current_config.friendly_fire) {
		return Plugin_Continue;
	}

	return Plugin_Changed;
}

public Action SVB_OnRandomCrit(int client, int weapon)
{
	if(current_evento_idx == -1) {
		return Plugin_Continue;
	}

	if(current_state != EVENTO_STATE_IN_PROGRESS &&
		current_state != EVENTO_STATE_IN_COUNTDOWN_END) {
		return Plugin_Continue;
	}

	if(!participando[client]) {
		return Plugin_Continue;
	}

	if(current_config.random_crits) {
		return Plugin_Continue;
	}

	return Plugin_Stop;
}

public Action TF2WeaponsAPI_OnPlayerRemoveAmmo(int client, int& count, TFAmmoType& ammoType)
{
	if(current_evento_idx == -1) {
		return Plugin_Continue;
	}

	if(current_state != EVENTO_STATE_IN_PROGRESS && current_state != EVENTO_STATE_IN_COUNTDOWN_END) {
		return Plugin_Continue;
	}

	if(!participando[client]) {
		return Plugin_Continue;
	}

	if(ammoType == TF_AMMO_METAL) {
		if(current_config.infinite_metal) {
			return Plugin_Stop;
		} else {
			return Plugin_Continue;
		}
	}

	if(current_config.infinite_ammo) {
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

static bool is_class_valid(EventoInfo eventoinfo, int class)
{
	bool valid = true;

	if(eventoinfo.classes > 0) {
		if(eventoinfo.classes_is_whitelist) {
			if(!(eventoinfo.classes & BIT_FOR_CLASS(class))) {
				valid = false;
			}
		} else {
			if(eventoinfo.classes & BIT_FOR_CLASS(class)) {
				valid = false;
			}
		}
	}

	return valid;
}

public Action TeamManager_CanChangeClass(int entity, int class)
{
	if(current_evento_idx != -1) {
		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			if(participando[entity]) {
				if(!is_class_valid(current_evento, class)) {
					char class_name[32];
					if(class_to_classname(view_as<TFClassType>(class), class_name, sizeof(class_name))) {
						CPrintToChat(entity, EVENTO_CHAT_PREFIX ... "Não é permitido %s no evento %s", class_name, current_evento.name);
					}
					return Plugin_Handled;
				}
			}
		}
	}
	return Plugin_Continue;
}

bool class_to_classname(TFClassType type, char[] name, int length)
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

static Action sm_evento(int client, int args)
{
	if(client == 0) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Não é possível executar esse comando pelo console");
		return Plugin_Handled;
	}

	if(current_evento_idx == -1) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Não há nenhum evento no momento");
		return Plugin_Handled;
	}

	if(current_state == EVENTO_STATE_IN_PROGRESS ||
		current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Não é possivel participar de um evento em progresso");
		return Plugin_Handled;
	}

	set_participando_ex(client, !participando[client], current_evento);

	if(participando[client]) {
		evento_explain_menu(client, current_evento_idx);

		if(evento_secs == -1) {
			CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Você está participando do evento %s", current_evento.name);
			CPrintToChatAll(EVENTO_CHAT_PREFIX ... "%N está participando do evento %s. Digite !evento para participar também!", client, current_evento.name);
		} else {
			CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Você irá participar do evento %s", current_evento.name);
			CPrintToChatAll(EVENTO_CHAT_PREFIX ... "%N vai participar do evento %s. Digite !evento para participar também!", client, current_evento.name);
		}
	} else {
		if(evento_secs == -1) {
			CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Você não está mais participando do evento %s", current_evento.name);
		} else {
			CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Você não vai mais participar do evento %s", current_evento.name);
		}
	}

	show_participating_hud(client);

	return Plugin_Handled;
}

void client_post_think_post(int client)
{
	if(playersprite[client] != INVALID_ENT_REFERENCE) {
		int entity = EntRefToEntIndex(playersprite[client]);

		float pos[3];
		GetClientAbsOrigin(client, pos);
		
		float hullmax[3];
		GetEntPropVector(client, Prop_Send, "m_vecMaxs", hullmax);
		
		pos[2] += hullmax[2];
		pos[2] += 20.0;
		
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
	}
}

public void OnClientPutInServer(int client)
{
	if(thedb != null) {
		if(!IsFakeClient(client)) {
			query_rewards(client);
		}
	}

	SDKHook(client, SDKHook_PostThinkPost, client_post_think_post);
	SDKHook(client, SDKHook_OnTakeDamage, client_takedamage);
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, client_takedamage_post);
	SDKHook(client, SDKHook_WeaponSwitch, client_weapon_switch);
	SDKHook(client, SDKHook_ShouldCollide, client_should_collide);
}

Action client_takedamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int custom)
{
	if(current_evento_idx == -1) {
		return Plugin_Continue;
	}

	if(current_state != EVENTO_STATE_IN_PROGRESS &&
		current_state != EVENTO_STATE_IN_COUNTDOWN_END) {
		return Plugin_Continue;
	}

	if(!is_player(victim) || !is_player(attacker)) {
		return Plugin_Continue;
	}

	if(current_config.damage) {
		return Plugin_Continue;
	}

	if(participando[victim] || participando[attacker]) {
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

bool is_player(int entity)
{
	return entity > 0 && entity <= MaxClients;
}

bool is_participating_in_in_progress_event(int client)
{
	if(current_evento_idx == -1) {
		return false;
	}

	if(current_state != EVENTO_STATE_IN_PROGRESS && current_state != EVENTO_STATE_IN_COUNTDOWN_END) {
		return false;
	}

	if(!participando[client]) {
		return false;
	}

	return true;
}

void client_takedamage_post(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if(attacker < 1 || attacker > MaxClients) {
		return;
	}

	/*if(damage == 666.0) {
		if(current_evento_idx != -1) {
			if(current_state == EVENTO_STATE_IN_PROGRESS ||
				current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
				if(participando[attacker]) {
					EventoInfo eventoinfo;
					evento_infos.GetArray(current_evento_idx, eventoinfo, sizeof(EventoInfo));

					if(achiv_hhh != Achievement_Null) {
						achiv_hhh.Award(attacker);
					}
				}
			}
		}
	}*/
}

Action client_weapon_switch(int client, int weapon)
{
	if(!IsValidEntity(weapon)) {
		return Plugin_Continue;
	}

	if(current_evento_idx == -1) {
		return Plugin_Continue;
	}

	if(current_state != EVENTO_STATE_IN_PROGRESS && current_state != EVENTO_STATE_IN_COUNTDOWN_END) {
		return Plugin_Continue;
	}

	if(!participando[client]) {
		return Plugin_Continue;
	}

	if(!current_config.melee) {
		return Plugin_Continue;
	}

	int new_weapon_slot = TF2Util_GetWeaponSlot(weapon);
	if(new_weapon_slot != TFWeaponSlot_Melee) {
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

bool client_should_collide(int entity, int collisiongroup, int contentmask, bool originalresult) {
	if(!is_player(entity)) {
		return originalresult;
	}

	if(!is_participating_in_in_progress_event(entity)) {
		return originalresult;
	}

	if(!current_config.friendly_fire) {
		return originalresult;
	}

	if(collisiongroup != COLLISION_GROUP_PLAYER_MOVEMENT) {
		return originalresult;
	}

	switch(TF2_GetClientTeam(entity)) {
		case TFTeam_Red: {
			if(!(contentmask & CONTENTS_REDTEAM)) {
				return true;
			}
		}
		case TFTeam_Blue: {
			if(!(contentmask & CONTENTS_BLUETEAM)) {
				return true;
			}
		}
	}
	
	return originalresult;
}

MRESReturn dhook_wants_lag_compensation_on_entity(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	if(!is_participating_in_in_progress_event(pThis)) {
		return MRES_Ignored;
	}

	if(!current_config.friendly_fire) {
		return MRES_Ignored;
	}

	int other_player = hParams.Get(1);
	if(!is_participating_in_in_progress_event(other_player)) {
		return MRES_Ignored;
	}

	if(TF2_GetClientTeam(pThis) != TF2_GetClientTeam(other_player)) {
		return MRES_Ignored;
	}

	hReturn.Value = true;
	return MRES_Supercede;
}

static bool handle_time(int &secs, int num, char timestr[TIME_STR_MAX], const char[] singular, const char[] plural)
{
	if(secs >= num) {
		int hours = (secs / num);
		char intstr[INT_STR_MAX];
		IntToString(hours, intstr, INT_STR_MAX);
		StrCat(timestr, TIME_STR_MAX, intstr);
		if(hours == 1) {
			StrCat(timestr, TIME_STR_MAX, singular);
		} else {
			StrCat(timestr, TIME_STR_MAX, plural);
		}
		int remainder = (secs % num);
		secs = remainder;
		return true;
	} else {
		return false;
	}
}

static int parse_time_string(const char[] str)
{
	int ret = 0;
	if(strcmp(str, "-1") == 0) {
		ret = -1;
	} else {
		char timesstr[7][INT_STR_MAX];
		int num = ExplodeString(str, ":", timesstr, 7, INT_STR_MAX);
		switch(num) {
			case 1: {
				ret += StringToInt(timesstr[0]);
			}
			case 2: {
				ret += StringToInt(timesstr[1]);
				ret += (StringToInt(timesstr[0]) * 60);
			}
			case 3: {
				ret += StringToInt(timesstr[2]);
				ret += (StringToInt(timesstr[1]) * 60);
				ret += (StringToInt(timesstr[0]) * 3600);
			}
			default: {
				ret = -1;
			}
		}
	}
	return ret;
}

static void format_seconds(int secs, char timestr[TIME_STR_MAX])
{
	do {
		if(handle_time(secs, 31557600, timestr, " ano ", " anos ")) {
		} else if(handle_time(secs, 2629800, timestr, " mes ", " meses ")) {
		} else if(handle_time(secs, 604800, timestr, " semana ", " semanas ")) {
		} else if(handle_time(secs, 86400, timestr, " dia ", " dias ")) {
		} else if(handle_time(secs, 3600, timestr, " hora ", " horas ")) {
		} else if(handle_time(secs, 60, timestr, " minuto ", " minutos ")) {
		} else {
			char intstr[INT_STR_MAX];
			IntToString(secs, intstr, INT_STR_MAX);
			StrCat(timestr, TIME_STR_MAX, intstr);
			if(secs == 1) {
				StrCat(timestr, TIME_STR_MAX, " segundo ");
			} else {
				StrCat(timestr, TIME_STR_MAX, " segundos ");
			}
			secs = 0;
		}
	} while(secs > 0);
}

public void OnPluginEnd()
{
	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i)) {
			continue;
		}

		delete_reward_ents(i);
	}
	
	if(current_state != EVENTO_STATE_ENDED) {
		cancel_evento();
	}
}

public void OnClientDisconnect(int client)
{
	if(client == usando_menu) {
		usando_menu = -1;
	}
	if(client == chat_listen.client) {
		chat_listen.client = -1;
	}

	if(playersprite[client] != INVALID_ENT_REFERENCE) {
		int entity = EntRefToEntIndex(playersprite[client]);
		RemoveEntity(entity);
	}
	playersprite[client] = INVALID_ENT_REFERENCE;

	delete_reward_ents(client);
	delete winned_eventos[client];
	participando[client] = false;
	vencedor[client] = false;

	morreu[client] = false;
	semato[client] = false;
	wants_lag_compensation_hook_id[client] = INVALID_HOOK_ID;
}

static int classes_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			char intstr[INT_STR_MAX];
			menu.GetItem(0, intstr, INT_STR_MAX);

			int idx = StringToInt(intstr);

			evento_explain_menu(param1, idx);
		}
	}

	return 0;
}

static Menu create_classes_menu(EventoInfo eventoinfo, int idx)
{
	Menu menu = new Menu(classes_menu_handler);
	if(eventoinfo.classes_is_whitelist) {
		menu.SetTitle("permitidas");
	} else {
		menu.SetTitle("bloqueadas");
	}
	menu.ExitBackButton = true;

	char intstr[INT_STR_MAX];
	IntToString(idx, intstr, INT_STR_MAX);
	menu.AddItem(intstr, "", ITEMDRAW_IGNORE);

	if(eventoinfo.classes & BIT_FOR_CLASS(TFClass_Scout)) {
		menu.AddItem("", "scout", ITEMDRAW_DISABLED);
	}
	if(eventoinfo.classes & BIT_FOR_CLASS(TFClass_Sniper)) {
		menu.AddItem("", "sniper", ITEMDRAW_DISABLED);
	}
	if(eventoinfo.classes & BIT_FOR_CLASS(TFClass_Soldier)) {
		menu.AddItem("", "soldier", ITEMDRAW_DISABLED);
	}
	if(eventoinfo.classes & BIT_FOR_CLASS(TFClass_DemoMan)) {
		menu.AddItem("", "demoman", ITEMDRAW_DISABLED);
	}
	if(eventoinfo.classes & BIT_FOR_CLASS(TFClass_Medic)) {
		menu.AddItem("", "medic", ITEMDRAW_DISABLED);
	}
	if(eventoinfo.classes & BIT_FOR_CLASS(TFClass_Heavy)) {
		menu.AddItem("", "heavy", ITEMDRAW_DISABLED);
	}
	if(eventoinfo.classes & BIT_FOR_CLASS(TFClass_Pyro)) {
		menu.AddItem("", "pyro", ITEMDRAW_DISABLED);
	}
	if(eventoinfo.classes & BIT_FOR_CLASS(TFClass_Spy)) {
		menu.AddItem("", "spy", ITEMDRAW_DISABLED);
	}
	if(eventoinfo.classes & BIT_FOR_CLASS(TFClass_Engineer)) {
		menu.AddItem("", "engineer", ITEMDRAW_DISABLED);
	}
	return menu;
}

static void display_classes_menu(int client, int idx)
{
	EventoInfo eventoinfo;
	evento_infos.GetArray(idx, eventoinfo, sizeof(EventoInfo));

	EventoMenus menus;

	if(eventomenus.GetArray(eventoinfo.name, menus, sizeof(EventoMenus))) {
		if(menus.classes != null) {
			menus.classes.Display(client, MENU_TIME_FOREVER);
		}
	}
}

static void display_ranking_menu(int client, int idx)
{
	EventoInfo eventoinfo;
	evento_infos.GetArray(idx, eventoinfo, sizeof(EventoInfo));

	EventoMenus menus;

	if(eventomenus.GetArray(eventoinfo.name, menus, sizeof(EventoMenus))) {
		if(menus.ranking != null) {
			menus.ranking.Display(client, MENU_TIME_FOREVER);
		}
	}
}

static int evento_explain_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		char intstr[INT_STR_MAX];
		menu.GetItem(0, intstr, INT_STR_MAX);
		int idx = StringToInt(intstr);

		menu.GetItem(param2, intstr, INT_STR_MAX);
		param2 = StringToInt(intstr);

		switch(param2) {
			case 0: {
				display_classes_menu(param1, idx);
			}
			case 1: {
				display_ranking_menu(param1, idx);
			}
		}
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			explain_menu(param1);
		}
	}

	return 0;
}

static Menu create_explain_menu(EventoInfo eventoinfo, int idx)
{
	Menu menu = new Menu(evento_explain_menu_handler);
	menu.SetTitle(eventoinfo.name);
	menu.ExitBackButton = true;

	char intstr[INT_STR_MAX];
	IntToString(idx, intstr, INT_STR_MAX);
	menu.AddItem(intstr, "", ITEMDRAW_IGNORE);

	menu.AddItem("1", "ranking");

	if(eventoinfo.classes > 0) {
		menu.AddItem("0", "classes");
		menu.AddItem("", "", ITEMDRAW_SPACER);
	}

	char explainstr[EVENTO_EXPLAIN_MAX];

	int len = eventoinfo.explains.Length;
	for(int i = 0; i < len; ++i) {
		eventoinfo.explains.GetString(i, explainstr, EVENTO_EXPLAIN_MAX);

		menu.AddItem("", explainstr, ITEMDRAW_DISABLED);
	}

	return menu;
}

static void evento_explain_menu(int client, int idx)
{
	EventoInfo eventoinfo;
	evento_infos.GetArray(idx, eventoinfo, sizeof(EventoInfo));

	EventoMenus menus;

	if(eventomenus.GetArray(eventoinfo.name, menus, sizeof(EventoMenus))) {
		if(menus.explain != null) {
			menus.explain.Display(client, MENU_TIME_FOREVER);
		}
	}
}

static int rank_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		char intstr[INT_STR_MAX];
		menu.GetItem(param2, intstr, INT_STR_MAX);
		int idx = StringToInt(intstr);

		if(idx == -1) {
			rankglobal.Display(param1, MENU_TIME_FOREVER);
		} else {
			display_ranking_menu(param1, idx);
		}
	}

	return 0;
}

static int explain_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		char intstr[INT_STR_MAX];
		menu.GetItem(param2, intstr, INT_STR_MAX);
		int idx = StringToInt(intstr);

		evento_explain_menu(param1, idx);
	}

	return 0;
}

static void explain_menu(int client)
{
	explainmenu.Display(client, MENU_TIME_FOREVER);
}

static void rank_menu(int client)
{
	rankmenu.Display(client, MENU_TIME_FOREVER);
}

static Action sm_rankevento(int client, int args)
{
	if(evento_infos == null) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Não existe nenhum evento registrado");
		return Plugin_Handled;
	}

	if(current_evento_idx == -1) {
		rank_menu(client);
	} else {
		display_ranking_menu(client, current_evento_idx);
	}

	return Plugin_Handled;
}

static Action sm_explain(int client, int args)
{
	if(evento_infos == null) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Não existe nenhum evento registrado");
		return Plugin_Handled;
	}

	if(client == 0) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Não é possível executar esse comando pelo console");
		return Plugin_Handled;
	}

	if(current_evento_idx == -1) {
		explain_menu(client);
	} else {
		evento_explain_menu(client, current_evento_idx);
	}

	return Plugin_Handled;
}

static Action sm_coroas(int client, int args)
{
	if(!AreClientCookiesCached(client) || winned_eventos[client] == null) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Seus dados ainda não foram carregadas, tente novamente mais tarde");
		return Plugin_Handled;
	}

	display_coroas_menu(client);
	return Plugin_Handled;
}

void display_coroas_menu(int client)
{
	Menu menu = new Menu(coroas_menu_handler);
	menu.SetTitle("Coroas de evento");

	char cookie_value[EVENTO_NAME_MAX];
	GetClientCookie(client, reward_preference_cookie, cookie_value, sizeof(cookie_value));

	int item_style = ITEMDRAW_DEFAULT;
	if(StrEqual(cookie_value, "none")) {
		item_style = ITEMDRAW_DISABLED;
	}
	menu.AddItem("none", "Remover", item_style);

	item_style = ITEMDRAW_DEFAULT;
	if(cookie_value[0] == '\0' || StrEqual(cookie_value, "random")) {
		item_style = ITEMDRAW_DISABLED;
	}
	menu.AddItem("random", "Aleatória", item_style);

	int len = winned_eventos[client].Length;

	for(int i = 0; i < len; i++) {
		int evento_idx = winned_eventos[client].Get(i);
		EventoInfo eventoinfo;
		evento_infos.GetArray(evento_idx, eventoinfo, sizeof(eventoinfo));

		item_style = ITEMDRAW_DEFAULT;
		if(StrEqual(cookie_value, eventoinfo.name)) {
			item_style = ITEMDRAW_DISABLED;
		}

		menu.AddItem(eventoinfo.name, eventoinfo.name, item_style);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

static int coroas_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		char info[EVENTO_NAME_MAX];
		menu.GetItem(param2, info, sizeof(info));
		SetClientCookie(param1, reward_preference_cookie, info);
		give_rewards(param1);
		display_coroas_menu(param1);
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

static void set_participando_ex(int client, bool value, EventoInfo info, bool death = false)
{
	if(!value) {
		vencedor[client] = false;

		if(playersprite[client] != INVALID_ENT_REFERENCE) {
			int entity = EntRefToEntIndex(playersprite[client]);
			RemoveEntity(entity);
			playersprite[client] = INVALID_ENT_REFERENCE;
		}
	}

	bool tava_participando = participando[client];
	bool is_event_in_progress = current_state == EVENTO_STATE_IN_PROGRESS ||
		current_state == EVENTO_STATE_IN_COUNTDOWN_END;

	participando[client] = value;
	
	if(value && playersprite[client] == INVALID_ENT_REFERENCE) {
		int entity = CreateEntityByName("env_sprite_oriented");
		DispatchKeyValue(entity, "framerate", "10.0");
		DispatchKeyValue(entity, "scale", "");
		DispatchKeyValue(entity, "model", "materials/sprites/minimap_icons/voiceicon.vmt");
		DispatchKeyValue(entity, "spawnflags", "1");
		DispatchKeyValueFloat(entity, "GlowProxySize", 2.0);
		DispatchKeyValueFloat(entity, "HDRColorScale", 1.0);
		DispatchSpawn(entity);
		ActivateEntity(entity);
		
		AcceptEntityInput(entity, "ShowSprite");
		
		SetEntityRenderColor(entity, 255, 0, 0, 255);
		
		SetEdictFlags(entity, GetEdictFlags(entity) ^ FL_EDICT_ALWAYS)
		
		SDKHook(entity, SDKHook_SetTransmit, sprite_set_transmit);

		playersprite[client] = EntIndexToEntRef(entity);
	}

	if(!death) {
		if(is_event_in_progress) {
			if(value) {
				handle_player(client, info);
			}
		}
	}

	if(!value && tava_participando && is_event_in_progress) {
		// move the player to the team that has less players
		int blue_count = 0;
		int red_count = 0;
		for(int i = 1; i <= MaxClients; i++) {
			if(!IsClientInGame(i) || participando[i]) {
				continue;
			}
			TFTeam team = TF2_GetClientTeam(i);
			if(team == TFTeam_Red) {
				red_count++;
			} else if(team == TFTeam_Blue) {
				blue_count++;
			}
		}
		if(red_count < blue_count) {
			set_client_team(client, TFTeam_Red);
		} else {
			set_client_team(client, TFTeam_Blue);
		}

		TF2_RespawnPlayer(client);
	}

	show_participating_hud(client);
	handle_melee(client);
	handle_friendlyfire(client);
}

static void set_participando(int client, bool value, bool death = false)
{
	set_participando_ex(client, value, current_evento, death);
}

static Action sprite_set_transmit(int entity, int client)
{
	if(current_config.show_sprite) {
		return Plugin_Continue;
	}

	return Plugin_Handled;
}

static void end_evento_with_player(int client)
{
	for(int i = 1; i <= MaxClients; ++i) {
		vencedor[i] = false;
	}

	vencedor[client] = true;
	end_evento();
}

static int player_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		char intstr[INT_STR_MAX];
		menu.GetItem(1, intstr, INT_STR_MAX);
		int idx = StringToInt(intstr);

		menu.GetItem(0, intstr, INT_STR_MAX);
		int player = StringToInt(intstr);
		player = GetClientOfUserId(player);
		if(player == 0) {
			CPrintToChat(param1, EVENTO_CHAT_PREFIX ... "O jogador se desconectou");
			players_menu(param1, idx, true);
			return 0;
		}

		menu.GetItem(param2, intstr, INT_STR_MAX);
		param2 = StringToInt(intstr);

		switch(param2) {
			case 0:
			{ set_participando(player, false); }
			case 1:
			{ vencedor[player] = !vencedor[player]; }
			case 2: {
				end_evento_with_player(player);
				return 0;
			}
			case 3: {
				set_player_event_team_if_needed(player);
				set_participando(player, true); 
			}
		}

		players_menu(param1, idx, true);
	} else if(action == MenuAction_DisplayItem) {
		if(param2 == 0 || param2 == 1) {
			return RedrawMenuItem("");
		}

		char intstr[INT_STR_MAX];
		menu.GetItem(0, intstr, INT_STR_MAX);
		int player = StringToInt(intstr);
		player = GetClientOfUserId(player);
		if(player == 0) {
			int idx = StringToInt(intstr);
			CPrintToChat(param1, EVENTO_CHAT_PREFIX ... "O jogador se desconectou");
			players_menu(param1, idx, true);
			return 0;
		}

		menu.GetItem(param2, intstr, INT_STR_MAX);
		param2 = StringToInt(intstr);
		
		switch(param2) {
			case 0:
			{ return RedrawMenuItem("remover"); }
			case 1: {
				if(vencedor[player]) {
					return RedrawMenuItem("desmarcar como vencedor");
				} else {
					return RedrawMenuItem("marcar como vencedor");
				}
			}
			case 2:
			{ return RedrawMenuItem("terminar com ele"); }
			case 3:
			{ return RedrawMenuItem("adicionar"); }
		}
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			char intstr[INT_STR_MAX];
			menu.GetItem(1, intstr, INT_STR_MAX);
			int idx = StringToInt(intstr);

			players_menu(param1, idx, true);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

static void player_menu(int client, int player, int idx)
{
	char plrname[MAX_NAME_LENGTH];
	GetClientName(player, plrname, MAX_NAME_LENGTH);

	Menu menu = new Menu(player_menu_handler, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);
	menu.SetTitle(plrname);
	menu.ExitBackButton = true;

	char intstr[INT_STR_MAX];
	IntToString(GetClientUserId(player), intstr, INT_STR_MAX);
	menu.AddItem(intstr, "", ITEMDRAW_IGNORE);

	IntToString(idx, intstr, INT_STR_MAX);
	menu.AddItem(intstr, "", ITEMDRAW_IGNORE);

	if(participando[player]) {
		menu.AddItem("0", "remover");
		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			menu.AddItem("1", "marcar como vencedor");
			menu.AddItem("2", "terminar com ele");
		}
	} else {
		menu.AddItem("3", "adicionar");
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

static int players_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		char intstr[INT_STR_MAX];
		menu.GetItem(0, intstr, INT_STR_MAX);
		int idx = StringToInt(intstr);

		menu.GetItem(param2, intstr, INT_STR_MAX);

		if(intstr[0] == 'm') {
			for(int i = 1; i <= MaxClients; ++i) {
				if(!IsClientInGame(i) ||
					!participando[i]) {
					continue;
				}

				vencedor[i] = true;
			}

			evento_menu(param1, idx);
			return 0;
		}

		param2 = StringToInt(intstr);
		param2 = GetClientOfUserId(param2);

		if(param2 == 0) {
			CPrintToChat(param1, EVENTO_CHAT_PREFIX ... "O jogador se desconectou");
			char title[15];
			menu.GetTitle(title, sizeof(title));
			bool parti = (StrEqual(title, "Particicpantes"));
			players_menu(param1, idx, parti);
		} else {
			player_menu(param1, param2, idx);
		}
	} else if(action == MenuAction_DrawItem) {
		if(param2 == 0) {
			return ITEMDRAW_IGNORE;
		}

		char intstr[INT_STR_MAX];
		menu.GetItem(param2, intstr, INT_STR_MAX);

		switch(intstr[0]) {
			case 'i':
			{ return ITEMDRAW_IGNORE; }
			case 's':
			{ return ITEMDRAW_SPACER; }
			case 'm':
			{ return ITEMDRAW_DEFAULT; }
			case 'n':
			{ return ITEMDRAW_DISABLED; }
		}

		param2 = StringToInt(intstr);
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

		char intstr[INT_STR_MAX];
		menu.GetItem(param2, intstr, INT_STR_MAX);

		switch(intstr[0]) {
			case 'i', 's':
			{ return RedrawMenuItem(""); }
			case 'm':
			{ return RedrawMenuItem("marcar todos como vencedores"); }
			case 'n':
			{ return RedrawMenuItem("<<nenhum jogador>>"); }
		}

		param2 = StringToInt(intstr);
		param2 = GetClientOfUserId(param2);

		if(param2 == 0) {
			return RedrawMenuItem("disconnected");
		} else {
			char plrname[MAX_NAME_LENGTH];
			GetClientName(param2, plrname, MAX_NAME_LENGTH);
			return RedrawMenuItem(plrname);
		}
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			char intstr[INT_STR_MAX];
			menu.GetItem(0, intstr, INT_STR_MAX);
			int idx = StringToInt(intstr);

			evento_menu(param1, idx);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

static void players_menu(int client, int idx, bool parti)
{
	Menu menu = new Menu(players_menu_handler, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem|MenuAction_DrawItem);
	if(parti) {
		menu.SetTitle("Particicpantes");
	} else {
		menu.SetTitle("Nao particicpantes");
	}
	menu.ExitBackButton = true;

	char intstr[INT_STR_MAX];
	IntToString(idx, intstr, INT_STR_MAX);
	menu.AddItem(intstr, "i", ITEMDRAW_IGNORE);

	if(parti) {
		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			menu.AddItem("m", "marcar todos como vencedores");
			menu.AddItem("s", "", ITEMDRAW_SPACER);
		}
	}

	int num_added = 0;

	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i)) {
			continue;
		}

		if(parti && !participando[i]) {
			continue;
		} else if(!parti && participando[i]) {
			continue;
		}

		IntToString(GetClientUserId(i), intstr, INT_STR_MAX);
		menu.AddItem(intstr, "player");
		++num_added;
	}

	if(num_added == 0) {
		menu.AddItem("n", "<<nenhum jogador>>", ITEMDRAW_DISABLED);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

static int winner_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		char intstr[INT_STR_MAX];
		menu.GetItem(1, intstr, INT_STR_MAX);
		int idx = StringToInt(intstr);

		menu.GetItem(0, intstr, INT_STR_MAX);
		int player = StringToInt(intstr);
		player = GetClientOfUserId(player);
		if(player == 0) {
			CPrintToChat(param1, EVENTO_CHAT_PREFIX ... "O jogador se desconectou");
			winners_menu(param1, idx);
			return 0;
		}

		if(param2 == 2) {
			vencedor[player] = false;
		}

		winners_menu(param1, idx);
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			char intstr[INT_STR_MAX];
			menu.GetItem(1, intstr, INT_STR_MAX);
			int idx = StringToInt(intstr);

			winners_menu(param1, idx);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

static void winner_menu(int client, int player, int idx)
{
	char plrname[MAX_NAME_LENGTH];
	GetClientName(player, plrname, MAX_NAME_LENGTH);

	Menu menu = new Menu(winner_menu_handler);
	menu.SetTitle(plrname);
	menu.ExitBackButton = true;

	char intstr[INT_STR_MAX];
	IntToString(GetClientUserId(player), intstr, INT_STR_MAX);
	menu.AddItem(intstr, "", ITEMDRAW_IGNORE);

	IntToString(idx, intstr, INT_STR_MAX);
	menu.AddItem(intstr, "", ITEMDRAW_IGNORE);

	menu.AddItem("0", "remover");

	menu.Display(client, MENU_TIME_FOREVER);
}

static int winners_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		char intstr[INT_STR_MAX];
		menu.GetItem(0, intstr, INT_STR_MAX);
		int idx = StringToInt(intstr);

		if(param2 == 1) {
			end_evento();
			return 0;
		}

		menu.GetItem(param2, intstr, INT_STR_MAX);
		param2 = StringToInt(intstr);
		param2 = GetClientOfUserId(param2);

		if(param2 == 0) {
			CPrintToChat(param1, EVENTO_CHAT_PREFIX ... "O jogador se desconectou");
			winners_menu(param1, idx);
		} else {
			winner_menu(param1, param2, idx);
		}
	} else if(action == MenuAction_DrawItem) {
		if(param2 == 0) {
			return ITEMDRAW_IGNORE;
		}

		char intstr[INT_STR_MAX];
		menu.GetItem(param2, intstr, INT_STR_MAX);

		switch(intstr[0]) {
			case 's':
			{ return ITEMDRAW_SPACER; }
			case 't':
			{ return ITEMDRAW_DEFAULT; }
			case 'n':
			{ return ITEMDRAW_DISABLED; }
		}

		param2 = StringToInt(intstr);
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

		char intstr[INT_STR_MAX];
		menu.GetItem(param2, intstr, INT_STR_MAX);

		switch(intstr[0]) {
			case 't':
			{ return RedrawMenuItem("terminar"); }
			case 'n':
			{ return RedrawMenuItem("<<nenhum jogador>>"); }
			case 's':
			{ return RedrawMenuItem(""); }
		}

		param2 = StringToInt(intstr);
		param2 = GetClientOfUserId(param2);

		if(param2 == 0) {
			return RedrawMenuItem("disconnected");
		} else {
			char plrname[MAX_NAME_LENGTH];
			GetClientName(param2, plrname, MAX_NAME_LENGTH);
			return RedrawMenuItem(plrname);
		}
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			char intstr[INT_STR_MAX];
			menu.GetItem(0, intstr, INT_STR_MAX);
			int idx = StringToInt(intstr);

			evento_menu(param1, idx);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

static void winners_menu(int client, int idx)
{
	Menu menu = new Menu(winners_menu_handler, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem|MenuAction_DrawItem);
	menu.SetTitle("Marcados para vencer");
	menu.ExitBackButton = true;

	char intstr[INT_STR_MAX];
	IntToString(idx, intstr, INT_STR_MAX);
	menu.AddItem(intstr, "", ITEMDRAW_IGNORE);

	menu.AddItem("t", "terminar");
	menu.AddItem("s", "", ITEMDRAW_SPACER);

	int num_added = 0;

	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i) ||
			!vencedor[i]) {
			continue;
		}

		IntToString(GetClientUserId(i), intstr, INT_STR_MAX);
		menu.AddItem(intstr, "player");
		++num_added;
	}

	if(num_added == 0) {
		menu.AddItem("n", "<<nenhum jogador>>", ITEMDRAW_DISABLED);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

static void stop_countdown()
{
	if(evento_secs != -1) {
		evento_secs = 0;
	}
	delete countdown_handle;
	if(hud) {
		for(int i = 1; i <= MaxClients; ++i) {
			if(!IsClientInGame(i) ||
				IsFakeClient(i)) {
				continue;
			}
			ClearSyncHud(i, hud);
			ClearSyncHud(i, hud_participating);
		}
	}
	delete hud;
	delete hud_participating;
}

static void start_countdown(int secs)
{
	hud = CreateHudSynchronizer();
	evento_secs = secs;
	if(!countdown_tick()) {
		countdown_handle = CreateTimer(1.0, timer_countdown, 0, TIMER_REPEAT);
	}
	hud_participating = CreateHudSynchronizer();
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			show_participating_hud(i);
		}
	}
}

static void clear_evento_vars()
{
	for(int i = 1; i <= MaxClients; ++i) {
		semato[i] = false;
		morreu[i] = false;

		if(!IsClientInGame(i)) {
			continue;
		}

		set_participando(i, false);
	}

	nukealguemorreu = false;

	delete timerpodesematar;
	podesematar = true;

	delete timer20seg;

	evento_secs = 0;
	stop_countdown();

	current_evento_idx = -1;
	current_state = EVENTO_STATE_ENDED;

	teleport[0][0] = 0.0;
	teleport[0][1] = 0.0;
	teleport[0][2] = 0.0;

	teleport[1][0] = 0.0;
	teleport[1][1] = 0.0;
	teleport[1][2] = 0.0;

	teleport_set = 0;
}

static void cancel_evento()
{
	clear_evento_vars();

	CPrintToChatAll(EVENTO_CHAT_PREFIX ... "Evento cancelado");
}

static void end_evento()
{
	EventoInfo eventoinfo;
	evento_infos.GetArray(current_evento_idx, eventoinfo, sizeof(EventoInfo));

	if(eventoinfo.cmds[1] != null) {
		char cmdstr[CMD_STR_MAX];

		int len = eventoinfo.cmds[1].Length;
		for(int i = 0; i < len; ++i) {
			eventoinfo.cmds[1].GetString(i, cmdstr, CMD_STR_MAX);
			ServerCommand("%s", cmdstr);
		}
	}

	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i)) {
			continue;
		}

		if(winned_eventos[i] != null) {
			int idx = winned_eventos[i].FindValue(current_evento_idx);
			if(idx != -1) {
				delete_reward_ents(i);
				winned_eventos[i].Erase(idx);
				give_rewards(i);
			}
		}
	}

	char query[QUERY_STR_MAX];
	Transaction tr;
	if(thedb != null) {
		thedb.Format(query, QUERY_STR_MAX, 
			"delete from last_winners where evento='%s';"
			,eventoinfo.name
		);
		thedb.Query(on_query_error, query);

		tr = new Transaction();
	}

	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i) ||
			!vencedor[i]) {
			continue;
		}

		if(winned_eventos[i] == null) {
			winned_eventos[i] = new ArrayList();
		}

		int idx = winned_eventos[i].FindValue(current_evento_idx);
		if(idx == -1) {
			winned_eventos[i].Push(current_evento_idx);

			if(thedb != null && !IsFakeClient(i)) {
				int accid = GetSteamAccountID(i);
				thedb.Format(query, QUERY_STR_MAX, 
					"insert into last_winners " ...
					" (accountid,evento) " ...
					" values(%i, '%s');"
					,accid,eventoinfo.name
				);
				tr.AddQuery(query);

				char plrname[MAX_NAME_LENGTH];
				GetClientName(i, plrname, MAX_NAME_LENGTH);

				thedb.Format(query, QUERY_STR_MAX, 
					"insert into winners_rank " ...
					" (accountid,last_name,evento,count) " ...
					" values(%i,'%s','%s',1) " ...
					" on duplicate key update " ...
					" last_name='%s', count=count+1" ...
					";"
					,accid,plrname,eventoinfo.name,
					plrname
				);
				tr.AddQuery(query);
			}
		}

		give_rewards_ex(i, current_evento_idx);

		DoAchievementEffects(i);

		if(achiv_rei1 != Achievement_Null) {
			achiv_rei1.Award(i);
		}

		if(StrEqual(eventoinfo.name, "MGE")) {
			if(achiv_nezay != Achievement_Null) {
				achiv_nezay.AwardProgress(i, 1);
			}
		} else if(StrEqual(eventoinfo.name, "Parkour")) {
			if(achiv_parkour != Achievement_Null) {
				achiv_parkour.Award(i);
			}
		} else if(StrEqual(eventoinfo.name, "Color Wars") ||
					StrEqual(eventoinfo.name, "Dodgeball") ||
					StrEqual(eventoinfo.name, "Pega a Dispenser!")) {
			if(achiv_rei5 != Achievement_Null) {
				achiv_rei5.Award(i);
			}
		} else if(StrEqual(eventoinfo.name, "Dice") ||
					StrEqual(eventoinfo.name, "Pedra, Papel e Tesoura") ||
					StrEqual(eventoinfo.name, "Dispenser")) {
			if(achiv_rng != Achievement_Null) {
				achiv_rng.Award(i);
			}
		}

		CPrintToChatAll(EVENTO_CHAT_PREFIX ... "%N ganhou", i);

		TF2_RespawnPlayer(i);
	}

	if(thedb != null) {
		thedb.Format(query, QUERY_STR_MAX, 
			"select * from winners_rank order by count desc;"
			,eventoinfo.name
		);
		tr.AddQuery(query,-1);

		thedb.Execute(tr, query_recreate_rankmenus, on_tr_error);
	}

	CPrintToChatAll(EVENTO_CHAT_PREFIX ... "Evento terminado");

	clear_evento_vars();
}

static void start_evento_now(int idx)
{
	evento_secs = -1;
	current_evento_idx = idx;
	EventoInfo eventoinfo;
	evento_infos.GetArray(current_evento_idx, eventoinfo, sizeof(EventoInfo));
	current_evento = eventoinfo;
	start_evento_queued();
}

static Action timer_teleport(Handle timer, int client)
{
	client = GetClientOfUserId(client);
	if(client == 0) {
		return Plugin_Continue;
	}

	teleport_player_to_event(client);

	return Plugin_Continue;
}

bool teleport_player_to_event(int client) {
	if(!IsPlayerAlive(client)) {
		TF2_RespawnPlayer(client);
	}

	int team = GetClientTeam(client);
	if(teleport_set & BIT_FOR_TEAM(team)) {
		TeleportEntity(client, teleport[IDX_FOR_TEAM(team)], teleport_angles[IDX_FOR_TEAM(team)]);
		return true;
	}

	return false;
}

static void handle_player(int i, EventoInfo eventoinfo)
{
	int class = view_as<int>(TF2_GetPlayerClass(i));
	if(!is_class_valid(eventoinfo, class)) {
		int j = 1;
		for(; j < TF_CLASS_COUNT_ALL; ++j) {
			if(is_class_valid(eventoinfo, j)) {
				break;
			}
		}
		TF2_SetPlayerClass(i, view_as<TFClassType>(j), _, true);
		TF2_RespawnPlayer(i);
	}

	int team = GetClientTeam(i);
	if(eventoinfo.team > 0 && eventoinfo.team != team) {
		team = (eventoinfo.team == 2 ? 3 : 2);
	} else if(team == 3 && ((!(teleport_set & BIT_FOR_TEAM(3))) && (teleport_set & BIT_FOR_TEAM(2)))) {
		team = 2;
	}

	//ChangeClientTeam(i, team);
	set_client_team(i, view_as<TFTeam>(team));

	if(godmode_loaded) {
		SVBGodMode_SetClientState(i, GodState_Mortal);
	}

	int usrid = GetClientUserId(i);
	CreateTimer(0.2, timer_teleport, usrid);
}

static void handle_melee_all()
{
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			handle_melee(i);
		}
	}
}

static void handle_melee(int client)
{
	if(current_evento_idx == -1) {
		return;
	}

	if(current_state != EVENTO_STATE_IN_PROGRESS && current_state != EVENTO_STATE_IN_COUNTDOWN_END) {
		return;
	}

	if(!participando[client]) {
		return;
	}

	if(!current_config.melee) {
		return;
	}

	int melee_weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	if(!IsValidEntity(melee_weapon)) {
		return;
	}

	int active_weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if(IsValidEntity(active_weapon)) {
		char active_weapon_classname[ENTITY_CLASSNAME_MAX];
		GetEntityClassname(active_weapon, active_weapon_classname, sizeof(active_weapon_classname));
		if(StrEqual(active_weapon_classname, "tf_weapon_minigun")) {
			SetEntProp(active_weapon, Prop_Send, "m_iWeaponState", 0);
			TF2_RemoveCondition(client, TFCond_Slowed);
		}
	}

	SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", melee_weapon);
}

static void handle_friendlyfire_all()
{
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			handle_friendlyfire(i);
		}
	}
}

static void handle_friendlyfire(int client)
{
	if(is_participating_in_in_progress_event(client) &&
		current_config.friendly_fire) {
		enable_friendlyfire(client);	
	} else {
		disable_friendlyfire(client);
	}
}

static void enable_friendlyfire(int client)
{
	wants_lag_compensation_hook_id[client] = wants_lag_compensation.HookEntity(Hook_Pre, client, dhook_wants_lag_compensation_on_entity);
	if(!IsFakeClient(client)) {
		mp_friendlyfire.ReplicateToClient(client, "1");
		tf_avoidteammates.ReplicateToClient(client, "0");
	}
}

static void disable_friendlyfire(int client)
{
	if(wants_lag_compensation_hook_id[client] != INVALID_HOOK_ID) {
		DynamicHook.RemoveHook(wants_lag_compensation_hook_id[client]);
		wants_lag_compensation_hook_id[client] = INVALID_HOOK_ID;
	}

	if(!IsFakeClient(client)) {
		char cvar_value[8];
		mp_friendlyfire.GetString(cvar_value, sizeof(cvar_value));
		mp_friendlyfire.ReplicateToClient(client, cvar_value);
		tf_avoidteammates.GetString(cvar_value, sizeof(cvar_value));
		tf_avoidteammates.ReplicateToClient(client, cvar_value);
	}
}

static void set_player_event_team_if_needed(int client) {
	if(current_evento_idx == -1) {
		return;
	}
	
	if(current_state != EVENTO_STATE_IN_PROGRESS && current_state != EVENTO_STATE_IN_COUNTDOWN_END) {
		return;
	}
	
	if(!(teleport_set & BIT_FOR_TEAM(2)) || !(teleport_set & BIT_FOR_TEAM(3))) {
		return;
	}
	
	int red_count = 0;
	int blu_count = 0;
	
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		
		if(!participando[i]) {
			continue;
		}
		
		if(TF2_GetClientTeam(i) == TFTeam_Red) {
			red_count++;
		} else if(TF2_GetClientTeam(i) == TFTeam_Blue) {
			blu_count++;
		}
	}
	
	if(red_count < blu_count) {
		set_client_team(client, TFTeam_Red);
	} else {
		set_client_team(client, TFTeam_Blue);
	}
}

static void set_client_team(int client, TFTeam team)
{
	TeamManager_SetEntityTeam(client, view_as<int>(team), false);
	set_client_wearables_team(client, team);
}

static void set_client_wearables_team(int client, TFTeam team) {
	int wearablesCount = TF2Util_GetPlayerWearableCount(client);
	for(int i = 0; i < wearablesCount; i++) {
		int wearable = TF2Util_GetPlayerWearable(client, i);
		if(IsValidEntity(wearable)) {
			TeamManager_SetEntityTeam(wearable, view_as<int>(team), false);
		}
	}
}

static Action timer_podesematar(Handle timer, any data)
{
	podesematar = false;
	timerpodesematar = null;
	return Plugin_Continue;
}

static Action timer_passo20seg(Handle timer, any data)
{
	for(int i = 1; i <= MaxClients; ++i) {
		if(!participando[i]) {
			continue;
		}

		if(!morreu[i]) {
			if(achiv_color != Achievement_Null) {
				achiv_color.Award(i);
			}
		}
	}
	timer20seg = null;
	return Plugin_Continue;
}

static void start_evento_queued()
{
	current_state = EVENTO_STATE_IN_PROGRESS;

	EventoInfo eventoinfo;
	evento_infos.GetArray(current_evento_idx, eventoinfo, sizeof(EventoInfo));

	if(eventoinfo.cmds[0] != null) {
		char cmdstr[CMD_STR_MAX];

		int len = eventoinfo.cmds[0].Length;
		for(int i = 0; i < len; ++i) {
			eventoinfo.cmds[0].GetString(i, cmdstr, CMD_STR_MAX);
			ServerCommand("%s", cmdstr);
		}
	}

	if((teleport_set & BIT_FOR_TEAM(2)) && (teleport_set & BIT_FOR_TEAM(3))) {
		split_participants();
	}

	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i) ||
			!participando[i]) {
			continue;
		}

		handle_player(i, eventoinfo);
		handle_melee(i);
		handle_friendlyfire(i);
	}

	CPrintToChatAll(EVENTO_CHAT_PREFIX ... "Evento inciado");

	delete timerpodesematar;
	timerpodesematar = CreateTimer(1.0, timer_podesematar);

	if(StrEqual(eventoinfo.name, "Corzinha")) {
		if(timer20seg != null) {
			KillTimer(timer20seg);
		}
		timer20seg = CreateTimer(20.0, timer_passo20seg);
	}
}

static void split_participants() {
	ArrayList participants = get_participants();
	shuffle_cell_list(participants);

	for(int i = 0; i < participants.Length; i++) {
		int client = participants.Get(i);
		TFTeam new_team = i % 2 == 0 ? TFTeam_Red :TFTeam_Blue;
		set_client_team(client, new_team);
	}

	delete participants;
}

static ArrayList get_participants() {
	ArrayList participants = new ArrayList();
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) && participando[i]) {
			participants.Push(i);
		}
	}
	return participants;
}

static void shuffle_cell_list(ArrayList list) {
	int len = list.Length;

	if(len <= 1) {
		return;
	}

	for(int i = 0; i < len - 1; i++) {
		int element = list.Get(i);
		int swap_idx = GetRandomInt(i, len - 1);
		list.Set(i, list.Get(swap_idx));
		list.Set(swap_idx, element);
	}
}

static bool countdown_tick()
{
	if(evento_secs == 0 || --evento_secs == 0) {
		switch(current_state) {
			case EVENTO_STATE_IN_COUNTDOWN_START:
			{ start_evento_queued(); }
			case EVENTO_STATE_IN_COUNTDOWN_END:
			{ end_evento(); }
		}
		return true;
	} else {
		EventoInfo eventoinfo;
		evento_infos.GetArray(current_evento_idx, eventoinfo, sizeof(EventoInfo));

		char timestr[TIME_STR_MAX];
		format_seconds(evento_secs, timestr);

		for(int i = 1; i <= MaxClients; ++i) {
			if(!IsClientInGame(i) ||
				IsFakeClient(i)) {
				continue;
			}

			ClearSyncHud(i, hud);
			SetHudTextParams(0.05, 0.1, 1.0, 0, 0, 255, 255);

			switch(current_state) {
				case EVENTO_STATE_IN_COUNTDOWN_START:
				{ ShowSyncHudText(i, hud, EVENTO_CON_PREFIX ... "%s começa em %s", eventoinfo.name, timestr); }
				case EVENTO_STATE_IN_COUNTDOWN_END:
				{ ShowSyncHudText(i, hud, EVENTO_CON_PREFIX ... "%s termina em %s", eventoinfo.name, timestr); }
			}
		}
	}
	return false;
}

static void show_participating_hud(int client) {
	if(!hud_participating) {
		return;
	}

	ClearSyncHud(client, hud_participating);

	if(current_state != EVENTO_STATE_IN_COUNTDOWN_START) {
		return;
	}

	float hold_time = float(evento_secs);

	if(participando[client]) {
		SetHudTextParams(0.05, 0.15, hold_time, 0, 255, 0, 255);
		ShowSyncHudText(client, hud_participating, "Você está participando");
	} else {
		SetHudTextParams(0.05, 0.15, hold_time, 255, 0, 0, 255);
		ShowSyncHudText(client, hud_participating, "Digite !evento para participar");
	}
}

static Action timer_countdown(Handle timer, any data)
{
	if(countdown_tick()) {
		countdown_handle = null;
		return Plugin_Stop;
	} else {
		return Plugin_Continue;
	}
}

static void queue_evento_end(int secs)
{
	if(current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
		evento_secs = secs;
		return;
	}

	current_state = EVENTO_STATE_IN_COUNTDOWN_END;
	start_countdown(secs);
}

static void cancel_evento_end()
{
	stop_countdown();
	current_state = EVENTO_STATE_IN_PROGRESS;
}

static void queue_evento_start(int idx, int secs)
{
	if(current_state == EVENTO_STATE_IN_COUNTDOWN_START) {
		evento_secs = secs;
		return;
	}

	current_evento_idx = idx;
	EventoInfo eventoinfo;
	evento_infos.GetArray(current_evento_idx, eventoinfo, sizeof(EventoInfo));
	current_evento = eventoinfo;
	current_state = EVENTO_STATE_IN_COUNTDOWN_START;
	start_countdown(secs);
}

static Action player_say(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client == chat_listen.client) {
		char timestr[TIME_INPUT_STR_MAX];
		event.GetString("text", timestr, TIME_INPUT_STR_MAX);

		int secs = parse_time_string(timestr);
		if(secs >= 0) {
			if(chat_listen.start) {
				queue_evento_start(chat_listen.idx, secs);
			} else {
				queue_evento_end(secs);
			}
		} else {
			CPrintToChat(client, EVENTO_CHAT_PREFIX ... "Tempo inválido");
		}

		chat_listen.client = -1;

		event.BroadcastDisabled = true;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

static int teleport_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		char intstr[INT_STR_MAX];
		menu.GetItem(0, intstr, INT_STR_MAX);
		int idx = StringToInt(intstr);

		switch(param2) {
			case 1: {
				float pos[3];
				GetClientAbsOrigin(param1, pos);
				float angles[3];
				GetClientAbsAngles(param1, angles);

				static const int team = 3;
				teleport[IDX_FOR_TEAM(team)][0] = pos[0];
				teleport[IDX_FOR_TEAM(team)][1] = pos[1];
				teleport[IDX_FOR_TEAM(team)][2] = pos[2];
				teleport_angles[IDX_FOR_TEAM(team)][0] = angles[0];
				teleport_angles[IDX_FOR_TEAM(team)][1] = angles[1];
				teleport_angles[IDX_FOR_TEAM(team)][2] = angles[2];
				teleport_set |= BIT_FOR_TEAM(team);
			}
			case 2: {
				float pos[3];
				GetClientAbsOrigin(param1, pos);
				float angles[3];
				GetClientAbsAngles(param1, angles);

				static const int team = 2;
				teleport[IDX_FOR_TEAM(team)][0] = pos[0];
				teleport[IDX_FOR_TEAM(team)][1] = pos[1];
				teleport[IDX_FOR_TEAM(team)][2] = pos[2];
				teleport_angles[IDX_FOR_TEAM(team)][0] = angles[0];
				teleport_angles[IDX_FOR_TEAM(team)][1] = angles[1];
				teleport_angles[IDX_FOR_TEAM(team)][2] = angles[2];
				teleport_set |= BIT_FOR_TEAM(team);
			}
			case 3: {
				float pos[3];
				GetClientAbsOrigin(param1, pos);
				float angles[3];
				GetClientAbsAngles(param1, angles);

				int team = 2;
				teleport[IDX_FOR_TEAM(team)][0] = pos[0];
				teleport[IDX_FOR_TEAM(team)][1] = pos[1];
				teleport[IDX_FOR_TEAM(team)][2] = pos[2];
				teleport_angles[IDX_FOR_TEAM(team)][0] = angles[0];
				teleport_angles[IDX_FOR_TEAM(team)][1] = angles[1];
				teleport_angles[IDX_FOR_TEAM(team)][2] = angles[2];
				teleport_set |= BIT_FOR_TEAM(team);

				team = 3;
				teleport[IDX_FOR_TEAM(team)][0] = pos[0];
				teleport[IDX_FOR_TEAM(team)][1] = pos[1];
				teleport[IDX_FOR_TEAM(team)][2] = pos[2];
				teleport_angles[IDX_FOR_TEAM(team)][0] = angles[0];
				teleport_angles[IDX_FOR_TEAM(team)][1] = angles[1];
				teleport_angles[IDX_FOR_TEAM(team)][2] = angles[2];
				teleport_set |= BIT_FOR_TEAM(team);
			}
			case 4: {
				for(int i = 1; i <= MaxClients; ++i) {
					if(!IsClientInGame(i) ||
						!participando[i]) {
						continue;
					}

					int team = GetClientTeam(i);
					if(teleport_set & BIT_FOR_TEAM(team)) {
						TeleportEntity(i, teleport[IDX_FOR_TEAM(team)], teleport_angles[IDX_FOR_TEAM(team)]);
					}
				}
			}
			case 5: {
				int team = 2;
				teleport[IDX_FOR_TEAM(team)][0] = 0.0;
				teleport[IDX_FOR_TEAM(team)][1] = 0.0;
				teleport[IDX_FOR_TEAM(team)][2] = 0.0;

				team = 3;
				teleport[IDX_FOR_TEAM(team)][0] = 0.0;
				teleport[IDX_FOR_TEAM(team)][1] = 0.0;
				teleport[IDX_FOR_TEAM(team)][2] = 0.0;

				teleport_set = 0;
			}
			case 6: {
				static const int team = 2;
				teleport[IDX_FOR_TEAM(team)][0] = 0.0;
				teleport[IDX_FOR_TEAM(team)][1] = 0.0;
				teleport[IDX_FOR_TEAM(team)][2] = 0.0;

				teleport_set &= ~BIT_FOR_TEAM(team);
			}
			case 7: {
				static const int team = 3;
				teleport[IDX_FOR_TEAM(team)][0] = 0.0;
				teleport[IDX_FOR_TEAM(team)][1] = 0.0;
				teleport[IDX_FOR_TEAM(team)][2] = 0.0;

				teleport_set &= ~BIT_FOR_TEAM(team);
			}
		}

		teleport_menu(param1, idx);
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			char intstr[INT_STR_MAX];
			menu.GetItem(0, intstr, INT_STR_MAX);
			int idx = StringToInt(intstr);

			evento_menu(param1, idx);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

public void OnGameFrame()
{
	if(teleport_set & BIT_FOR_TEAM(2)) {
		float start[3];
		start[0] = teleport[IDX_FOR_TEAM(2)][0];
		start[1] = teleport[IDX_FOR_TEAM(2)][1];
		start[2] = teleport[IDX_FOR_TEAM(2)][2];

		float end[3];
		end[0] = start[0];
		end[1] = start[1];
		end[2] = start[2] + 72.0;

		TE_SetupBeamPoints(start, end, laserbeam, 0, 0, 0, 0.1, 1.0, 1.0, 0, 0.0, {255, 0, 0, 255}, 0);
		TE_SendToAll();
	}

	if(teleport_set & BIT_FOR_TEAM(3)) {
		float start[3];
		start[0] = teleport[IDX_FOR_TEAM(3)][0];
		start[1] = teleport[IDX_FOR_TEAM(3)][1];
		start[2] = teleport[IDX_FOR_TEAM(3)][2];

		float end[3];
		end[0] = start[0];
		end[1] = start[1];
		end[2] = start[2] + 72.0;

		TE_SetupBeamPoints(start, end, laserbeam, 0, 0, 0, 0.1, 1.0, 1.0, 0, 0.0, {0, 0, 255, 255}, 0);
		TE_SendToAll();
	}
}

static void teleport_menu(int client, int idx)
{
	Menu menu = new Menu(teleport_menu_handler);
	menu.SetTitle("Teleport");
	menu.ExitBackButton = true;

	char intstr[INT_STR_MAX];
	IntToString(idx, intstr, INT_STR_MAX);
	menu.AddItem(intstr, "", ITEMDRAW_IGNORE);

	menu.AddItem("0", "blue");
	menu.AddItem("1", "red");
	menu.AddItem("2", "ambos");
	menu.AddItem("3", "teleportar");
	menu.AddItem("4", "resetar ambos");
	menu.AddItem("5", "resetar red");
	menu.AddItem("6", "resetar blue");

	menu.Display(client, MENU_TIME_FOREVER);
}

static int evento_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Display) {
		usando_menu = param1;
	} else if(action == MenuAction_Select) {
		char intstr[INT_STR_MAX];
		menu.GetItem(0, intstr, INT_STR_MAX);
		int idx = StringToInt(intstr);

		menu.GetItem(param2, intstr, INT_STR_MAX);
		param2 = StringToInt(intstr);

		switch(param2) {
			case 0, 1: {
				chat_listen.client = param1;
				chat_listen.start = true;
				chat_listen.idx = idx;
				CPrintToChat(param1, EVENTO_CHAT_PREFIX ... "Digite o tempo no chat");
			}
			case 2, 9: {
				chat_listen.client = param1;
				chat_listen.start = false;
				chat_listen.idx = idx;
				CPrintToChat(param1, EVENTO_CHAT_PREFIX ... "Digite o tempo no chat");
			}
			case 3: {
				cancel_evento_end();
			}
			case 4: {
				cancel_evento();
			}
			case 5: {
				players_menu(param1, idx, true);
			}
			case 6: {
				winners_menu(param1, idx);
			}
			case 7: {
				teleport_menu(param1, idx);
			}
			case 8: {
				stop_countdown();
				start_evento_queued();
			}
			case 10: {
				start_evento_now(idx);
			}
			case 11: {
				end_evento();
			}
			case 12: {
				players_menu(param1, idx, false);
			}
			case 13: {
				configs_menu(param1);
			}
		}
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			eventos_menu(param1);
		}
	} else if(action == MenuAction_End) {
		usando_menu = -1;
		delete menu;
	}

	return 0;
}

static void evento_menu(int client, int idx)
{
	EventoInfo eventoinfo;
	evento_infos.GetArray(idx, eventoinfo, sizeof(EventoInfo));

	Menu menu = new Menu(evento_menu_handler);
	menu.SetTitle(eventoinfo.name);
	if(current_evento_idx == -1) {
		menu.ExitBackButton = true;
	}

	char intstr[INT_STR_MAX];
	IntToString(idx, intstr, INT_STR_MAX);
	menu.AddItem(intstr, "", ITEMDRAW_IGNORE);

	menu.AddItem("13", "configurações");

	if(current_evento_idx == idx) {
		menu.AddItem("5", "participantes");
		menu.AddItem("12", "nao participantes");
		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			menu.AddItem("6", "marcados para vencer");
		}
	}

	menu.AddItem("7", "teleport");

	if(current_evento_idx == -1) {
		menu.AddItem("0", "marcar inicio");
		menu.AddItem("10", "inicar agora");
	} else {
		switch(current_state) {
			case EVENTO_STATE_IN_COUNTDOWN_END:
			{
				menu.AddItem("3", "cancelar termino");
				menu.AddItem("9", "adiar termino");
			}
			case EVENTO_STATE_IN_COUNTDOWN_START:
			{
				menu.AddItem("8", "iniciar agora");
				menu.AddItem("1", "adiar inicio");
			}
			case EVENTO_STATE_IN_PROGRESS:
			{ menu.AddItem("2", "marcar termino"); }
		}
		menu.AddItem("4", "cancelar");
		if(current_state == EVENTO_STATE_IN_PROGRESS ||
			current_state == EVENTO_STATE_IN_COUNTDOWN_END) {
			menu.AddItem("11", "terminar");
		}
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

static int eventos_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Display) {
		usando_menu = param1;
	} else if(action == MenuAction_Select) {
		char intstr[INT_STR_MAX];
		menu.GetItem(param2, intstr, INT_STR_MAX);
		int idx = StringToInt(intstr);

		EventoInfo eventoinfo;
		evento_infos.GetArray(idx, eventoinfo, sizeof(EventoInfo));

		EventoConfig eventoconfig;
		eventoconfig.Init(eventoinfo);
		current_config = eventoconfig;

		selected_evento_idx[param1] = idx;
		evento_menu(param1, idx);
	} else if(action == MenuAction_End) {
		usando_menu = -1;
		delete menu;
	}

	return 0;
}

static void eventos_menu(int client)
{
	Menu menu = new Menu(eventos_menu_handler);
	menu.SetTitle("Eventos");

	char intstr[INT_STR_MAX];

	EventoInfo eventoinfo;

	int len = evento_infos.Length;
	for(int i = 0; i < len; ++i) {
		evento_infos.GetArray(i, eventoinfo, sizeof(EventoInfo));

		IntToString(i, intstr, INT_STR_MAX);
		menu.AddItem(intstr, eventoinfo.name);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

static void configs_menu(int client, int first_item = 0)
{
	Menu menu = new Menu(configs_menu_handler);
	menu.SetTitle("Configurações do Evento");

	char menu_item[MENU_ITEM_DISPLAY_MAX];

	format_boolean_config_item("Respawn", current_config.respawn, menu_item, sizeof(menu_item));
	menu.AddItem("respawn", menu_item);

	format_boolean_config_item("Bhop", current_config.bhop, menu_item, sizeof(menu_item));
	menu.AddItem("bhop", menu_item);

	format_boolean_config_item("Apenas melee", current_config.melee, menu_item, sizeof(menu_item));
	menu.AddItem("melee", menu_item);

	format_boolean_config_item("Random crits", current_config.random_crits, menu_item, sizeof(menu_item));
	menu.AddItem("random_crits", menu_item);

	format_boolean_config_item("Dano entre os participantes", current_config.damage, menu_item, sizeof(menu_item));
	menu.AddItem("damage", menu_item);

	format_boolean_config_item("Munição infinita", current_config.infinite_ammo, menu_item, sizeof(menu_item));
	menu.AddItem("infinite_ammo", menu_item);

	format_boolean_config_item("Metal infinito", current_config.infinite_metal, menu_item, sizeof(menu_item));
	menu.AddItem("infinite_metal", menu_item);

	format_boolean_config_item("Friendly fire", current_config.friendly_fire, menu_item, sizeof(menu_item));
	menu.AddItem("friendly_fire", menu_item);
	
	format_boolean_config_item("Ícone acima dos participantes", current_config.show_sprite, menu_item, sizeof(menu_item));
	menu.AddItem("show_sprite", menu_item);

	menu.ExitBackButton = true;

	menu.DisplayAt(client, first_item, MENU_TIME_FOREVER);
}

static void format_boolean_config_item(char[] display, bool value, char[] output, int output_len)
{
	FormatEx(output, output_len, "%s: [%s]", display, value ? "X" : " ");
}

static int configs_menu_handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		char info[MENU_ITEM_INFO_MAX];
		menu.GetItem(param2, info, sizeof(info));

		handle_config_selection(param1, info);

		configs_menu(param1, menu.Selection);
	} else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			evento_menu(param1, selected_evento_idx[param1]);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

static void handle_config_selection(int client, char[] selectedConfig)
{
	if(StrEqual(selectedConfig, "respawn")) {
		current_config.respawn = !current_config.respawn;
		show_config_change_message(client, "Respawn", current_config.respawn);
	} else if(StrEqual(selectedConfig, "bhop")) {
		current_config.bhop = !current_config.bhop;
		show_config_change_message(client, "Bhop", current_config.bhop);
	} else if(StrEqual(selectedConfig, "melee")) {
		current_config.melee = !current_config.melee;
		show_config_change_message(client, "Modo apenas melee", current_config.melee);
		handle_melee_all();
	} else if(StrEqual(selectedConfig, "random_crits")) {
		current_config.random_crits = !current_config.random_crits;
		show_config_change_message(client, "Random crit", current_config.random_crits);
	} else if(StrEqual(selectedConfig, "damage")) {
		current_config.damage = !current_config.damage;
		show_config_change_message(client, "Dano entre os participantes", current_config.damage);
	} else if(StrEqual(selectedConfig, "infinite_ammo")) {
		current_config.infinite_ammo= !current_config.infinite_ammo;
		show_config_change_message(client, "Munição infinita", current_config.infinite_ammo);
	} else if(StrEqual(selectedConfig, "infinite_metal")) {
		current_config.infinite_metal = !current_config.infinite_metal;
		show_config_change_message(client, "Metal infinito", current_config.infinite_metal);
	} else if(StrEqual(selectedConfig, "friendly_fire")) {
		current_config.friendly_fire = !current_config.friendly_fire;
		show_config_change_message(client, "Friendly fire", current_config.friendly_fire);
		handle_friendlyfire_all();
	} else if(StrEqual(selectedConfig, "show_sprite")) {
		current_config.show_sprite = !current_config.show_sprite;
		show_config_change_message(client, "Ícone acima dos participantes", current_config.show_sprite);
	}
}

static void show_config_change_message(int client_who_changed_config, char[] configName, bool newValue)
{
	if(current_state != EVENTO_STATE_IN_PROGRESS && 
		current_state != EVENTO_STATE_IN_COUNTDOWN_END) {
		return;
	}

	CShowActivity2(client_who_changed_config, EVENTO_CHAT_PREFIX, "%s %s", configName, newValue ? "ativado" : "desativado");
}

static Action sm_mevento(int client, int args)
{
	if(evento_infos == null) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Não existe nenhum evento registrado");
		return Plugin_Handled;
	}

	if(client == 0) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Não é possível executar esse comando pelo console");
		return Plugin_Handled;
	}

	if(usando_menu != -1) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "O jogador %N já está utilizando o menu de evento", usando_menu);
		return Plugin_Handled;
	}

	if(current_evento_idx == -1) {
		eventos_menu(client);
	} else {
		evento_menu(client, current_evento_idx);
	}

	return Plugin_Handled;
}

static Action sm_reventos(int client, int args)
{
	unload_eventos();
	load_eventos();
	return Plugin_Handled;
}

static Action sm_leventos(int client, int args)
{
	if(evento_infos == null) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Não existe nenhum evento registrado");
		return Plugin_Handled;
	}

	int len = evento_infos.Length;

	int buffer_len = ((EVENTO_NAME_MAX+1) * len);
	char[] buffer = new char[buffer_len];

	EventoInfo eventoinfo;

	for(int i = 0; i < len; ++i) {
		evento_infos.GetArray(i, eventoinfo, sizeof(EventoInfo));

		StrCat(buffer, buffer_len, eventoinfo.name);
		StrCat(buffer, buffer_len, "\n");
	}

	PrintToConsole(client, "%s", buffer);

	return Plugin_Handled;
}

static Action sm_split(int client, int args)
{
	if(current_evento_idx == -1) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Não há nenhum evento em andamento");
		return Plugin_Handled;
	}

	split_participants();

	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || !participando[i]) {
			continue;
		}

		int team = GetClientTeam(i);
		if(teleport_set & BIT_FOR_TEAM(team)) {
			teleport_player_to_event(i);
		}

		CPrintToChat(i, EVENTO_CHAT_PREFIX ... "Os participantes foram divididos em times por um administrador. Seu time agora é %s.", team == 2 ? "RED" : "BLU");
	}

	CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Split realizado com sucesso");

	return Plugin_Handled;
}

static Action sm_fevento(int client, int args)
{
	if(current_evento_idx == -1) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Não há nenhum evento em andamento");
		return Plugin_Handled;
	}

	if(args != 2) {
		CReplyToCommand(client, EVENTO_CHAT_PREFIX ... "Use: sm_fevento <alvo> <1/0>");
		return Plugin_Handled;
	}

	char target[MAX_TARGET_LENGTH];
	GetCmdArg(1, target, sizeof(target));

	bool should_participate = !!GetCmdArgInt(2);

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	bool tn_is_ml;

	int target_count = ProcessTargetString(target, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml);
	if(target_count == 0) {
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i = 0; i < target_count; i++) {
		int target_client = target_list[i];
		if(should_participate) {
			set_player_event_team_if_needed(target_client);
		}
		set_participando(target_client, should_participate);
	}

	if(tn_is_ml) {
		if(should_participate) {
			CShowActivity2(client, EVENTO_CHAT_PREFIX, "%t foi/foram forçado(s) a participar do evento", target_name);
		} else {
			CShowActivity2(client, EVENTO_CHAT_PREFIX, "%t foi/foram forçado(s) a sair do evento", target_name);
		}
	} else {
		if(should_participate) {
			CShowActivity2(client, EVENTO_CHAT_PREFIX, "%s foi/foram forçado(s) a participar do evento", target_name);
		} else {
			CShowActivity2(client, EVENTO_CHAT_PREFIX, "%s foi/foram forçado(s) a sair do evento", target_name);
		}
	}

	return Plugin_Handled;
}

int native_get_current_state(Handle plugin, int params)
{
	return view_as<int>(current_state);
}

int native_is_participating(Handle plugin, int params)
{
	int client = GetNativeCell(1);

	if(client < 1 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
	}

	if(!IsClientInGame(client)) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Client not ingame [%d]", client);
	}

	return view_as<int>(participando[client]);
}

int native_is_bhop_enabled(Handle plugin, int params)
{
	if(current_state != EVENTO_STATE_IN_PROGRESS &&
		current_state != EVENTO_STATE_IN_COUNTDOWN_END) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Event not in progress");
	}

	return view_as<int>(current_config.bhop);
}