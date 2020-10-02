#if defined __USE_SYSTEM2
#define HTTPStatus_OK 200

methodmap HTTPResponse < System2HTTPResponse
{
	property int Status
	{
		public get()
		{ return this.StatusCode; }
	}
	
	property Handle Data
	{
		public get()
		{
		#if defined __USE_SMJANSSON
			int len = this.ContentLength;
			len++;
			char[] body = new char[len];
			
			this.GetContent(body, len);
			
			return json_load(body);
		#endif
		}
	}
}
#endif

#if defined __USE_SMJANSSON
methodmap JSONObject < Handle
{
	public void GetString(const char[] name, char[] value, int len)
	{ json_object_get_string(this, name, value, len); }
	
	public Handle Get(const char[] name)
	{ return json_object_get(this, name); }
	
	public void SetInt(const char[] name, int value)
	{
		Handle obj = json_object_get(this, name);
		json_integer_set(obj, value);
		delete obj;
	}
	
	public int GetInt(const char[] name)
	{ return json_object_get_int(this, name); }
}

methodmap JSONArray < Handle
{
	public Handle Get(int i)
	{ return json_array_get(this, i); }
	
	public void GetString(int i, char[] value, int len)
	{
		Handle obj = json_array_get(this, i);
		json_string_value(obj, value, len);
		delete obj;
	}
	
	property int Length
	{
		public get()
		{ return json_array_size(this); }
	}
}
#endif