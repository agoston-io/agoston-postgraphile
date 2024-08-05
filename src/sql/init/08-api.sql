CREATE OR REPLACE FUNCTION agoston_api.graphql_subscription ()
  RETURNS TRIGGER
  AS $$
DECLARE
  v_topic text;
  v_sub text;
  v_record record;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_record = new;
  elsif TG_OP = 'UPDATE' THEN
    v_record = new;
  elsif TG_OP = 'DELETE' THEN
    v_record = old;
  END IF;
  IF TG_ARGV[0] IS NOT NULL THEN
    EXECUTE 'select $1.' || quote_ident(TG_ARGV[0])
    USING v_record INTO v_sub;
    v_topic = lower(TG_TABLE_NAME || ':' || TG_ARGV[0] || ':' || v_sub);
  ELSE
    v_topic = lower(TG_TABLE_NAME);
  END IF;
    IF v_topic IS NOT NULL THEN
      PERFORM
        pg_notify('postgraphile:' || v_topic, json_build_object('event', TG_OP, 'topic', v_topic)::text);
    END IF;
    RETURN v_record;
END;
$$ LANGUAGE plpgsql VOLATILE SET search_path FROM CURRENT;

-- Automatic subscription for all new table created
CREATE OR REPLACE FUNCTION agoston_api.auto_subscription()
  RETURNS event_trigger
 LANGUAGE plpgsql
  AS $$
DECLARE
  d_object_type text;
  d_schema_name text;
  d_table_name text;
BEGIN
  SELECT  lower(object_type), lower(schema_name), lower(objid::regclass::text)
  into    d_object_type, d_schema_name, d_table_name
  FROM    pg_event_trigger_ddl_commands();
  if d_object_type = 'table' and d_schema_name = 'agoston_public' then
    execute format('create or replace trigger %I after insert or update or delete or truncate on %I for each statement execute function agoston_api.graphql_subscription();', 'trgsub_'||d_table_name, d_table_name);
    RAISE NOTICE 'Trigger % for auto subscription created', 'TRGSUB_'||d_table_name;
  end if;
END;
$$;
CREATE EVENT TRIGGER auto_subscription ON ddl_command_end EXECUTE FUNCTION agoston_api.auto_subscription();

-- Requests API
---- select agoston_api.requests('GET', url:='https://httpbin.org/get', headers:='{"header1":"val1"}', http_basic_auth:='{"user":"val1", "password":"val1"}');
---- select agoston_api.requests('GET', url:='https://httpbin.org/get', headers:='{"header1":"val1"}', params:='{"param1":"val1"}', data:='{"param1":"val1"}');
---- select agoston_api.requests('POST', url:='https://httpbin.org/post', headers:='{"header1":"val1"}',params:='{"param1":"val1"}', data:='{"param1":"val1"}');
---- select agoston_api.requests('PUT', url:='https://httpbin.org/put', headers:='{"header1":"val1"}',params:='{"param1":"val1"}', data:='{"param1":"val1"}');
---- select agoston_api.requests('PATCH', url:='https://httpbin.org/patch', headers:='{"header1":"val1"}',params:='{"param1":"val1"}', data:='{"param1":"val1"}');
---- select agoston_api.requests('DELETE', url:='https://httpbin.org/delete', headers:='{"header1":"val1"}',params:='{"param1":"val1"}', data:='{"param1":"val1"}');
CREATE OR REPLACE FUNCTION agoston_api.requests (
  method text DEFAULT 'GET',
  url text DEFAULT 'https://api.github.com',
  headers jsonb DEFAULT '{}'::jsonb,
  params jsonb DEFAULT '{}'::jsonb,
  payload jsonb DEFAULT '{}'::jsonb,
  http_basic_auth jsonb DEFAULT null
)
  RETURNS jsonb
  TRANSFORM FOR TYPE jsonb
  LANGUAGE plpython3u
  AS $$
  import requests
  import json
  v_headers = headers
  v_params = params
  v_payload = payload
  v_timeout = 5
  plpy.notice('url => {} => {}'.format(type(url), url))
  plpy.notice('method => {} => {}'.format(type(method), method))
  plpy.notice('headers => {} => {}'.format(type(headers), headers))
  plpy.notice('params => {} => {}'.format(type(v_params), v_params))
  plpy.notice('payload => {} => {}'.format(type(payload), payload))
  plpy.notice('v_timeout => {}'.format(v_timeout))

  request_auth = None
  if http_basic_auth is not None:
    v_http_basic_auth = http_basic_auth
    plpy.notice('http_basic_auth => {}'.format(v_http_basic_auth))
    from requests.auth import HTTPBasicAuth
    request_auth = HTTPBasicAuth(v_http_basic_auth['user'], v_http_basic_auth['password'])

  if method == 'GET':
    response = requests.get(url=url, headers=v_headers, params=v_params, auth=request_auth, json=v_payload, timeout=v_timeout)
    v_return = {
      'status_code': response.status_code,
      'encoding': response.encoding,
      'headers': dict(response.headers),
      'output': response.json()
    }
  elif method == 'POST':
    response = requests.post(url=url, headers=v_headers, params=v_params, auth=request_auth, json=v_payload, timeout=v_timeout)
    v_return = {
      'status_code': response.status_code,
      'encoding': response.encoding,
      'headers': dict(response.headers),
      'output': response.json()
    }
  elif method == 'PUT':
    response = requests.put(url=url, headers=v_headers, params=v_params, auth=request_auth, json=v_payload, timeout=v_timeout)
    v_return = {
      'status_code': response.status_code,
      'encoding': response.encoding,
      'headers': dict(response.headers),
      'output': response.json()
    }
  elif method == 'PATCH':
    response = requests.patch(url=url, headers=v_headers, params=v_params, auth=request_auth, json=v_payload, timeout=v_timeout)
    v_return = {
      'status_code': response.status_code,
      'encoding': response.encoding,
      'headers': dict(response.headers),
      'output': response.json()
    }
  elif method == 'DELETE':
    response = requests.delete(url=url, headers=v_headers, params=v_params, auth=request_auth, json=v_payload, timeout=v_timeout)
    v_return = {
      'status_code': response.status_code,
      'encoding': response.encoding,
      'headers': dict(response.headers)
    }
  else:
    raise Exception("method '{}' not supported".format(method))

  return v_return;
$$;
