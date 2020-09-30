stock void Register_Core_Commands()
{
	RegAdminCmd("sm_startevento", ConCommand_StartEvento, ADMFLAG_ROOT);
	RegAdminCmd("sm_endevento", ConCommand_EndEvento, ADMFLAG_ROOT);
	RegAdminCmd("sm_cancelevento", ConCommand_CancelEvento, ADMFLAG_ROOT);
	RegAdminCmd("sm_split", ConCommand_Split, ADMFLAG_ROOT);
	RegAdminCmd("sm_forceevento", ConCommand_ForcarEvento, ADMFLAG_ROOT);
	RegAdminCmd("sm_forcetime", ConCommand_ForcarTime, ADMFLAG_ROOT);
	
	RegConsoleCmd("sm_participantes", ConCommand_Participantes);
	RegConsoleCmd("sm_participando", ConCommand_Participando);
	RegConsoleCmd("sm_explain", ConCommand_Explain);
	RegConsoleCmd("sm_evento", ConCommand_Evento);
	RegConsoleCmd("sm_time", ConCommand_Time);
	RegConsoleCmd("sm_times", ConCommand_Times);
}

stock Action ConCommand_StartEvento(int client, int args)
{
	if(Eventinho_InEvent()) {
		CReplyToCommand(client, CHAT_PREFIX ... "Há um evento em andamento.");
		return Plugin_Handled;
	}
	
	ArrayList eventos = new ArrayList();
	Eventinho_GetAllEvents(eventos);

	if(args >= 1) {
		char count[32];
		GetCmdArg(1, count, sizeof(count));
		g_tmpStartCountdown = StringToFloat(count);
	}
	
	Handle style = GetMenuStyleHandle(MenuStyle_Default);
	Menu menu = CreateMenuEx(style, MenuHandler_Evento, MENU_ACTIONS_DEFAULT);
	menu.SetTitle("Eventos");

	bool found = false;

	int length = eventos.Length;
	for(int i = 0; i < length; i++) {
		Evento evento = eventos.Get(i);
		
		if(MapSupportsEvent(evento)) {
			char nome[64];
			evento.GetName(nome, sizeof(nome));
			
			menu.AddItem(nome, nome, ITEMDRAW_DEFAULT);

			found = true;
		}
		
		delete evento;
	}
	menu.Display(client, MENU_TIME_FOREVER);
	
	delete eventos;

	if(!found) {
		CReplyToCommand(client, CHAT_PREFIX ... "Nenhum evento encontrado para este mapa.");
		g_tmpStartCountdown = DEFAULT_START_COUNTDOWN;
	}

	g_TmpAdmin = client;
	
	return Plugin_Handled;
}

stock Action ConCommand_CancelEvento(int client, int args)
{
	if(!Eventinho_InEvent()) {
		CReplyToCommand(client,  CHAT_PREFIX ... "Não há nenhum evento em andamento.");
		return Plugin_Handled;
	}
	
	Eventinho_CancelEvent();
	
	return Plugin_Handled;
}

stock Action ConCommand_EndEvento(int client, int args)
{
	Evento evento = Eventinho_CurrentEvent();
	
	if(!evento) {
		CReplyToCommand(client, CHAT_PREFIX ... "Não há nenhum evento em andamento.");
		return Plugin_Handled;
	}

	char nome[64];
	evento.GetName(nome, sizeof(nome));
	
	if(evento.GetState() != EventInProgress) {
		CReplyToCommand(client, CHAT_PREFIX ... "%s ainda não começou.", nome);
		return Plugin_Handled;
	}
	
	ArrayList winners = new ArrayList();
	
	bool errors = false;
	
	if(args > 0) {
		bool tmp_time = false;
		for(int i = 1; i <= args; i++) {
			char filter[32];
			GetCmdArg(i, filter, sizeof(filter));

			if(StrEqual(filter, "time")) {
				tmp_time = true;
				continue;
			}
			
			char name[MAX_TARGET_LENGTH];
			int targets[MAXPLAYERS];
			bool isml = false;
			int count = ProcessTargetString(filter, client, targets, MAXPLAYERS, COMMAND_FILTER_ALIVE|COMMAND_FILTER_NO_IMMUNITY, name, sizeof(name), isml);
			if(count == 0) {
				errors = true;
				PrintToConsole(client, "[Evento] arg%i (%s) não processado.", i, filter);
				tmp_time = false;
				continue;
			}
			
			for(int j = 0; j <= count; j++) {
				int target = targets[j];
				if(target == 0) {
					continue;
				}
				
				if(!Eventinho_IsParticipating(target)) {
					errors = true;
					PrintToConsole(client, "[Evento] %N não esta participando do %s", target, nome);
					continue;
				}

				if(tmp_time) {
					if(g_Time[target] == null) {
						errors = true;
						PrintToConsole(client, "[Evento] %N não tem um time.", target);
						continue;
					}

					int len = g_Time[target].Length;
					for(int k = 0; k < len; k++) {
						int membro = g_Time[target].Get(k);

						if(!Eventinho_IsParticipating(membro)) {
							errors = true;
							PrintToConsole(client, "[Evento] %N não esta participando do %s", membro, nome);
							continue;
						}

						winners.Push(membro);
					}

					if(errors) {
						continue;
					}

					CPrintToChatAll(CHAT_PREFIX ... "O Time de %N ganhou o %s", target, nome);
				} else {
					CPrintToChatAll(CHAT_PREFIX ... "%N Ganhou o %s", target, nome);
				}
				
				winners.Push(target);
			}

			tmp_time = false;
		}
		
		if(errors) {
			PrintToConsole(client, "========= Errors ^^^^^ ========");
		}
	}
	
	if(!errors) {
		Eventinho_EndEvent(winners, 0.0);
	} else if(client != 0) {
		CPrintToChat(client, CHAT_PREFIX ... "Aconteceram ERRORS, por favor olhe o console para mais informações");
	}
	
	delete winners;
	
	return Plugin_Handled;
}

