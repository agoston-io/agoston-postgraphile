\set ON_ERROR_STOP on

-- Cron Jobs
do $$
declare
    v_crontabs record;
    v_count int := 0;
begin
    for v_crontabs in (select identifier, discovered_since from cron_jobs) loop
        assert v_crontabs.discovered_since is not null, 'Cron task not discovered!';
    end loop;
    perform pg_sleep(65);
    select count(1) into v_count from added_job_table;
    assert v_count = 3, 'A cron task did not ran in due time, because added_job_table has not 3 rows!';
end $$;
