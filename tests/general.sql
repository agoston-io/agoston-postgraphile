\set ON_ERROR_STOP on

------------------------------------------------------------------------
-- Postgres user
------------------------------------------------------------------------
set role postgres;

do $$
declare
    v_backend_old_version varchar(10);
    v_backend_new_version varchar(10);
    v_backend_test_version varchar(10) := 'v0.0.0';
begin

    select agoston_api.get_backend_version() into v_backend_old_version;
    select agoston_api.set_backend_version( p_version => v_backend_test_version ) into v_backend_new_version;
    assert v_backend_new_version = v_backend_test_version;
    select agoston_api.set_backend_version( p_version => v_backend_old_version ) into v_backend_new_version;
    assert v_backend_new_version = v_backend_old_version;

end $$;

------------------------------------------------------------------------
-- Postgraphile user
------------------------------------------------------------------------
set role :postgraphile_user;

do $$
declare
    v_backend_version varchar(10);
begin

    perform agoston_api.set_authenticated_user(
        p_provider => 'user-pwd',
        p_subject => '848456qsdqs56d56qs',
        p_raw => '{"username":"niolap","more_data":{"attr1":"val1"}}',
        p_password => 'aFakeP@ssword2025'
    );
    perform agoston_api.set_authenticated_user(
        p_provider => 'google',
        p_subject => 'niolap',
        p_raw => '{"username":"niolap","more_data":{"attr1":"val1"}}'
    );

end $$;


------------------------------------------------------------------------
-- User token
------------------------------------------------------------------------
set role :developer_user;

do $$
declare
    v_iterator int := 0;
    v_user_id int;
    v_token text;
begin
    while v_iterator < 100 loop
        raise notice 'token test % / 100', v_iterator;
        select agoston_api.add_user() into v_user_id;
        select agoston_api.set_user_token(p_user_id=>v_user_id) into v_token;
        perform agoston_api.get_user_by_token(v_user_id, v_token);
        assert (select cast(auth_data->'token'->>'expiration_ts' as timestamp with time zone) from get_user_by_token(v_user_id, v_token)) > now() + interval '9 YEARS';
        select agoston_api.set_user_token(p_user_id=>v_user_id, p_expiration_ts => now() + interval '24 hours') into v_token;
        assert (select cast(auth_data->'token'->>'expiration_ts' as timestamp with time zone) from get_user_by_token(v_user_id, v_token)) between now() + interval '23 HOURS' and now() + interval '25 HOURS';
        select agoston_api.set_user_token(p_user_id=>v_user_id, p_token_name=> 'test_1_'||v_user_id||'_'||v_iterator) into v_token;
        assert (select cast(auth_data->'token'->>'name' as text) from get_user_by_token(v_user_id, v_token)) = 'test_1_'||v_user_id||'_'||v_iterator;
        assert (select cast(auth_data->'token'->>'expiration_ts' as timestamp with time zone) from get_user_by_token(v_user_id, v_token)) > now() + interval '9 YEARS';
        select agoston_api.set_user_token(p_user_id=>v_user_id, p_token_name=> 'test_2_'||v_user_id||'_'||v_iterator, p_expiration_ts => now() + interval '24 hours') into v_token;
        assert (select cast(auth_data->'token'->>'name' as text) from get_user_by_token(v_user_id, v_token)) = 'test_2_'||v_user_id||'_'||v_iterator;
        assert (select cast(auth_data->'token'->>'expiration_ts' as timestamp with time zone) from get_user_by_token(v_user_id, v_token)) between now() + interval '23 HOURS' and now() + interval '25 HOURS';
        assert (select user_id from get_user_by_token(v_user_id, v_token)) = v_user_id;
        v_iterator := v_iterator+1;
    end loop;
end $$;

------------------------------------------------------------------------
-- User password
------------------------------------------------------------------------
set role :developer_user;

do $$
begin
    assert(select user_id from set_user_password(p_username => '848456qsdqs56d56qs', p_password => 'Azerty@2025')) = 1; -- ok
    assert(select password_expired from set_user_password_expiration(p_username => '848456qsdqs56d56qs', p_password_expired => true)) = true;
    assert(select password_expired from set_user_password(p_username => '848456qsdqs56d56qs', p_password => 'Azerty@2026', p_old_password => 'Azerty@2025')) = false; -- ok

    assert(select user_id from set_user_password_expiration(p_username => '848456qsdqs56d56qs')) = 1;
    assert(select password_expired from set_user_password_expiration(p_username => '848456qsdqs56d56qs', p_password_expired => false)) = false;
    assert(select password_expired from set_user_password_expiration(p_username => '848456qsdqs56d56qs')) = true;
    assert(select password_expired from set_user_password_expiration(p_username => '848456qsdqs56d56qs', p_password_expired => false)) = false;
    assert(select password_expired from set_user_password_expiration(p_username => '848456qsdqs56d56qs', p_password_expired => true)) = true;
end $$;

------------------------------------------------------------------------
-- Developer user
------------------------------------------------------------------------
set role :developer_user;

do $$
declare
    v_user_id integer;
    v_role_id integer;
    v_role_anonymous_id integer;
    v_role_authenticated_id integer;
    v_user_token text;
    v_job record;
    v_table_name text;
begin

    -- Session
    perform agoston_public.session();

    -- Users
    select agoston_api.add_user () into v_user_id;
    select agoston_api.set_user_token (p_user_id => v_user_id) into v_user_token;
    perform agoston_api.get_user_by_token (v_user_id, v_user_token);
    perform agoston_api.delete_user (v_user_id);

end $$;

------------------------------------------------------------------------
-- User token deletion
------------------------------------------------------------------------
set role :postgraphile_user;

do $$
declare
    v_token record;
begin
    for v_token in (select * from agoston_identity.user_tokens) loop
        assert agoston_api.delete_user_token(p_user_token_id => v_token.id);
    end loop;
end $$;


------------------------------------------------------------------------
-- Jobs
------------------------------------------------------------------------
do $$
declare
    v_job record;
begin
    select agoston_api.add_job( identifier => 'run-sql', payload => '{ "sql": "create table \"added_job_table\" ( id int );" }') into v_job;
end $$;
select pg_sleep(2); -- Let's give a few seconds to the worker.


do $$
declare
    v_table_name text;
begin
    select tablename into v_table_name from pg_tables where schemaname = 'agoston_private' and tablename  = 'added_job_table';
    assert v_table_name = 'added_job_table';
end $$;

-- Cron Jobs
do $$
declare
    v_crontabs record;
begin
    select agoston_api.add_cron_job( task => 'run-sql', identifier => 'run-sql-1', match => '* * * * *', payload => '{ "sql": "insert into added_job_table values (1);" }') into v_crontabs;
    select agoston_api.add_cron_job( task => 'run-sql', identifier => 'run-sql-2', match => '* * * * *', payload => '{ "sql": "insert into added_job_table values (1);" }') into v_crontabs;
    select agoston_api.add_cron_job( task => 'run-sql', identifier => 'run-sql-3', match => '* * * * *', payload => '{ "sql": "insert into added_job_table values (1);" }') into v_crontabs;
end $$;