stock void DisplayEventOptionsMenu(int client, const char[] name, StringMap options)
{
	g_TmpAdmin = client;

	Handle style = GetMenuStyleHandle(MenuStyle_Default);
	Menu menu = CreateMenuEx(style, MenuHandler_Options, MENU_ACTIONS_DEFAULT);
	
	SetMenuTitleFormated(menu, "%s - Opçoes", name);
	
	StringMapSnapshot snapshot = options.Snapshot();
	
	for(int i = 0; i < snapshot.Length; i++) {
		char key[64];
		snapshot.GetKey(i, key, sizeof(key));
		if(StrEqual(key, "__internal_refs")) {
			continue;
		}
		
		char value[64];
		options.GetString(key, value, sizeof(value));
		
		AddMenuItemFormated(menu, "%s: %s", key, value);
	}
	
	delete snapshot;
	
	menu.AddItem("Começar", "Começar", ITEMDRAW_DEFAULT);
	
	char optionsid[64];
	IntToString(view_as<int>(options), optionsid, sizeof(optionsid));
	
	menu.InsertItem(0, optionsid, optionsid, ITEMDRAW_IGNORE);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

stock void GetInverse(const char[] str, char[] dest, int len)
{
	if(StrEqual(str, "ON")) {
		strcopy(dest, len, "OFF");
	} else if(StrEqual(str, "OFF")) {
		strcopy(dest, len, "ON");
	}
}

stock int MenuHandler_Preparacao(Menu menu, MenuAction action, int param1, int param2)
{
	char optionsid[64];
	menu.GetItem(0, optionsid, sizeof(optionsid));
	
	StringMap options = view_as<StringMap>(StringToInt(optionsid));
	
	char title[64];
	menu.GetTitle(title, sizeof(title));
	
	char eventname[64];
	FindSubstrReverse(title, " - Preparaçao", eventname, sizeof(eventname));
	
	if(action == MenuAction_Select) {
		char name[64];
		menu.GetItem(param2, name, sizeof(name));

		char option_name[64];
		SplitString(name, " ", option_name, sizeof(option_name));
		
		char option_value[64];
		FindSubstr(name, " ", option_value, sizeof(option_value));

		if(!StrEqual(option_name, "OFF")) {
			g_tmpStartCountdown = StringToFloat(option_name);

			if(StrContains(option_value, "minuto") != -1) {
				g_tmpStartCountdown *= 60;
			}
		} else {
			g_tmpStartCountdown = 0.0;
		}
		
		options.SetString("Preparaçao", name);
		
		DisplayEventOptionsMenu(param1, eventname, options);
	} else if(action == MenuAction_End) {
		
		DisplayEventOptionsMenu(param1, eventname, options);
		
		delete menu;
	}
}

stock int MenuHandler_Options(Menu menu, MenuAction action, int param1, int param2)
{
	char optionsid[64];
	menu.GetItem(0, optionsid, sizeof(optionsid));
	
	StringMap options = view_as<StringMap>(StringToInt(optionsid));
	
	if(action == MenuAction_Select) {
		char name[64];
		menu.GetItem(param2, name, sizeof(name));
		
		char title[64];
		menu.GetTitle(title, sizeof(title));
		
		char eventname[64];
		FindSubstrReverse(title, " - Opçoes", eventname, sizeof(eventname));
		
		if(StrEqual(name, "Começar")) {

			int timeleft = 0;
			GetMapTimeLeft(timeleft);
			if(timeleft < (10 * 60)) {
				ExtendMapTimeLimit(30 * 60);
			}

			__Eventinho_StartEvent_IMPL(eventname, options, g_tmpStartCountdown);
			g_tmpStartCountdown = DEFAULT_START_COUNTDOWN;
		} else {
			char option_name[64];
			SplitString(name, ": ", option_name, sizeof(option_name));
			
			char option_value[64];
			FindSubstr(name, ": ", option_value, sizeof(option_value));

			if(StrEqual(option_name, "Preparaçao")) {
				Handle style = GetMenuStyleHandle(MenuStyle_Default);
				Menu menu2 = CreateMenuEx(style, MenuHandler_Preparacao, MENU_ACTIONS_DEFAULT);
				
				SetMenuTitleFormated(menu2, "%s - Preparaçao", eventname);
				
				menu2.AddItem("OFF", "OFF", ITEMDRAW_DEFAULT);
				menu2.AddItem("5 segundos", "5 segundos", ITEMDRAW_DEFAULT);
				menu2.AddItem("10 segundos", "10 segundos", ITEMDRAW_DEFAULT);
				menu2.AddItem("20 segundos", "20 segundos", ITEMDRAW_DEFAULT);
				menu2.AddItem("1 minuto", "1 minuto", ITEMDRAW_DEFAULT);
				menu2.AddItem("2 minutos", "2 minutos", ITEMDRAW_DEFAULT);
				menu2.AddItem("5 minutos", "5 minutos", ITEMDRAW_DEFAULT);
				
				menu2.InsertItem(0, optionsid, optionsid, ITEMDRAW_IGNORE);
				
				menu2.Display(param1, MENU_TIME_FOREVER);

				return 0;
			}
			
			Call_StartForward(hHandleMenuOption);
			Call_PushCell(param1);
			Call_PushString(eventname);
			Call_PushCell(options);
			Call_PushString(option_name);
			Call_PushStringEx(option_value, sizeof(option_value), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
			Call_PushCell(sizeof(option_value));
			
			bool result = false;
			Call_Finish(result);
			
			if(result) {
				
			} else {
				GetInverse(option_value, option_value, sizeof(option_value));
			}
			
			options.SetString(option_name, option_value);
			
			if(!result) {
				DisplayEventOptionsMenu(param1, eventname, options);
			}
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}
	
	return 0;
}

stock void GetOnOrOff(const char[] value, char[] res, int len)
{
	int intvalue = StringToInt(value);
	if(intvalue > 0) {
		strcopy(res, len, "ON");
	} else if(intvalue <= 0) {
		strcopy(res, len, "OFF");
	}
}

stock void FindCommandOption(const char[] command, char[] option, int len)
{
	if(!hOptionsMap.GetString(command, option, len)) {
		strcopy(option, len, "");
	}
}

stock void GetDefaultOptions(const char[] name, StringMap options)
{
	g_tmpStartCountdown = 10.0;
	options.SetString("Preparaçao", "10 segundos");
	
	Evento event = null;
	Eventinho_FindEvento(name, event);
	
	ArrayList commands = new ArrayList();
	event.GetStartCommands(commands);
	
	delete event;
	
	int length = commands.Length;
	for(int i = 0; i < length; i++) {
		EventCommand command = commands.Get(i);

		char key[64];
		command.GetName(key, sizeof(key));
		
		char value[64];
		command.GetValue(value, sizeof(value));
		
		delete command;
		
		GetOnOrOff(value, value, sizeof(value));
		
		FindCommandOption(key, key, sizeof(key));

		if(StrEmpty(key)) {
			continue;
		}
		
		options.SetString(key, value);
	}
	
	delete commands;
	
	Call_StartForward(hModifyDefaultOptions);
	Call_PushString(name);
	Call_PushCell(options);
	Call_Finish();
}

stock int MenuHandler_Evento(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		char name[64];
		menu.GetItem(param2, name, sizeof(name));
		
		hTmpOptions.Clear();
		GetDefaultOptions(name, hTmpOptions);
		DisplayEventOptionsMenu(param1, name, hTmpOptions);
		
	} else if(action == MenuAction_End) {
		delete menu;
	}
	
	return 0;
}

stock Action ConCommand_Participantes(int client, int args)
{
	Evento evento = Eventinho_CurrentEvent();
	
	if(!evento) {
		CReplyToCommand(client, CHAT_PREFIX ... "Não há nenhum evento em andamento.");
		return Plugin_Handled;
	}

	if(client != 0) {
		CPrintToChat(client, CHAT_PREFIX ... "Olhe no console");
	}

	char nome[64];
	evento.GetName(nome, sizeof(nome));
	
	PrintToConsole(client, "===============================");
	PrintToConsole(client, "Lista de participantes do %s:", nome);
	
	for(int i = 1; i <= MaxClients; i++) {
		if(Eventinho_IsParticipating(i)) {
			PrintToConsole(client, "%N", i);
		}
	}
	
	PrintToConsole(client, "===============================");
	
	return Plugin_Handled;
}

stock Action ConCommand_Split(int client, int args)
{
	int count = 1;
	for(int i = 1; i <= MaxClients; i++) {
		if(Eventinho_IsParticipating(i)) {
			if(count % 2 == 0) {
				TeamManager_SetEntityTeam(i, 2, false);
			} else if(count % 2 == 1) {
				TeamManager_SetEntityTeam(i, 3, false);
			}
			count++;
		}
	}

	return Plugin_Handled;
}

stock Action ConCommand_Participando(int client, int args)
{
	if(args < 1) {
		CPrintToChat(client, CHAT_PREFIX ... "Usagem: sm_participando <player>");
		return Plugin_Handled;
	}

	Evento evento = Eventinho_CurrentEvent();
	
	if(!evento) {
		CPrintToChat(client, CHAT_PREFIX ... "Não há nenhum evento em andamento.");
		return Plugin_Handled;
	}

	char nome[64];
	evento.GetName(nome, sizeof(nome));

	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1, false, false);
	if(target == -1) {
		CPrintToChat(client, CHAT_PREFIX ... "Jogador não encontrado.");
		return Plugin_Handled;
	}
	
	if(Eventinho_IsParticipating(target)) {
		CPrintToChat(client, CHAT_PREFIX ... "%N esta participando do %s.", target, nome);
	} else {
		CPrintToChat(client, CHAT_PREFIX ... "%N não esta participando do %s.", target, nome);
	}
	
	return Plugin_Handled;
}

stock void DeletarTime(int client, bool print, int admin)
{
	g_TimeEntrado[client] = -1;
	g_tmpConvidarPlayer[client] = -1;

	if(g_Time[client] == null) {
		return;
	}

	int len = g_Time[client].Length;
	for(int i = 0; i < len; i++) {
		int target = g_Time[client].Get(i);
		if(print) {
			if(admin == -1) {
				CPrintToChat(target, CHAT_PREFIX ... "%N deletou o time.", client);
			} else {
				CPrintToChat(target, CHAT_PREFIX ... "%N forçou o deletamento do time de %N", admin, client);
			}
		}
		g_TimeEntrado[target] = -1;
	}
	delete g_Time[client];
}

stock void SairTime(int client, bool print, int admin)
{
	g_tmpConvidarPlayer[client] = -1;

	if(g_TimeEntrado[client] == -1) {
		return;
	}

	int target = g_TimeEntrado[client];
	g_TimeEntrado[client] = -1;

	if(g_Time[target] == null) {
		return;
	}

	int len = g_Time[target].Length;
	for(int i = 0; i < len; i++) {
		if(g_Time[target].Get(i) == client) {
			g_Time[target].Erase(i);
			if(print) {
				if(admin == -1) {
					CPrintToChat(target, CHAT_PREFIX ... "%N saiu do seu time.", client);
				} else {
					CPrintToChat(target, CHAT_PREFIX ... "%N forçou %N a sair de seu time.", admin, client);
				}
			}
			return;
		}
	}
}

stock void EntrarTime(int client, int target, bool print, int admin)
{
	SairTime(client, print, admin);

	if(g_Time[target] == null) {
		return;
	}

	g_Time[target].Push(client);
	g_TimeEntrado[client] = target;

	if(print) {
		if(admin == -1) {
			CPrintToChat(target, CHAT_PREFIX ... "%N entrou em seu time.", client);
		} else {
			CPrintToChat(target, CHAT_PREFIX ... "%N forçou %N a entrar em seu time.", admin, client);
		}
	}
}

stock int MenuHandler_Convidar(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		int target = g_tmpConvidarPlayer[param1];
		if(param2 == 3) {
			EntrarTime(param1, target, true, -1);
		} else if(param2 == 4) {
			CPrintToChat(target, CHAT_PREFIX ... "%N recusou o seu convite.", param2);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	g_tmpConvidarPlayer[param1] = -1;
	
	return 0;
}

stock int MenuHandler_Entrar(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		int target = g_tmpConvidarPlayer[param1];
		if(param2 == 3) {
			EntrarTime(target, param1, true, -1);
		} else if(param2 == 4) {
			CPrintToChat(param1, CHAT_PREFIX ... "%N recusou o seu convite.", target);
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}

	g_tmpConvidarPlayer[param1] = -1;
	
	return 0;
}

stock Action ConCommand_Time_IMPL_IMPL(int client, int args, bool admin, const char[] nome, char[] arg1, int sizearg1, int selected_player)
{
	if(!Eventinho_IsParticipating(selected_player)) {
		if(!admin) {
			CReplyToCommand(selected_player, CHAT_PREFIX ... "É preciso estar participando do %s", nome);
		} else {
			CReplyToCommand(client, CHAT_PREFIX ... "%N não esta participando do %s", selected_player, nome);
		}
		return Plugin_Handled;
	}

	if(StrEqual(arg1, "deletar")) {
		if(g_Time[selected_player] == null) {
			if(!admin) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "Você não tem um time definido.");
			} else {
				CReplyToCommand(client, CHAT_PREFIX ... "%N não tem um time definido.", selected_player);
			}
			return Plugin_Handled;
		}

		DeletarTime(selected_player, true, admin ? client : -1);

		if(!admin) {
			CReplyToCommand(selected_player, CHAT_PREFIX ... "Time deletado.");
		} else {
			CReplyToCommand(client, CHAT_PREFIX ... "Time de %N deletado.", selected_player);
			CPrintToChat(selected_player, CHAT_PREFIX ... "%N deletou o seu time.", client);
		}
	} else if(StrEqual(arg1, "criar")) {
		if(g_TimeEntrado[selected_player] == selected_player || g_Time[selected_player] != null) {
			if(!admin) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "Você já tem um time definido.");
			} else {
				CReplyToCommand(client, CHAT_PREFIX ... "%N já tem um time definido.", selected_player);
			}
			return Plugin_Handled;
		}

		if(g_TimeEntrado[selected_player] != -1) {
			if(!admin) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "Você já esta participando do time de %N", g_TimeEntrado[selected_player]);
			} else {
				CReplyToCommand(client, CHAT_PREFIX ... "%N já esta participando do time de %N", selected_player, g_TimeEntrado[selected_player]);
			}
			return Plugin_Handled;
		}

		g_Time[selected_player] = new ArrayList();
		g_TimeEntrado[selected_player] = selected_player;

		if(!admin) {
			CReplyToCommand(selected_player, CHAT_PREFIX ... "Time criado.");
		} else {
			CReplyToCommand(client, CHAT_PREFIX ... "Um time para %N foi criado.", selected_player);
			CPrintToChat(selected_player, CHAT_PREFIX ... "%N criou um time para você.", client);
		}
	} else if(StrEqual(arg1, "convidar")) {
		if(!admin) {
			if(g_TimeEntrado[selected_player] != -1 && g_TimeEntrado[selected_player] != selected_player) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "Somente o dono do time (%N) pode convidar outras pessoas.", g_TimeEntrado[selected_player]);
				return Plugin_Handled;
			}
		}

		if(g_Time[selected_player] == null) {
			if(!admin) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "Você não tem um time definido.");
			} else {
				CReplyToCommand(client, CHAT_PREFIX ... "%N não tem um time definido.", selected_player);
			}
			return Plugin_Handled;
		}

		if(!admin) {
			if(args < 2) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "Usagem: sm_time [criar/deletar/convidar/entrar/kick/lista] (player)");
				return Plugin_Handled;
			}
		} else {
			if(args < 3) {
				CReplyToCommand(client, CHAT_PREFIX ... "Usagem: sm_forcetime <player/filter> [criar/deletar/convidar/entrar/kick/lista] (player)");
				return Plugin_Handled;
			}
		}

		if(!admin) {
			GetCmdArg(2, arg1, sizearg1);
		} else {
			GetCmdArg(3, arg1, sizearg1);
		}

		int target = FindTarget(client, arg1, false, false);
		if(target == -1) {
			CReplyToCommand(client, CHAT_PREFIX ... "Jogador não encontrado.");
			return Plugin_Handled;
		}

		if(!admin) {
			if(target == selected_player) {
				CReplyToCommand(client, CHAT_PREFIX ... "Não e possivel convidar a si mesmo.");
				return Plugin_Handled;
			}
		}

		if(!Eventinho_IsParticipating(target)) {
			CReplyToCommand(client, CHAT_PREFIX ... "%N não esta participando do evento %s", target, nome);
			return Plugin_Handled;
		}

		if(g_TimeEntrado[target] != -1) {
			CReplyToCommand(client, CHAT_PREFIX ... "%N ja esta participando de um time.", target);
			return Plugin_Handled;
		}

		if(admin) {
			EntrarTime(target, selected_player, true, admin ? client : -1);
		} else {
			Handle style = GetMenuStyleHandle(MenuStyle_Default);
			Panel menu = CreatePanel(style);
			
			menu.SetTitle("");
			
			menu.DrawItem("", ITEMDRAW_SPACER);

			DrawTextFormated(menu, "%N esta convidando você a entrar no time dele.", selected_player);
			
			menu.DrawItem("", ITEMDRAW_SPACER);

			menu.DrawItem("Aceitar", ITEMDRAW_DEFAULT);
			menu.DrawItem("Recusar", ITEMDRAW_DEFAULT);
			
			menu.CurrentKey = 10;
			menu.DrawItem("Exit", ITEMDRAW_CONTROL);
			
			g_tmpConvidarPlayer[target] = selected_player;
			menu.Send(target, MenuHandler_Convidar, MENU_TIME_FOREVER);
		}
	} else if(StrEqual(arg1, "entrar")) {
		if(!admin) {
			if(args < 2) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "Usagem: sm_time [criar/deletar/convidar/entrar/kick/lista] (player)");
				return Plugin_Handled;
			}

			GetCmdArg(2, arg1, sizearg1);
		} else {
			if(args < 3) {
				CReplyToCommand(client, CHAT_PREFIX ... "Usagem: sm_forcetime <player/filter> [criar/deletar/convidar/entrar/kick/lista] (player)");
				return Plugin_Handled;
			}

			GetCmdArg(3, arg1, sizearg1);
		}

		if(g_Time[selected_player] != null) {
			if(!admin) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "Você já tem o seu próprio time.");
			} else {
				CReplyToCommand(client, CHAT_PREFIX ... "%N já tem o seu proprio time.", selected_player);
			}
			return Plugin_Handled;
		}

		if(g_TimeEntrado[selected_player] != -1) {
			if(!admin) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "Você já esta em um time.");
			} else {
				CReplyToCommand(client, CHAT_PREFIX ... "%N já esta em um time.", selected_player);
			}
			return Plugin_Handled;
		}

		int target = FindTarget(selected_player, arg1, false, false);
		if(target == -1) {
			CReplyToCommand(client, CHAT_PREFIX ... "Jogador não encontrado.");
			return Plugin_Handled;
		}

		if(!Eventinho_IsParticipating(target)) {
			CReplyToCommand(client, CHAT_PREFIX ... "%N não esta participando do evento %s", target, nome);
			return Plugin_Handled;
		}

		if(g_Time[target] == null) {
			CReplyToCommand(client, CHAT_PREFIX ... "%N não tem um time definido.", target);
			return Plugin_Handled;
		}

		if(admin) {
			EntrarTime(selected_player, target, true, admin ? client : -1);
		} else {
			Handle style = GetMenuStyleHandle(MenuStyle_Default);
			Panel menu = CreatePanel(style);
			
			menu.SetTitle("");
			
			menu.DrawItem("", ITEMDRAW_SPACER);

			DrawTextFormated(menu, "%N quer entrar no seu time.", selected_player);
			
			menu.DrawItem("", ITEMDRAW_SPACER);

			menu.DrawItem("Aceitar", ITEMDRAW_DEFAULT);
			menu.DrawItem("Recusar", ITEMDRAW_DEFAULT);
			
			menu.CurrentKey = 10;
			menu.DrawItem("Exit", ITEMDRAW_CONTROL);
			
			g_tmpConvidarPlayer[target] = selected_player;
			menu.Send(target, MenuHandler_Entrar, MENU_TIME_FOREVER);
		}
	} else if(StrEqual(arg1, "sair")) {
		if(g_Time[selected_player] != null) {
			if(!admin) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "Você não esta em um time.");
			} else {
				CReplyToCommand(client, CHAT_PREFIX ... "%N não esta em um time.", selected_player);
			}
			return Plugin_Handled;
		}

		if(g_TimeEntrado[selected_player] == -1 || g_TimeEntrado[selected_player] == selected_player) {
			if(!admin) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "Você não esta em um time.");
			} else {
				CReplyToCommand(client, CHAT_PREFIX ... "%N não esta em um time.", selected_player);
			}
			return Plugin_Handled;
		}

		SairTime(selected_player, true, admin ? client : -1);
	} else if(StrEqual(arg1, "lista")) {
		if(g_Time[selected_player] == null) {
			if(!admin) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "Você não tem um time definido.");
			} else {
				CReplyToCommand(client, CHAT_PREFIX ... "%N não tem um time definido.", selected_player);
			}
			return Plugin_Handled;
		}

		if(client != 0) {
			CPrintToChat(client, CHAT_PREFIX ... "Olhe no console");
		}

		PrintToConsole(client, "===============================");
		PrintToConsole(client, "Lista de membros:");

		int len = g_Time[selected_player].Length;
		for(int i = 0; i < len; i++) {
			int target = g_Time[selected_player].Get(i);
			PrintToConsole(client, "%N", target);
		}
		
		PrintToConsole(client, "===============================");
	} else if(StrEqual(arg1, "kick")) {
		if(g_Time[selected_player] == null) {
			if(!admin) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "Você não tem um time definido.");
			} else {
				CReplyToCommand(client, CHAT_PREFIX ... "%N não tem um time definido.", selected_player);
			}
			return Plugin_Handled;
		}

		if(!admin) {
			if(g_TimeEntrado[selected_player] != -1 && g_TimeEntrado[selected_player] != selected_player) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "Somente o dono do time (%N) pode kickar outras pessoas.", g_TimeEntrado[selected_player]);
				return Plugin_Handled;
			}
		}

		int target = FindTarget(selected_player, arg1, false, false);
		if(target == -1) {
			CReplyToCommand(client, CHAT_PREFIX ... "Jogador não encontrado.");
			return Plugin_Handled;
		}

		if(target == selected_player) {
			CReplyToCommand(client, CHAT_PREFIX ... "%N não e possivel kickar a si mesmo.", target, nome);
			return Plugin_Handled;
		}

		if(g_TimeEntrado[target] != selected_player) {
			if(!admin) {
				CReplyToCommand(selected_player, CHAT_PREFIX ... "%N não esta no seu time.", target);
			} else {
				CReplyToCommand(client, CHAT_PREFIX ... "%N não esta no time de %N", target, selected_player);
			}
			return Plugin_Handled;
		}

		SairTime(target, true, admin ? client : -1);
	}

	return Plugin_Handled;
}

