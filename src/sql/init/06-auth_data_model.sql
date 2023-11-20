CREATE TABLE agoston_identity.federated_credentials (
    id serial PRIMARY KEY,
    provider text NOT NULL,
    subject text NOT NULL,
    raw jsonb NOT NULL DEFAULT '{}',
    UNIQUE (provider, subject)
);

CREATE INDEX idx_federated_credentials_01 ON agoston_identity.federated_credentials (subject, provider);

ALTER TABLE agoston_identity.federated_credentials OWNER TO "##POSTGRAPHILE_USER##";

GRANT SELECT, INSERT, DELETE, UPDATE, TRUNCATE, REFERENCES, TRIGGER ON agoston_identity.federated_credentials TO "##DEVELOPER_USER##";

CREATE TABLE agoston_identity.user_roles (
    id int PRIMARY KEY,
    name text NOT NULL UNIQUE
);

ALTER TABLE agoston_identity.user_roles OWNER TO "##POSTGRAPHILE_USER##";
GRANT SELECT, REFERENCES, TRIGGER ON agoston_identity.user_roles TO "##DEVELOPER_USER##";

--
CREATE TABLE agoston_identity.user_identities (
    id serial PRIMARY KEY,
    user_role_id int NOT NULL DEFAULT 2,
    federated_credential_id int,
    hashed_password text,
    hashed_token text,
    UNIQUE (id, user_role_id),
    CONSTRAINT user_identities_user_role_id FOREIGN KEY (user_role_id) REFERENCES agoston_identity.user_roles (id),
    CONSTRAINT user_identities_federated_credential_id FOREIGN KEY (federated_credential_id) REFERENCES agoston_identity.federated_credentials (id)
);
CREATE INDEX hashed_token_idx_01 ON agoston_identity.user_identities (id);

ALTER TABLE agoston_identity.user_identities OWNER TO "##POSTGRAPHILE_USER##";

GRANT SELECT, INSERT, DELETE, UPDATE, TRUNCATE, REFERENCES, TRIGGER ON agoston_identity.user_identities TO "##DEVELOPER_USER##";

GRANT usage, SELECT ON SEQUENCE agoston_identity.user_identities_id_seq TO "##DEVELOPER_USER##";

CREATE TABLE agoston_identity.user_sessions (
    sid text NOT NULL COLLATE "default",
    sess json NOT NULL,
    expire timestamp(6) NOT NULL,
    CONSTRAINT session_pkey PRIMARY KEY (sid) NOT DEFERRABLE INITIALLY immediate
)
WITH (
    OIDS = FALSE
);

CREATE INDEX idx_user_sessions_expire ON agoston_identity.user_sessions (expire);

ALTER TABLE agoston_identity.user_sessions OWNER TO "##POSTGRAPHILE_USER##";

GRANT SELECT, INSERT, DELETE, UPDATE, TRUNCATE, REFERENCES, TRIGGER ON agoston_identity.user_sessions TO "##DEVELOPER_USER##";

----------------------------------------------------------------------------------------
-- Session data
----------------------------------------------------------------------------------------
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
      'session_id', current_setting('session.id', true)::text,
      'auth_provider', ( select case current_setting('session.auth_provider', true)
                        when '' then null
                        else current_setting('session.auth_provider', true)::text
                        end case
                        ),
      'auth_subject', ( select case current_setting('session.auth_subject', true)
                        when '' then null
                        else current_setting('session.auth_subject', true)::text
                        end case
                        ),
      'auth_data', ( select case current_setting('session.auth_data', true)
                     when '' then null
                     else current_setting('session.auth_data', true)::jsonb
                     end case
                    )
    );
$BODY$;

----------------------------------------------------------------------------------------
-- APIs
----------------------------------------------------------------------------------------
-- Function is idempotent
CREATE OR REPLACE FUNCTION agoston_api.set_authenticated_user (
        p_provider text,
        p_subject text,
        p_raw jsonb,
        p_password text default null
)
    RETURNS record
    AS $$
