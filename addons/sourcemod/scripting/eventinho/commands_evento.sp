stock void Register_Evento_Commands()
{
	RegAdminCmd("sm_revents", ConCommand_ReloadEventos, ADMFLAG_ROOT);
	RegAdminCmd("sm_levents", ConCommand_ListaEventos, ADMFLAG_ROOT);
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