stock Action ConCommand_Time_IMPL(int client, int args, bool admin)
{
	if(!admin) {
		if(client == 0) {
			CReplyToCommand(client, CHAT_PREFIX ... "Você precisa estar presente no jogo.");
			return Plugin_Handled;
		}
	}
	
	Evento evento = Eventinho_CurrentEvent();
	
	if(!evento) {
		CReplyToCommand(client, CHAT_PREFIX ... "Não há nenhum evento em andamento.");
		return Plugin_Handled;
	}

	char nome[64];
	evento.GetName(nome, sizeof(nome));

	if(!admin) {
		if(args < 1) {
			CReplyToCommand(client, CHAT_PREFIX ... "Usagem: sm_time [criar/deletar/convidar/entrar/kick/lista] (player)");
			return Plugin_Handled;
		}
	} else {
		if(args < 2) {
			CReplyToCommand(client, CHAT_PREFIX ... "Usagem: sm_forcetime <player/filter> [criar/deletar/convidar/entrar/kick/lista] (player)");
			return Plugin_Handled;
		}
	}

	char arg1[32];
	if(!admin) {
		GetCmdArg(1, arg1, sizeof(arg1));
	} else {
		GetCmdArg(2, arg1, sizeof(arg1));
	}

	if(admin) {
		char filter[64];
		GetCmdArg(1, filter, sizeof(filter));

		char name[MAX_TARGET_LENGTH];
		int targets[MAXPLAYERS];
		bool isml = false;
		int count = ProcessTargetString(filter, client, targets, MAXPLAYERS, COMMAND_FILTER_ALIVE, name, sizeof(name), isml);
		if(count == 0) {
			ReplyToTargetError(client, count);
			return Plugin_Handled;
		}

		for(int i = 0; i < count; i++) {
			int target = targets[i];

			if(target == client) {
				continue;
			}

			ConCommand_Time_IMPL_IMPL(client, args, admin, nome, arg1, sizeof(arg1), target);
		}
	} else {
		ConCommand_Time_IMPL_IMPL(client, args, admin, nome, arg1, sizeof(arg1), client);
	}

	return Plugin_Handled;
}