DECLARE
    v_return record;
    v_federated_credential_id integer := NULL;
    v_user_id integer := NULL;
BEGIN
    SELECT  id INTO v_federated_credential_id
    FROM    agoston_identity.federated_credentials
    WHERE   provider = p_provider
    AND     subject = p_subject;

    -- User never auth before
    IF v_federated_credential_id IS NULL THEN
        INSERT INTO agoston_identity.federated_credentials (provider, subject, raw)
            VALUES (p_provider, p_subject, p_raw)
        RETURNING id INTO v_federated_credential_id;
    END IF;

    -- User exists?
    SELECT  id
    INTO    v_user_id
    FROM    agoston_identity.user_identities
    WHERE   federated_credential_id = v_federated_credential_id;
    raise notice 'User exists returned => %', v_user_id;

    -- User never created before: create it
    IF v_user_id IS NULL THEN
        insert into agoston_identity.user_identities (federated_credential_id)
            values (v_federated_credential_id) returning id into v_user_id;
        if p_password is not null then
            update agoston_identity.user_identities
            set hashed_password = public.crypt(p_password, public.gen_salt('md5'))
            where id = v_user_id;
        end if;
    END IF;

    -- return
    if p_password is null and p_provider != 'user-pwd' then
        select  u.id user_id,
                r.name as "role_name",
                f.provider auth_provider,
                f.subject auth_subject,
                f.raw::text auth_data
        into    v_return
        from    agoston_identity.user_identities u,
                agoston_identity.federated_credentials f,
                agoston_identity.user_roles r
        where   u.user_role_id = r.id
        and     u.federated_credential_id = f.id
        and     u.id = v_user_id
        and     f.provider != 'user-pwd' ;
    else
        select  u.id user_id,
                r.name as "role_name",
                f.provider auth_provider,
                f.subject auth_subject,
                f.raw::text auth_data
        into    v_return
        from    agoston_identity.user_identities u,
                agoston_identity.federated_credentials f,
                agoston_identity.user_roles r
        where   u.user_role_id = r.id
        and     u.federated_credential_id = f.id
        and     u.id = v_user_id
        and     f.provider = 'user-pwd'
        and     hashed_password = public.crypt(p_password, hashed_password);
    end if;
    return  v_return;
END;
$$
LANGUAGE plpgsql;

ALTER FUNCTION agoston_api.set_authenticated_user OWNER TO "##POSTGRAPHILE_USER##";

CREATE OR REPLACE FUNCTION agoston_api.add_user ()
    RETURNS int
    AS $$
DECLARE
    v_user_id integer := NULL;
BEGIN
    INSERT INTO agoston_identity.user_identities (id)
        VALUES (nextval('agoston_identity.user_identities_id_seq'))
    RETURNING
        id INTO v_user_id;
    RETURN v_user_id;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION agoston_api.add_user OWNER TO "##POSTGRAPHILE_USER##";

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
ALTER FUNCTION agoston_api.delete_user OWNER TO "##POSTGRAPHILE_USER##";

--------

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

ALTER FUNCTION agoston_api.set_user_token OWNER TO "##POSTGRAPHILE_USER##";

CREATE OR REPLACE FUNCTION agoston_api.get_user_by_token (p_token text)
    RETURNS record
    AS $$
DECLARE
    v_return record;
BEGIN
    -- return
    SELECT
        u.id user_id,
        r.name as "role_name",
        'http-bearer' auth_provider,
        u.id::text auth_subject,
        '{}'::text auth_data
    INTO v_return
    FROM
        agoston_identity.user_identities u,
        agoston_identity.user_roles r
    WHERE
        u.user_role_id = r.id
        AND hashed_token = public.crypt(p_token, hashed_token);
    RETURN v_return;
END;
$$
LANGUAGE plpgsql;

ALTER FUNCTION agoston_api.get_user_by_token OWNER TO "##POSTGRAPHILE_USER##";
