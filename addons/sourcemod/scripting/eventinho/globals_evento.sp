HTTPClient hApiClient = null;
JSONArray jsonEventos = null;

stock void Evento_Init()
{
	char url[64];
	API_URL.GetString(url, sizeof(url));

	char key[64];
	API_KEY.GetString(key, sizeof(key));

	hApiClient = new HTTPClient(url);
	hApiClient.SetHeader("apikey", key);
	hApiClient.Get("/eventos", RestEventos);
}

stock void RestEventos(HTTPResponse response, any data)
{
	if(response.Status != HTTPStatus_OK) {
		jsonEventos = null;
		int status = view_as<int>(response.Status);
		PrintToServer("[Evento] Falha no API %i", status);
		return;
	}
	
	if(response.Data == null) {
		jsonEventos = null;
		PrintToServer("[Evento] Falha no API");
		return;
	}
	
	if(jsonEventos) {
		delete jsonEventos;
	}
	
	JSONArray tmp = view_as<JSONArray>(response.Data);
	jsonEventos = view_as<JSONArray>(CloneHandle(tmp));
	delete tmp;
}