stock Action ConCommand_ForcarTime(int client, int args)
{
	return ConCommand_Time_IMPL(client, args, true);
}

stock Action ConCommand_Times(int client, int args)
{
	if(client != 0) {
		CReplyToCommand(client, CHAT_PREFIX ... "Olhe no console");
	}
	
	PrintToConsole(client, "===============================");
	PrintToConsole(client, "Lista de times:");
	
	for(int i = 1; i <= MaxClients; i++) {
		if(g_Time[i] != null) {
			PrintToConsole(client, "%N", i);
		}
	}
	
	PrintToConsole(client, "===============================");

	return Plugin_Handled;
}

stock Action ConCommand_Time(int client, int args)
{
	return ConCommand_Time_IMPL(client, args, false);
}

stock Action ConCommand_Evento(int client, int args)
{
	if(client == 0) {
		CReplyToCommand(client, CHAT_PREFIX ... "Você precisa estar presente no jogo");
		return Plugin_Handled;
	}
	
	Evento evento = Eventinho_CurrentEvent();
	
	if(!evento) {
		CReplyToCommand(client, CHAT_PREFIX ... "Não há nenhum evento em andamento.");
		return Plugin_Handled;
	}

	char nome[64];
	evento.GetName(nome, sizeof(nome));

	if(!Eventinho_IsParticipating(client)) {
		StringMap options = evento.GetOptions();
		
		char value[64];
		if(options.GetString("Preparaçao", value, sizeof(value))) {
			if(!StrEqual(value, "OFF")) {
				EventState state = evento.GetState();
				if(state != EventStartCountdown) {
					CReplyToCommand(client, CHAT_PREFIX ... "Não é possível participar do %s enquanto ele está em andamento.", nome);
					return Plugin_Handled;
				}
			}
		}

		/*
		int team = GetClientTeam(client);

		char out[32];
		if(!TeamSupportsEventEx(evento, team, out, sizeof(out))) {
			int index = GetTeamIndex(out);
			if(index != -1) {
				TeamManager_SetEntityTeam(client, index, false);
				TF2_RespawnPlayer(client);
			} else {
				CReplyToCommand(client, CHAT_PREFIX ... "%s requer que você seja do time %s", nome, out);
				return Plugin_Handled;
			}
		}

		int class = view_as<int>(TF2_GetPlayerClass(client));

		strcopy(out, sizeof(out), "");
		if(!ClassSupportsEventEx(evento, class, out, sizeof(out))) {
			TFClassType needclass = TF2_GetClass(out);
			if(needclass != TFClass_Unknown) {
				TF2_SetPlayerClass(client, needclass, true, true);
				TF2_RespawnPlayer(client);
			} else {
				CReplyToCommand(client, CHAT_PREFIX ... "%s requer que você seja da classe %s", nome, out);
				return Plugin_Handled;
			}
		}*/
	}
	
	Eventinho_Participate(client, !Eventinho_IsParticipating(client));
	
	if(Eventinho_IsParticipating(client)) {
		CReplyToCommand(client, CHAT_PREFIX ... "Agora você é um participante do %s", nome);
		CPrintToChatAll(CHAT_PREFIX ... "%N esta participando do %s. Digite !evento para participar tambem!", client, nome);
	} else {
		CReplyToCommand(client, CHAT_PREFIX ... "Agora você não é mais um participante do %s", nome);
	}
	
	return Plugin_Handled;
}

