drop function if exists requests(text,text,jsonb,jsonb,jsonb,jsonb) ;
drop extension if exists "jsonb_plpython3u";
drop extension if exists "plpython3u";
set search_path to agoston_api;
create extension if not exists "plpython3u";
create extension if not exists "jsonb_plpython3u";
set search_path to agoston_private,agoston_public,agoston_api,agoston_identity,agoston_metadata,public;

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

---------
drop function if exists agoston_api.apply_auto_subscription();
drop event trigger auto_subscription;
create or replace function agoston_api.auto_subscription()
  returns event_trigger
 language plpgsql
  as $$
declare
  d_object_type text;
  d_schema_name text;
  d_table_name text;
begin
  select  lower(object_type), lower(schema_name), lower(split_part(object_identity, '.', 2))
  into    d_object_type, d_schema_name, d_table_name
  from    pg_event_trigger_ddl_commands();
  if d_object_type = 'table' and d_schema_name in ('agoston_public', 'agoston_private') then
    execute format(
      'create or replace trigger %s after insert or update or delete or truncate on %s.%s for each statement execute function agoston_api.graphql_subscription();',
      'trgsub_'||d_table_name, d_schema_name, d_table_name
    );
    raise notice
      E'Trigger % for auto subscription created.\nDrop it if you don''t need GraphQL subscription for this table: \n > drop trigger % on %.%;',
     'trgsub_'||d_table_name, 'trgsub_'||d_table_name, d_schema_name, d_table_name;
  end if;
end;
$$;

create event trigger auto_subscription
on ddl_command_end
when tag in ('CREATE TABLE')
execute function agoston_api.auto_subscription();

