
do $$
DECLARE
    r_role record;
BEGIN
    for r_role in (select * from agoston_identity.user_roles) loop
        execute 'grant usage on schema public to ' || r_role.name;
        execute 'grant usage on schema agoston_api to ' || r_role.name;
        execute 'grant usage on schema agoston_identity to ' || r_role.name;
        execute 'grant usage on schema cron to ' || r_role.name;
        execute 'grant ' || r_role.name || ' to ##DEVELOPER_USER##';
    end loop;

end;
$$
language plpgsql;
