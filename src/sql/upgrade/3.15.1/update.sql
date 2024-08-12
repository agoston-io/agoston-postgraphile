drop function agoston_api.set_authenticated_user(text,text,jsonb,text,boolean);
CREATE OR REPLACE FUNCTION agoston_api.set_authenticated_user (
        p_provider text,
        p_subject text,
        p_raw jsonb,
        p_password text default null,
        p_create_user_if_not_exits boolean default true
)
    RETURNS table (
        user_id int,
        role_name text,
        auth_provider text,
        auth_subject text,
        auth_data jsonb
    )
    AS $$
DECLARE
    v_federated_credential_id integer := NULL;
    v_user_id integer := NULL;
BEGIN
    raise notice 'p_create_user_if_not_exits => %', p_create_user_if_not_exits;

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
    IF v_user_id IS NULL and p_create_user_if_not_exits THEN
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
        return query
        select  u.id user_id,
                r.name as "role_name",
                f.provider auth_provider,
                f.subject auth_subject,
                f.raw auth_data
        from    agoston_identity.user_identities u,
                agoston_identity.federated_credentials f,
                agoston_identity.user_roles r
        where   u.user_role_id = r.id
        and     u.federated_credential_id = f.id
        and     u.id = v_user_id
        and     f.provider != 'user-pwd' ;
    else
        return query
        select  u.id user_id,
                r.name as "role_name",
                f.provider auth_provider,
                f.subject auth_subject,
                f.raw auth_data
        from    agoston_identity.user_identities u,
                agoston_identity.federated_credentials f,
                agoston_identity.user_roles r
        where   u.user_role_id = r.id
        and     u.federated_credential_id = f.id
        and     u.id = v_user_id
        and     f.provider = 'user-pwd'
        and     hashed_password = public.crypt(p_password, hashed_password);
    end if;
END;
$$
LANGUAGE plpgsql;


create or replace function agoston_public.session (
	)
    returns jsonb
    language 'sql'
    cost 100
    stable parallel unsafe
    security definer
AS
$BODY$
    select jsonb_build_object(
      'role', current_user,
      'is_authenticated', current_setting('session.is_authenticated', true)::boolean,
      'user_id', current_setting('session.user_id', true)::int,
      'session_id', current_setting('session.id', true)::text,
      'auth_data', (    select  jsonb_build_object(
                                    'provider', provider,
                                    'subject', subject,
                                    'info', raw
                                )
                        from    agoston_identity.federated_credentials
                        where   id in (
                            select  federated_credential_id
                            from    agoston_identity.user_identities
                            where   id = current_setting('session.user_id', true)::int
                        )
                    )
    );

$BODY$;
alter function agoston_public.session owner to ##POSTGRAPHILE_USER##;