stock Action ConCommand_ForcarEvento(int client, int args)
{
	if(args != 2) {
		CReplyToCommand(client, CHAT_PREFIX ... "Usagem: sm_forceevento <usuario/filter> <1/0>");
		return Plugin_Handled;
	}
	
	Evento evento = Eventinho_CurrentEvent();
	
	if(!evento) {
		CReplyToCommand(client, CHAT_PREFIX ... "Não há nenhum evento em andamento.");
		return Plugin_Handled;
	}
	
	char filter[64];
	GetCmdArg(1, filter, sizeof(filter));
	
	char value[5];
	GetCmdArg(2, value, sizeof(value));
	
	int intvalue = StringToInt(value);
	
	char name[MAX_TARGET_LENGTH];
	int targets[MAXPLAYERS];
	bool isml = false;
	int count = ProcessTargetString(filter, client, targets, MAXPLAYERS, COMMAND_FILTER_ALIVE, name, sizeof(name), isml);
	if(count == 0) {
		ReplyToTargetError(client, count);
		return Plugin_Handled;
	}

	char nome[64];
	evento.GetName(nome, sizeof(nome));
	
	for(int i = 0; i < count; i++) {
		int target = targets[i];

		bool parti = (intvalue > 0);

		if(parti) {
			CPrintToChat(target, CHAT_PREFIX ... "%N forçou você a participar do %s", client, nome);
		} else {
			CPrintToChat(target, CHAT_PREFIX ... "%N forçou você a não ser um participante do %s", client, nome);
		}
		
		Eventinho_Participate(target, parti);
	}
	
	return Plugin_Handled;
}

