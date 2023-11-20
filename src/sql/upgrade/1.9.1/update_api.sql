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
      'auth_provider', current_setting('session.auth_provider', true)::text,
      'auth_subject', current_setting('session.auth_subject', true)::text,
      'auth_data', current_setting('session.auth_data', true)::jsonb
    );
$BODY$;

CREATE OR REPLACE FUNCTION agoston_api.get_user_by_token (p_token text)
    RETURNS record
    AS $$
DECLARE
    v_return record;
BEGIN
    -- return
    SELECT
        u.id user_id,
        r.name role_name,
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
                r.name role_name,
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
                r.name role_name,
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
