#if defined __USE_SYSTEM2
System2HTTPRequest hApiClient = null;
#elseif defined __USE_REST_EXT
HTTPClient hApiClient = null;
#endif
JSONArray jsonEventos = null;

stock void Evento_Init()
{
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
	hApiClient = new HTTPClient(url);
	hApiClient.SetHeader("apikey", key);
	hApiClient.Get("/eventos", RestEventos);
#endif
}

#if defined __USE_SYSTEM2
stock void RestEventos(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse r, HTTPRequestMethod method)
#elseif defined __USE_REST_EXT
stock void RestEventos(HTTPResponse response, any data)
#endif
{
#if defined __USE_SYSTEM2
	HTTPResponse response = view_as<HTTPResponse>(r);
#elseif defined __USE_REST_EXT
	char error[1] = "";
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