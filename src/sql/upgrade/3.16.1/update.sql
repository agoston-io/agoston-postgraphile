drop function agoston_api.set_authenticated_user;
create or replace function agoston_api.set_authenticated_user (
        p_provider text,
        p_subject text,
        p_raw jsonb,
        p_password text default null,
        p_username_complexity_pattern text default '^[a-z0-9\-_.@]{5,}$',
        p_password_complexity_pattern text default '^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$%^&*,-_])(?=.{8,})',
        p_create_user_if_not_exits boolean default true
)
    returns table (
        user_id int,
        role_name text,
        auth_provider text,
        auth_subject text,
        auth_data jsonb,
        user_existed boolean
    )
    AS $$
declare
    v_federated_credential_id integer := null;
    v_user_id integer := null;
    v_user_existed boolean := false;
begin
    raise notice 'p_username_complexity_pattern => %', p_username_complexity_pattern;
    raise notice 'p_password_complexity_pattern => %', p_password_complexity_pattern;
    raise notice 'p_create_user_if_not_exits => %', p_create_user_if_not_exits;

    select  id into v_federated_credential_id
    from    agoston_identity.federated_credentials
    where   provider = p_provider
    and     subject = p_subject;
    raise notice 'v_federated_credential_id => %', v_federated_credential_id;

    -- user never auth before
    if v_federated_credential_id is null and p_create_user_if_not_exits then
        -- Ensure username match pattern
        if p_provider = 'user-pwd' then
            raise notice 'p_username_complexity_pattern => %', p_username_complexity_pattern;
            if not p_subject ~ p_username_complexity_pattern then
                raise exception 'The username provided doesn''t comply with the requirements.';
            end if;
        end if;
        insert into agoston_identity.federated_credentials (provider, subject, raw)
            values (p_provider, p_subject, p_raw)
        returning id into v_federated_credential_id;
    end if;

    -- User exists?
    select  id
    into    v_user_id
    from    agoston_identity.user_identities
    where   federated_credential_id = v_federated_credential_id;
    raise notice 'User exists returned => %', v_user_id;

    -- User never created before: create it
    if v_user_id is null and p_create_user_if_not_exits then
        v_user_existed := true;
        if p_provider = 'user-pwd' then
            -- Ensure password match pattern
            raise notice 'p_password_complexity_pattern => %', p_password_complexity_pattern;
            raise notice 'p_password => %', p_password;
            if not  p_password ~ p_password_complexity_pattern then
                raise exception 'The password provided doesn''t comply with the requirements.';
            end if;
        end if;
        -- Create user
        insert into agoston_identity.user_identities (federated_credential_id)
            values (v_federated_credential_id) returning id into v_user_id;
        if p_password is not null then
            update agoston_identity.user_identities
            set hashed_password = public.crypt(p_password, public.gen_salt('md5'))
            where id = v_user_id;
        end if;
    end if;

    -- return
    if p_password is null and p_provider != 'user-pwd' then
        return query
        select  u.id user_id,
                r.name as "role_name",
                f.provider auth_provider,
                f.subject auth_subject,
                f.raw auth_data,
                v_user_existed as "user_existed"
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
                f.raw auth_data,
                v_user_existed as "user_existed"
        from    agoston_identity.user_identities u,
                agoston_identity.federated_credentials f,
                agoston_identity.user_roles r
        where   u.user_role_id = r.id
        and     u.federated_credential_id = f.id
        and     u.id = v_user_id
        and     f.provider = 'user-pwd'
        and     hashed_password = public.crypt(p_password, hashed_password);
    end if;
end;
$$
language plpgsql;

create or replace function agoston_public.session (
	)
    returns jsonb
    language 'sql'
    cost 100
    stable parallel unsafe
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
alter function agoston_public.session owner to ##POSTGRAPHILE_USER##;
