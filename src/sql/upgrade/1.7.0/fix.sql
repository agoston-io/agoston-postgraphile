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
    return true;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION agoston_api.set_default_role_id_when_anonymous OWNER TO ##POSTGRAPHILE_USER##;

-----------------------------

CREATE OR REPLACE FUNCTION agoston_api.set_default_role_id_when_authenticated (p_role_id int)
    RETURNS boolean
    SECURITY DEFINER
    AS $$
BEGIN
    if not exists (select * from agoston_identity.user_roles where id = p_role_id) then
		raise exception 'Role (id=''%'') does not exist.', p_role_id;
	end if;
    update agoston_identity.user_roles set is_authenticated_default = false ;
    update agoston_identity.user_roles set is_authenticated_default = true where id = p_role_id;
    return true;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION agoston_api.set_default_role_id_when_authenticated OWNER TO ##POSTGRAPHILE_USER##;

-----------------------------

alter table agoston_identity.user_roles
    rename column is_authenticated_default to is_anonymous_default;

alter table agoston_identity.user_roles
    add column is_authenticated_default boolean not null default false;

update agoston_identity.user_roles
    set is_authenticated_default = is_anonymous_default;

select agoston_api.set_default_role_id_when_anonymous(1) ;
select agoston_api.set_default_role_id_when_authenticated(2) ;

-----------------------------

CREATE OR REPLACE FUNCTION agoston_public.get_session_id ()
    RETURNS text
    AS $$
    SELECT
        current_setting('session_id', TRUE)::text;

$$
LANGUAGE sql
STABLE;

-----------------------------
DROP FUNCTION agoston_api.add_user(p_user_role_id integer);

CREATE OR REPLACE FUNCTION agoston_api.add_user (p_role_id int DEFAULT NULL)
    RETURNS int
    AS $$
DECLARE
    v_user_id integer := NULL;
BEGIN
    if p_role_id is not null then
        if not exists (select * from agoston_identity.user_roles where id = p_role_id) then
            raise exception 'Role (id=''%'') does not exist.', p_role_id;
        end if;
    end if;
    INSERT INTO agoston_identity.user_identities (user_role_id)
        VALUES (coalesce(p_role_id, agoston_api.get_default_role_id_when_authenticated ()))
    RETURNING
        id INTO v_user_id;
    RETURN v_user_id;
END;
$$
LANGUAGE plpgsql;

ALTER FUNCTION agoston_api.add_user OWNER TO ##POSTGRAPHILE_USER##;

-----------------------------

DROP FUNCTION agoston_api.set_user_token (p_user_uuid uuid);

CREATE OR REPLACE FUNCTION agoston_api.set_user_token (p_user_id int DEFAULT NULL)
    RETURNS text
    AS $$
DECLARE
    v_token text;
    v_token_chars text := 'abcdefghjklmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ0123456789';
BEGIN
    if not exists (select * from agoston_identity.user_identities where id = p_user_id) then
		raise exception 'User (id=''%'') does not exist.', p_user_id;
	end if;
    SELECT
        array_to_string(ARRAY ((
                SELECT
                    substring(v_token_chars
                    FROM mod((random() * 62)::int, 62) + 1 FOR 1)
    FROM generate_series(1, 128))), '') INTO v_token;
    UPDATE
        agoston_identity.user_identities
    SET
        hashed_token = public.crypt(v_token, public.gen_salt('md5'))
    WHERE
        id = p_user_id;
    RETURN v_token;
END;
$$
LANGUAGE plpgsql;

ALTER FUNCTION agoston_api.set_user_token OWNER TO ##POSTGRAPHILE_USER##;

-----------------------------

DROP FUNCTION agoston_api.delete_user (p_user_id int, p_user_uuid uuid);

CREATE OR REPLACE FUNCTION agoston_api.delete_user (p_user_id int DEFAULT NULL)
    RETURNS boolean
    AS $$
BEGIN
    if not exists (select * from agoston_identity.user_identities where id = p_user_id) then
		raise exception 'User (id=''%'') does not exist.', p_user_id;
	end if;
    delete from agoston_identity.user_identities
        where id = p_user_id;
    return true;
END;
$$
LANGUAGE plpgsql;

ALTER FUNCTION agoston_api.delete_user OWNER TO ##POSTGRAPHILE_USER##;

