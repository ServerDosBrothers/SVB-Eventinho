#if defined __USE_SYSTEM2
System2HTTPRequest hApiClient = null;
#elseif defined __USE_REST_EXT
#if defined __OLD_REST_EXT
HTTPClient hApiClient = null;
#else
HTTPRequest hApiClient = null;
#endif
#endif

#if defined __USING_API
JSONArray jsonEventos = null;
#elseif defined __USE_KEYVALUES
KeyValues kvEventos = null;
StringMap EventoMap = null;
int defaultid = -1;
#endif

stock void Evento_Init()
{
#if defined __USING_API
	char url[64];
	API_URL.GetString(url, sizeof(url));

	char key[64];
	API_KEY.GetString(key, sizeof(key));

	delete hApiClient;
	delete jsonEventos;

	#if defined __USE_SYSTEM2
	char tmpurl[64];
	System2_URLEncode(tmpurl, sizeof(tmpurl), "%s/eventos", url);
	hApiClient = new System2HTTPRequest(RestEventos, tmpurl);
	hApiClient.SetHeader("apikey", key);
	hApiClient.GET();
	#elseif defined __USE_REST_EXT
		#if defined __OLD_REST_EXT
	hApiClient = new HTTPClient(url);
	hApiClient.SetHeader("apikey", key);
	hApiClient.Get("/eventos", RestEventos);
		#else
	char tmpurl[64];
	Format(tmpurl, sizeof(tmpurl), "%s/eventos", url);
	hApiClient = new HTTPRequest(tmpurl);
	hApiClient.SetHeader("apikey", key);
	hApiClient.Get(RestEventos);
		#endif
	#endif
#elseif defined __USE_KEYVALUES
	char eventosfile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, eventosfile, sizeof(eventosfile), "data/eventos.txt");

	if(FileExists(eventosfile, true)) {
		kvEventos = new KeyValues("Eventos");
		kvEventos.ImportFromFile(eventosfile);

		if(kvEventos.GotoFirstSubKey()) {
			EventoMap = new StringMap();

			char tmpname[64];
			do {
				kvEventos.GetSectionName(tmpname, sizeof(tmpname));

				int id = -1;
				if(kvEventos.GetSectionSymbol(id)) {
					if(StrEqual(tmpname, "##default##")) {
						defaultid = id;
					} else {
						EventoMap.SetValue(tmpname, id);
					}
				}
			} while(kvEventos.GotoNextKey());

			kvEventos.GoBack();
		}
	}
#endif
}

#if defined __USING_API
	#if defined __USE_SYSTEM2
stock void RestEventos(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse r, HTTPRequestMethod method)
	#elseif defined __USE_REST_EXT
stock void RestEventos(HTTPResponse response, any data, const char[] error)
	#endif
{
	#if defined __USE_SYSTEM2
	HTTPResponse response = view_as<HTTPResponse>(r);
	#endif
	
	delete jsonEventos;
	
	if(response.Status != HTTPStatus_OK) {
		int status = view_as<int>(response.Status);
		PrintToServer("[Evento] Falha no API %i %s", status, error);
		return;
	}
	
	JSONArray tmp = view_as<JSONArray>(response.Data);
	if(tmp == null) {
		PrintToServer("[Evento] Falha no API %s", error);
		return;
	}
	
	jsonEventos = view_as<JSONArray>(CloneHandle(tmp));
	delete tmp;
}
#endif