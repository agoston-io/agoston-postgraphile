-- Roles
do $$
begin
    if not exists ( select from pg_catalog.pg_roles where  lower(rolname) = lower('anonymous') ) then
            execute 'create role anonymous with nologin';
    end if;
    if not exists ( select from pg_catalog.pg_roles where  lower(rolname) = lower('authenticated') ) then
            execute 'create role authenticated with nologin';
    end if;
end $$;

grant usage on schema agoston_public to anonymous;
grant usage on schema public to anonymous;
grant usage on schema agoston_api to anonymous;
grant usage on schema agoston_identity to anonymous;
grant anonymous to "##DEVELOPER_USER##";
grant anonymous to "##POSTGRAPHILE_USER##";

grant usage on schema agoston_public to authenticated;
grant usage on schema public to authenticated;
grant usage on schema agoston_api to authenticated;
grant usage on schema agoston_identity to authenticated;
grant authenticated to "##DEVELOPER_USER##";
grant authenticated to "##POSTGRAPHILE_USER##";

-- Insert default roles
insert into agoston_identity.user_roles ( id, name ) values (1, 'anonymous') ;
insert into agoston_identity.user_roles ( id, name ) values (2, 'authenticated') ;

-- Insert default anonymous user
insert into agoston_identity.user_identities (id, user_role_id ) values (0, 1) ;
