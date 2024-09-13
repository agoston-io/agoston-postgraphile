alter table agoston_identity.user_identities add password_expired boolean not null default false;

create or replace function agoston_api.set_user_password (
        p_username text,
        p_password text default null,
        p_current_password text default null,
        p_password_complexity_pattern text default '^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$%^&*,-_])(?=.{8,})'
)
    returns table (
        user_id int,
        role_name text,
        auth_provider text,
        auth_subject text,
        auth_data jsonb,
        password_expired boolean
    )
as $$
declare
    d_user_id integer;
begin
    select  ui.id
    into    d_user_id
    from    agoston_identity.user_identities ui
    join    agoston_identity.federated_credentials fc on fc.id = ui.federated_credential_id
    where   fc.provider = 'user-pwd'
    and     fc.subject = p_username;
    if d_user_id is null then
        raise exception 'The username/old password is incorrect.';
    end if;
    -- Ensure password match pattern
    raise notice 'p_password_complexity_pattern => %', p_password_complexity_pattern;
    raise notice 'p_password => %', p_password;
    raise notice 'p_current_password => %', p_current_password;
    if p_current_password is not null and not exists (select from agoston_identity.user_identities where id = d_user_id and hashed_password = public.crypt(p_current_password, hashed_password)) then
        raise exception 'The username/old password is incorrect.';
    end if;
    if not p_password ~ p_password_complexity_pattern then
        raise exception 'The password provided doesn''t comply with the requirements.';
    end if;
    update  agoston_identity.user_identities
    set     hashed_password = public.crypt(p_password, public.gen_salt('md5'))
    where   id = d_user_id;
    if p_current_password is not null then
        update  agoston_identity.user_identities set password_expired = false;
    end if;

    return  query
    select  u.id user_id,
            r.name as "role_name",
            f.provider auth_provider,
            f.subject auth_subject,
            f.raw auth_data,
            u.password_expired as "password_expired"
    from    agoston_identity.user_identities u,
            agoston_identity.federated_credentials f,
            agoston_identity.user_roles r
    where   u.user_role_id = r.id
    and     u.federated_credential_id = f.id
    and     u.id = d_user_id
    and     f.provider = 'user-pwd'
    and     hashed_password = public.crypt(p_password, hashed_password);
end;
$$
language plpgsql;
alter function agoston_api.set_user_password owner to "##POSTGRAPHILE_USER##";

create or replace function agoston_api.set_user_password_expiration (
        p_username text,
        p_password_expired boolean default true
)
    returns table (
        user_id int,
        role_name text,
        auth_provider text,
        auth_subject text,
        auth_data jsonb,
        password_expired boolean
    )
as $$
declare
    d_user_id integer;
begin
    select  ui.id
    into    d_user_id
    from    agoston_identity.user_identities ui
    join    agoston_identity.federated_credentials fc on fc.id = ui.federated_credential_id
    where   fc.provider = 'user-pwd'
    and     fc.subject = p_username;
    if d_user_id is null then
        raise exception 'The username does not exist.';
    end if;

    update  agoston_identity.user_identities
    set     password_expired = p_password_expired
    where   id = d_user_id;

    return  query
    select  u.id user_id,
            r.name as "role_name",
            f.provider auth_provider,
            f.subject auth_subject,
            f.raw auth_data,
            u.password_expired as "password_expired"
    from    agoston_identity.user_identities u,
            agoston_identity.federated_credentials f,
            agoston_identity.user_roles r
    where   u.user_role_id = r.id
    and     u.federated_credential_id = f.id
    and     u.id = d_user_id
    and     f.provider = 'user-pwd';
end;
$$
language plpgsql;
alter function agoston_api.set_user_password owner to "##POSTGRAPHILE_USER##";

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
        user_existed boolean,
        password_expired boolean
    )
    AS $$
declare
    v_federated_credential_id integer := null;
    v_user_id integer := null;
    v_user_existed boolean := true;
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
        v_user_existed := false;
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
                v_user_existed as "user_existed",
                u.password_expired as "password_expired"
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
                v_user_existed as "user_existed",
                u.password_expired as "password_expired"
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
alter function agoston_api.set_authenticated_user owner to "##POSTGRAPHILE_USER##";
