drop function if exists requests(text,text,jsonb,jsonb,jsonb,jsonb) ;
drop extension if exists "jsonb_plpython3u";
drop extension if exists "plpython3u";
SET search_path TO agoston_private,agoston_public,agoston_api,agoston_identity,agoston_metadata,public;
create extension if not exists "plpython3u";
create extension if not exists "jsonb_plpython3u";

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

