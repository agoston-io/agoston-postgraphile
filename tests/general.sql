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
        p_password => 'aFakePassword'
    );
    perform agoston_api.set_authenticated_user(
        p_provider => 'google',
        p_subject => 'niolap',
        p_raw => '{"username":"niolap","more_data":{"attr1":"val1"}}'
    );

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
    perform agoston_api.get_user_by_token (v_user_token);
    perform agoston_api.delete_user (v_user_id);

end $$;

-- Jobs
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
    select agoston_api.add_cron_job( task => 'run-sql', identifier => 'run-sql-1', pattern => '* * * * *', payload => '{ "sql": "insert into added_job_table values (1);" }') into v_crontabs;
    select agoston_api.add_cron_job( task => 'run-sql', identifier => 'run-sql-2', pattern => '* * * * *', payload => '{ "sql": "insert into added_job_table values (1);" }') into v_crontabs;
    select agoston_api.add_cron_job( task => 'run-sql', identifier => 'run-sql-3', pattern => '* * * * *', payload => '{ "sql": "insert into added_job_table values (1);" }') into v_crontabs;
end $$;
