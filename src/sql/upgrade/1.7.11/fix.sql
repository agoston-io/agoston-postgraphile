DROP FUNCTION agoston_api.add_user_role;
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
    execute 'grant ' || p_role_name || ' to ##POSTGRAPHILE_USER##';
    return v_role_id;
end;
$$
language plpgsql;

------------

CREATE OR REPLACE FUNCTION agoston_api.delete_user_role ( p_role_id int )
    RETURNS boolean
    SECURITY DEFINER
    AS $$
DECLARE
    p_role_name text default null;
BEGIN
    select name into p_role_name from agoston_identity.user_roles where id = p_role_id;
    if p_role_name is null then
        raise exception 'Role (id=''%'') does not exist.', p_role_id;
	end if;
    execute 'revoke usage on schema agoston_public from ' || p_role_name;
    execute 'revoke ' || p_role_name || ' from ##POSTGRAPHILE_USER##';
    execute 'drop role ' || p_role_name;
    delete from agoston_identity.user_roles where id = p_role_id;
    return true;
END;
$$
LANGUAGE plpgsql;

------------

CREATE OR REPLACE FUNCTION agoston_api.delete_user (p_user_id int DEFAULT NULL)
    RETURNS boolean
    AS $$
BEGIN
    if not exists (select * from agoston_identity.user_identities where id = p_user_id) then
		raise exception 'User (id=''%'') does not exist.', p_user_id;
	end if;
    if p_user_id = 0 then
		raise exception 'Cannot delete user 0 (used internally by Agoston).';
	end if;
    delete from agoston_identity.user_identities
        where id = p_user_id;
    return true;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION agoston_api.delete_user OWNER TO ##POSTGRAPHILE_USER##;

------------

CREATE OR REPLACE FUNCTION agoston_api.set_default_role_id_when_anonymous (p_role_id int)
    RETURNS boolean
    SECURITY DEFINER
    AS $$
BEGIN
    if not exists (select * from agoston_identity.user_roles where id = p_role_id) then
		raise exception 'Role (id=''%'') does not exist.', p_role_id;
	end if;
    update agoston_identity.user_roles set is_anonymous_default = false ;
    update agoston_identity.user_roles set is_anonymous_default = true where id = p_role_id;
    update agoston_identity.user_identities set user_role_id = p_role_id where id = 0;
    return true;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION agoston_api.set_default_role_id_when_anonymous OWNER TO ##POSTGRAPHILE_USER##;

------------

CREATE OR REPLACE FUNCTION agoston_api.rename_user_role ( p_role_id int, p_new_role_name text )
    RETURNS boolean
    SECURITY DEFINER
    AS $$
DECLARE
    p_role_name text default null;
BEGIN
    select name into p_role_name from agoston_identity.user_roles where id = p_role_id;
    if p_role_name is null then
        raise exception 'Role (id=''%'') does not exist.', p_role_id;
	end if;
    if not p_new_role_name ~ '^[a-zA-Z][a-zA-Z_]*[a-zA-Z]$' then
		raise exception 'Role name can only contain letters and optional underscores in the middle.';
	end if;
    if p_role_name = p_new_role_name then
        return false;
    end if;
    update agoston_identity.user_roles set name = p_new_role_name where id = p_role_id;
    execute 'alter role ' || p_role_name || ' rename to ' || p_new_role_name ;
    return true;
END;
$$
LANGUAGE plpgsql;

--------------

CREATE OR REPLACE FUNCTION agoston_api.get_default_role_id_when_authenticated ()
    RETURNS integer
    SECURITY DEFINER
    AS $$
DECLARE
    default_role_id integer;
BEGIN
    if not exists (select * from agoston_identity.user_roles where is_authenticated_default = TRUE) then
		raise exception 'No default role set for authenticated users.';
	end if;
    SELECT
        min(id) INTO default_role_id
    FROM
        agoston_identity.user_roles
    WHERE
        is_authenticated_default = TRUE;
    RETURN default_role_id;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION agoston_api.get_default_role_id_when_authenticated OWNER TO ##POSTGRAPHILE_USER##;
