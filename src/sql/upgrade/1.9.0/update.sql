drop function if exists agoston_api.set_authenticated_user ( text, text, jsonb ) ;

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
                r.name role_name
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
                r.name role_name
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

ALTER FUNCTION agoston_api.set_authenticated_user OWNER TO ##POSTGRAPHILE_USER##;
