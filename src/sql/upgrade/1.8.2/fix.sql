CREATE OR REPLACE FUNCTION agoston_api.add_user_role ( p_role_name text )
    RETURNS int
    SECURITY DEFINER
    AS $$
DECLARE
    v_role_id int;
BEGIN
    if exists (select * from agoston_identity.user_roles where name = p_role_name) then
		raise exception 'Role (name=''%'') already exist.', p_role_name;
	end if;
    if not p_role_name ~ '^[a-zA-Z][a-zA-Z_]*[a-zA-Z]$' then
		raise exception 'Role name can only contain letters and optional underscores in the middle.';
	end if;
    insert into agoston_identity.user_roles (name) values (lower(p_role_name)) returning id into v_role_id;
    execute 'create role ' || p_role_name || ' with nologin';
    execute 'grant usage on schema agoston_public to ' || p_role_name;
    execute 'grant usage on schema public to ' || p_role_name;
    execute 'grant usage on schema agoston_api to ' || p_role_name;
    execute 'grant usage on schema agoston_identity to ' || p_role_name;
    execute 'grant usage on schema cron to ' || p_role_name;
    execute 'grant ' || p_role_name || ' to ##DEVELOPER_USER##';
    execute 'grant ' || p_role_name || ' to ##POSTGRAPHILE_USER##';
    return v_role_id;
end;
$$
language plpgsql;