stock int MenuHandler_Explain(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		char nome[32];
		menu.GetItem(param2, nome, sizeof(nome));
		
		Evento event = null;
		Eventinho_FindEvento(nome, event);
		
		DisplayExplainEventMenu(param1, event);
		
		delete event;
	} else if(action == MenuAction_End) {
		delete menu;
	}
	
	return 0;
}

stock int MenuHandler_Maps(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		char nome[32];
		menu.GetItem(param2, nome, sizeof(nome));
		
		
	} else if(action == MenuAction_End) {
		delete menu;
	}
	
	return 0;
}

stock void DisplayMapsMenu(int client, Evento event)
{	
	Handle style = GetMenuStyleHandle(MenuStyle_Default);
	
	Panel menu = CreatePanel(style);
	
	char nome[32];
	event.GetName(nome, sizeof(nome));
	
	SetPanelTitleFormated(menu, "%s - Mapas Permitidos", nome);
	
	ArrayList mapas = new ArrayList(64);
	
	for(int i = 0; i < mapas.Length; i++) {
		char map[64];
		mapas.GetString(i, map, sizeof(map));
		
		menu.DrawText(map);
	}
	
	delete mapas;
	
	menu.DrawItem("", ITEMDRAW_SPACER);
	
	menu.CurrentKey = 8;
	menu.DrawItem("Back", ITEMDRAW_CONTROL);
	
	menu.CurrentKey = 10;
	menu.DrawItem("Exit", ITEMDRAW_CONTROL);
	
	menu.Send(client, MenuHandler_Maps, MENU_TIME_FOREVER);
}

