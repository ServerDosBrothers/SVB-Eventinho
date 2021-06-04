stock void Register_Evento_Commands()
{
	RegAdminCmd("sm_revents", ConCommand_ReloadEventos, ADMFLAG_ROOT);
	RegAdminCmd("sm_levents", ConCommand_ListaEventos, ADMFLAG_ROOT);
	RegAdminCmd("sm_dump_events", ConCommand_DumpEventos, ADMFLAG_ROOT);
	RegAdminCmd("sm_dump_events_desc", ConCommand_DumpEventosDesc, ADMFLAG_ROOT);
}

stock Action ConCommand_ListaEventos(int client, int args)
{
	if(client != 0) {
		CPrintToChat(client, CHAT_PREFIX ... "olhe no console");
	}
	
	ArrayList list = new ArrayList();
	Eventinho_GetAllEvents(list);
	
	PrintToConsole(client, "===============================");
	PrintToConsole(client, "Lista de eventos:");
	
	for(int i = 0; i < list.Length; i++) {
		Evento evento = view_as<Evento>(list.Get(i));
		
		char nome[64];
		evento.GetName(nome, sizeof(nome));
		
		delete evento;
		
		PrintToConsole(client, "%s", nome);
	}
	
	PrintToConsole(client, "===============================");
	
	delete list;
	
	return Plugin_Handled;
}

stock Action ConCommand_ReloadEventos(int client, int args)
{
	Evento_Init();
	
	return Plugin_Handled;
}

stock Action ConCommand_DumpEventosDesc(int client, int args)
{
	ArrayList eventos = new ArrayList();
	Eventinho_GetAllEvents(eventos);

	int len1 = eventos.Length;
	char tmpstr[2048];
	for(int i = 0; i < len1; ++i) {
		Evento evento = eventos.Get(i);

		evento.GetName(tmpstr, sizeof(tmpstr));
		PrintToConsole(client, "%s:", tmpstr);

		evento.GetDescription(tmpstr, sizeof(tmpstr));
		ReplaceString(tmpstr, sizeof(tmpstr), "\n", "\\n");
		PrintToConsole(client, "%s", tmpstr);

		delete evento;
	}

	delete eventos;

	return Plugin_Handled;
}

stock Action ConCommand_DumpEventos(int client, int args)
{
	ArrayList eventos = new ArrayList();
	Eventinho_GetAllEvents(eventos);

	PrintToConsole(client, "backend:");
#if defined __USE_REST_EXT
	#if defined __OLD_REST_EXT
	PrintToConsole(client, "  using RIPext old version");
	#else
	PrintToConsole(client, "  using RIPext new version");
	#endif
#elseif defined __USE_SYSTEM2
	PrintToConsole(client, "  using system2 + SMJansson");
#elseif defined __USE_KEYVALUES
	PrintToConsole(client, "  using keyvalues");
#else
	#error
#endif

	int len1 = eventos.Length;
	char tmpstr[64];
	char tmpstr2[64];
	for(int i = 0; i < len1; ++i) {
		Evento evento = eventos.Get(i);

		evento.GetName(tmpstr, sizeof(tmpstr));
		PrintToConsole(client, "%s: {", tmpstr);

		evento.GetDescription(tmpstr, sizeof(tmpstr));
		ReplaceString(tmpstr, sizeof(tmpstr), "\n", "\\n");
		PrintToConsole(client, "  desc: %s", tmpstr);

		ArrayList cmdstart = new ArrayList();
		evento.GetStartCommands(cmdstart);

		PrintToConsole(client, "  cmd start: [");
		int len2 = cmdstart.Length;
		for(int j = 0; j < len2; ++j) {
			EventCommand cmd = cmdstart.Get(j);

			cmd.GetName(tmpstr, sizeof(tmpstr));
			cmd.GetValue(tmpstr2, sizeof(tmpstr2));
			PrintToConsole(client, "    %s %s", tmpstr, tmpstr2);

			delete cmd;
		}

		PrintToConsole(client, "  ]");

		delete cmdstart;

		cmdstart = new ArrayList();
		evento.GetEndCommands(cmdstart);

		PrintToConsole(client, "  cmd end: [");
		len2 = cmdstart.Length;
		for(int j = 0; j < len2; ++j) {
			EventCommand cmd = cmdstart.Get(j);

			cmd.GetName(tmpstr, sizeof(tmpstr));
			cmd.GetValue(tmpstr2, sizeof(tmpstr2));
			PrintToConsole(client, "    %s %s", tmpstr, tmpstr2);

			delete cmd;
		}

		PrintToConsole(client, "  ]");

		delete cmdstart;

		cmdstart = new ArrayList();
		evento.GetRequirements(cmdstart);

		PrintToConsole(client, "  requirements: {");
		len2 = cmdstart.Length;
		for(int j = 0; j < len2; ++j) {
			EventRequirement cmd = cmdstart.Get(j);

			switch(cmd.GetType()) {
				case ReqBlacklistMaps: { PrintToConsole(client, "    type: blacklist_maps"); }
				case ReqWhitelistMaps: { PrintToConsole(client, "    type: whitelist_maps"); }
				case ReqPlayerTeam: { PrintToConsole(client, "    type: player_team"); }
				case ReqPlayerClass: { PrintToConsole(client, "    type: player_class"); }
			}

			PrintToConsole(client, "    values: [");

			ArrayList values = new ArrayList();
			cmd.GetValues(values);

			int len3 = values.Length;
			for(int k = 0; k < len3; ++k) {
				values.GetString(k, tmpstr, sizeof(tmpstr));
				PrintToConsole(client, "      %s", tmpstr);
			}

			PrintToConsole(client, "    ]");

			delete values;

			delete cmd;
		}

		PrintToConsole(client, "  }");

		delete cmdstart;

		cmdstart = new ArrayList();
		evento.GetRewards(cmdstart);

		PrintToConsole(client, "  rewards: {");
		len2 = cmdstart.Length;
		for(int j = 0; j < len2; ++j) {
			EventReward cmd = cmdstart.Get(j);

			PrintToConsole(client, "    id: %i", cmd.GetItemID());

			cmd.GetModel(tmpstr, sizeof(tmpstr));
			PrintToConsole(client, "    model: %s", tmpstr);

			PrintToConsole(client, "    attributes: [", tmpstr);

			ArrayList attributes = new ArrayList();
			cmd.GetAttributes(attributes);

			int len3 = attributes.Length;
			for(int k = 0; k < len3; ++k) {
				EventRewardAttribute attr = attributes.Get(k);

				PrintToConsole(client, "      %i %f", attr.GetID(), attr.GetValue());

				delete attr;
			}

			PrintToConsole(client, "    ]");

			delete attributes;

			delete cmd;
		}

		PrintToConsole(client, "  }");

		delete cmdstart;

		delete evento;

		PrintToConsole(client, "}");
	}

	delete eventos;

	return Plugin_Handled;
}