-----------------------------

alter function get_default_authenticated_role rename to get_default_role_id_when_authenticated;

CREATE OR REPLACE FUNCTION agoston_api.get_default_role_id_when_authenticated ()
    RETURNS integer
    SECURITY DEFINER
    AS $$
DECLARE
    default_role_id integer;
BEGIN
    if not exists (select * from agoston_identity.user_roles where is_anonymous_default = TRUE) then
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

-----------------------------

CREATE OR REPLACE FUNCTION agoston_api.get_default_role_id_when_anonymous ()
    RETURNS integer
    SECURITY DEFINER
    AS $$
DECLARE
    default_role_id integer;
BEGIN
    if not exists (select * from agoston_identity.user_roles where is_anonymous_default = TRUE) then
		raise exception 'No default role set for anonymous users.';
	end if;
    SELECT
        min(id) INTO default_role_id
    FROM
        agoston_identity.user_roles
    WHERE
        is_anonymous_default = TRUE;
    RETURN default_role_id;
END;
$$
LANGUAGE plpgsql;

ALTER FUNCTION agoston_api.get_default_role_id_when_anonymous OWNER TO ##POSTGRAPHILE_USER##;

-----------------------------

CREATE OR REPLACE FUNCTION agoston_public.session (
	)
    RETURNS jsonb
    LANGUAGE 'sql'
    COST 100
    STABLE PARALLEL UNSAFE
AS
$BODY$
    select jsonb_build_object(
      'role', current_user,
      'is_authenticated', current_setting('session.is_authenticated', true)::boolean,
      'user_id', current_setting('session.user_id', true)::int,
      'session_id', current_setting('session.id', true)::text
    );
$BODY$;

-----------------------------

DROP FUNCTION agoston_api.add_user_role;
CREATE OR REPLACE FUNCTION agoston_api.add_user_role (
    p_role_name text,
    p_is_anonymous_default boolean DEFAULT FALSE,
    p_is_authenticated_default boolean DEFAULT FALSE
    )
    RETURNS boolean
    SECURITY DEFINER
    AS $$
DECLARE
    v_count int;
    v_return boolean default false;
BEGIN
    /* WARNING! This function must be/remain idempotent */
    IF p_role_name ~ '^[a-zA-Z][a-zA-Z_]*[a-zA-Z]$' THEN
        INSERT INTO agoston_identity.user_roles (name, is_anonymous_default, is_authenticated_default)
            VALUES (lower(p_role_name), p_is_anonymous_default, p_is_authenticated_default)
        ON CONFLICT
            DO NOTHING;
        IF EXISTS (
            SELECT
            FROM
                pg_catalog.pg_roles
            WHERE
                lower(rolname) = lower(p_role_name)) THEN
            RAISE NOTICE 'role "%" already exists. skipping.', p_role_name;
            v_return := FALSE;
        ELSE
            EXECUTE 'create role ' || p_role_name || ' with nologin';
            v_return := TRUE;
        END IF;
        EXECUTE 'grant usage on schema agoston_public to ' || p_role_name;
        EXECUTE 'grant ' || p_role_name || ' to ##POSTGRAPHILE_USER##';
        RETURN v_return;
    END IF;
    RAISE EXCEPTION 'Role names can only contain letters.';
END;
$$
LANGUAGE plpgsql;

-----------------------------

alter table agoston_identity.user_identities drop column uuid;

-----------------------------

CREATE OR REPLACE FUNCTION agoston_api.set_user_role (p_user_id int DEFAULT NULL, p_role_id int DEFAULT NULL)
    RETURNS boolean
    AS $$
BEGIN
    if not exists (select * from agoston_identity.user_roles where id = p_role_id) then
        raise exception 'Role (id=''%'') does not exist.', p_role_id;
	end if;
    if not exists (select * from agoston_identity.user_identities where id = p_user_id) then
		raise exception 'User (id=''%'') does not exist.', p_user_id;
	end if;
    UPDATE
        agoston_identity.user_identities
    SET
        user_role_id = p_role_id
    WHERE
        id = p_user_id;
    RETURN true;
END;
$$
LANGUAGE plpgsql;

ALTER FUNCTION agoston_api.set_user_role OWNER TO ##POSTGRAPHILE_USER##;