stock void DisplayClassMenu(int client, Evento event)
{
	
}

stock void DisplayWeaponsMenu(int client, Evento event)
{
	
}

stock int MenuHandler_ExplainEvent(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select) {
		if(param2 == 8) {
			DisplayExplainMenu(param1);
		} else if(param2 == 10) {
			
		} else {
			char nome[32];
			menu.GetTitle(nome, sizeof(nome));
			
			Evento event = null;
			Eventinho_FindEvento(nome, event);
			
			if(param2 == 4) {
				DisplayMapsMenu(param1, event);
			} else if(param2 == 5) {
				DisplayClassMenu(param1, event);
			} else if(param2 == 6) {
				DisplayWeaponsMenu(param1, event);
			}
			
			delete event;
		}
	} else if(action == MenuAction_End) {
		delete menu;
	}
	
	return 0;
}

stock void DisplayExplainEventMenu(int client, Evento event)
{
	Handle style = GetMenuStyleHandle(MenuStyle_Default);
	
	Panel menu = CreatePanel(style);
	
	char nome[32];
	event.GetName(nome, sizeof(nome));
	
	menu.SetTitle(nome);
	
	char tmp[256];
	
	event.GetDescription(tmp, sizeof(tmp));
	menu.DrawItem("", ITEMDRAW_SPACER);
	menu.DrawText(tmp);
	
	menu.DrawItem("", ITEMDRAW_SPACER);
	
	menu.CurrentKey = 8;
	menu.DrawItem("Back", ITEMDRAW_CONTROL);
	
	menu.CurrentKey = 10;
	menu.DrawItem("Exit", ITEMDRAW_CONTROL);
	
	menu.Send(client, MenuHandler_ExplainEvent, MENU_TIME_FOREVER);
}

