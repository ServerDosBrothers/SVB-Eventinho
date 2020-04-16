HTTPClient hApiClient = null;
JSONArray jsonEventos = null;

stock void Evento_Init()
{
	hApiClient = new HTTPClient(API_URL);
	hApiClient.SetHeader("apikey", API_KEY);
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