create table agoston_identity.user_tokens (
    id bigint generated always as identity,
    name text not null,
    user_id int not null,
    hashed_token text not null,
    expiration_ts timestamp with time zone,
    constraint user_tokens_pk primary key (id),
    constraint user_tokens_fk_01 foreign key (user_id) references agoston_identity.user_identities (id) on delete cascade,
    constraint user_tokens_uq_01 unique (user_id, name)
);
create index user_tokens_idx_01 on agoston_identity.user_tokens (id);
create index user_tokens_idx_02 on agoston_identity.user_tokens (user_id);

alter table agoston_identity.user_tokens owner to "##POSTGRAPHILE_USER##";
grant select, insert, delete, update, truncate, references, trigger on agoston_identity.user_tokens TO "##DEVELOPER_USER##";
grant usage, select on sequence agoston_identity.user_tokens_id_seq TO "##DEVELOPER_USER##";

--------

alter table agoston_identity.user_identities drop column hashed_token;

--------
drop function if exists agoston_api.set_user_token;
create or replace function agoston_api.set_user_token (
    p_user_id int,
    p_token_name text default null,
    p_expiration_ts timestamp with time zone default null
)
    returns text
    as $$
declare
    v_token text;
    v_token_chars text := 'abcdefghjklmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ0123456789';
begin
    -- Checks
    if not exists (select * from agoston_identity.user_identities where id = p_user_id) then
		raise exception 'User (id=''%'') does not exist.', p_user_id;
	end if;
    if p_token_name is not null and exists (select from agoston_identity.user_tokens where user_id = p_user_id and name = p_token_name) then
		raise exception 'Token name (''p_token_name'') already exists';
    end if;
    if p_token_name is not null and not p_token_name ~ '^[a-zA-Z0-9\-_]{1,30}$' then
		raise exception 'Token name (''p_token_name'') invalid. 1 and 30 chars max. Allowed chars "a-z", "A-Z", "0-9", "-" and "_"';
    end if;
    if p_expiration_ts is not null and p_expiration_ts < now() then
		raise exception 'Expiration date (''p_expiration_ts'') cannot be in the past.';
    end if;

    -- Generate token
    select  array_to_string(array((select substring(v_token_chars from mod((random() * 62)::int, 62) + 1 for 1) from generate_series(1, 72))), '')
    into v_token;

    -- Save token
    insert into agoston_identity.user_tokens
    (
        user_id,
        name,
        hashed_token,
        expiration_ts
    )
    values
    (
        p_user_id,
        coalesce(p_token_name, 'token_'||substring(v_token from 1 for 5)),
        public.crypt(v_token, public.gen_salt('bf')),
        coalesce(p_expiration_ts, now() + interval '10 years')
    );

    -- Return token
    return v_token;
end;
$$
language plpgsql;
alter function agoston_api.set_user_token owner to "##POSTGRAPHILE_USER##";

--------
drop function if exists agoston_api.get_user_by_token;
create or replace function agoston_api.get_user_by_token (p_user_id int, p_token text)
    returns table (
        user_id int,
        role_name text,
        auth_provider text,
        auth_subject text,
        auth_data jsonb,
        user_existed boolean
    )
    as $$
declare
    v_return record;
begin
    raise notice 'get_user_by_token | p_user_id => %', p_user_id;
    raise notice 'get_user_by_token | p_token => %', p_token;
    return query
    select  ui.id as "user_id",
            ur.name as "role_name",
            'http-bearer' as "auth_provider",
            ui.id::text as "auth_subject",
            jsonb_build_object('token',
                jsonb_build_object(
                    'id', ut.id,
                    'name', ut.name,
                    'expiration_ts', ut.expiration_ts)
            ) as "auth_data",
            true as "user_existed"
    from    agoston_identity.user_identities ui
    join    agoston_identity.user_tokens ut on ui.id = ut.user_id
        and     ut.user_id = p_user_id
        and     ut.hashed_token = public.crypt(p_token, ut.hashed_token)
        and     ut.expiration_ts > now()
    join    agoston_identity.user_roles ur on ui.user_role_id = ur.id;
end;
$$
language plpgsql;
alter function agoston_api.get_user_by_token owner to "##POSTGRAPHILE_USER##";

--------
drop function if exists agoston_api.delete_user_token;
create or replace function agoston_api.delete_user_token (
    p_user_token_id bigint
)
    returns boolean
    as $$
declare
    v_deleted boolean := true;
begin
    raise notice 'delete_user_token | p_user_token_id => %', p_user_token_id;
    -- Checks
    if not exists (select * from agoston_identity.user_tokens where id = p_user_token_id) then
		raise exception 'User token (id=''%'') does not exist.', p_user_token_id;
	end if;
    -- Deletion
    delete from agoston_identity.user_tokens where id = p_user_token_id;
    return v_deleted;
end;
$$
language plpgsql;
alter function agoston_api.delete_user_token owner to "##POSTGRAPHILE_USER##";