stock void DisplayExplainMenu(int client, int item = -1)
{
	Handle style = GetMenuStyleHandle(MenuStyle_Default);
	
	Menu menu = CreateMenuEx(style, MenuHandler_Explain, MENU_ACTIONS_DEFAULT);
	menu.SetTitle("Eventos");
	
	ArrayList eventos = new ArrayList();
	Eventinho_GetAllEvents(eventos);
	
	for(int i = 0; i < eventos.Length; i++) {
		Evento evento = eventos.Get(i);
		
		char nome[32];
		evento.GetName(nome, sizeof(nome));
		
		delete evento;

		menu.AddItem(nome, nome, ITEMDRAW_DEFAULT);
	}
	
	delete eventos;
	
	if(item == -1) {
		menu.Display(client, MENU_TIME_FOREVER);
	} else {
		menu.DisplayAt(client, item, MENU_TIME_FOREVER);
	}
}

stock Action ConCommand_Explain(int client, int args)
{
	if(client == 0) {
		CReplyToCommand(client, CHAT_PREFIX ... "Você precisa estar presente no jogo");
		return Plugin_Handled;
	}
	
	Evento evento = Eventinho_CurrentEvent();
	
	if(!evento) {
		DisplayExplainMenu(client);
	} else {
		DisplayExplainEventMenu(client, evento);
	}
	
	return Plugin_Handled;
}