drop function agoston_api.set_authenticated_user(text,text,jsonb,text);
CREATE OR REPLACE FUNCTION agoston_api.set_authenticated_user (
        p_provider text,
        p_subject text,
        p_raw jsonb,
        p_password text default null,
        p_create_user_if_not_exits boolean default true
)
    RETURNS record
    AS $$
DECLARE
    v_return record;
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
        select  u.id user_id,
                r.name as "role_name",
                f.provider auth_provider,
                f.subject auth_subject,
                f.raw::text auth_data
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
                r.name as "role_name",
                f.provider auth_provider,
                f.subject auth_subject,
                f.raw::text auth_data
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

----------------------------------------------------------------------
-- save existing crontab if any
----------------------------------------------------------------------
alter table if exists agoston_api.crontabs rename to crontabs_saved;

----------------------------------------------------------------------
-- Cleanup Old job and cron
----------------------------------------------------------------------
drop view if exists agoston_api.jobs cascade;
drop view if exists agoston_api.job_queues cascade;
drop view if exists agoston_api.known_crontabs cascade;
drop table if exists agoston_api.job_tasks cascade;
drop view if exists agoston_api.cron_jobs cascade;
drop function if exists agoston_api.add_cron_job;
drop function if exists agoston_api.enable_cron_job;
drop function if exists agoston_api.disable_cron_job;
drop function if exists agoston_api.delete_cron_job;
drop function if exists agoston_api.add_job;
----------------------------------------------------------------------
-- Cron
----------------------------------------------------------------------

create table agoston_api.job_tasks (
  id int primary key,
  name text not null unique
);
insert into agoston_api.job_tasks values
( 1, 'rest-delete'),
( 2, 'rest-get'),
( 3, 'rest-patch'),
( 4, 'rest-post'),
( 5, 'rest-put'),
( 6, 'run-sql'),
( 7, 'send-email');
GRANT SELECT ON agoston_api.job_tasks TO "##DEVELOPER_USER##";

create table agoston_api.crontabs (
  id serial primary key,
  task text,
  match text,
  backfillPeriod text default null,
  maxAttempts int default 1,
  queue_name text default null,
  priority int default 0,
  payload jsonb default null,
  identifier text default null unique,
  enable boolean default true,
  constraint crontabs_task_must_exits foreign key (task) references agoston_api.job_tasks(name)
);
alter table agoston_api.crontabs owner to "##POSTGRAPHILE_USER##";

CREATE OR REPLACE VIEW agoston_api.cron_jobs AS
SELECT c.*, kc.known_since as "discovered_since", kc.last_execution
FROM agoston_api.crontabs c
left join "##WORKER_SCHEMA##"._private_known_crontabs kc on c.identifier = kc.identifier;
GRANT SELECT ON agoston_api.cron_jobs TO "##DEVELOPER_USER##";

create or replace function agoston_api.add_cron_job (
  task text,
  match text,
  backfillPeriod text = null,
  maxAttempts int = 1,
  queue_name text = null,
  priority int = 0,
  payload jsonb = null,
  identifier text = null,
  enable boolean = true
)
returns agoston_api.crontabs
security definer
as $$
  insert into agoston_api.crontabs (
    task,
    match,
    backfillPeriod,
    maxAttempts,
    queue_name,
    priority,
    payload,
    identifier,
    enable
  ) values (
    task,
    match,
    backfillPeriod,
    maxAttempts,
    queue_name,
    priority,
    payload,
    coalesce(identifier, task),
    enable
  ) returning *;
$$ LANGUAGE sql;
alter function agoston_api.add_cron_job owner to "##POSTGRAPHILE_USER##";

create or replace function agoston_api.enable_cron_job (crontab_id int)
returns agoston_api.crontabs
security definer
as $$
  update agoston_api.crontabs set enable = true where id = crontab_id returning *;
$$ LANGUAGE sql;
alter function agoston_api.enable_cron_job owner to "##POSTGRAPHILE_USER##";

create or replace function agoston_api.disable_cron_job (crontab_id int)
returns agoston_api.crontabs
security definer
as $$
  update agoston_api.crontabs set enable = false where id = crontab_id returning *;
$$ LANGUAGE sql;
alter function agoston_api.disable_cron_job owner to "##POSTGRAPHILE_USER##";

create or replace function agoston_api.delete_cron_job (crontab_id int)
returns agoston_api.crontabs
security definer
as $$
  delete from agoston_api.crontabs where id = crontab_id returning *;
$$ LANGUAGE sql;
alter function agoston_api.delete_cron_job owner to "##POSTGRAPHILE_USER##";

----------------------------------------------------------------------
-- Restore crontab
----------------------------------------------------------------------
do $$
declare
  d_crontab record;
begin
  if exists ( select * from information_schema.tables where table_schema = 'agoston_api' and table_name = 'crontabs_saved' ) then
    for d_crontab in ( select * from agoston_api.crontabs_saved order by id) loop
      raise notice 'Starting migration of crontab %...', d_crontab.task;
      perform agoston_api.add_cron_job (
        task => d_crontab.task,
        match => d_crontab.pattern,
        backfillPeriod => d_crontab.backfillPeriod,
        maxAttempts => d_crontab.maxAttempts,
        queue_name => d_crontab.queue_name,
        priority => d_crontab.priority,
        payload => d_crontab.payload,
        identifier => d_crontab.identifier,
        enable => d_crontab.enable
      );
      raise notice 'Migration of crontab % ok.', d_crontab.task;
    end loop;
  end if;
end $$;

drop table if exists agoston_api.crontabs_saved;

----------------------------------------------------------------------
-- Jobs
----------------------------------------------------------------------
-- Ensure that user insert an available task
alter table "##WORKER_SCHEMA##"._private_tasks add constraint jobs_task_must_exits foreign key (identifier) references agoston_api.job_tasks(name);

create or replace function agoston_api.add_job (
  identifier text,
  payload json = NULL,
  queue_name text = NULL,
  run_at timestamptz = NULL,
  max_attempts integer = 1,
  job_key text = NULL,
  priority integer = NULL,
  flags text[] = NULL,
  job_key_mode text = 'replace'
)
  RETURNS "##WORKER_SCHEMA##"._private_jobs
  SECURITY DEFINER
  AS $$
BEGIN
  RETURN "##WORKER_SCHEMA##".add_job (
    identifier,
    payload,
    queue_name,
    run_at,
    max_attempts,
    job_key,
    priority,
    flags,
    job_key_mode
    );
END;
$$ LANGUAGE plpgsql;
alter function agoston_api.add_job owner to "##POSTGRAPHILE_USER##";

-- Views
CREATE OR REPLACE VIEW agoston_api.jobs AS
SELECT * FROM "##WORKER_SCHEMA##"._private_jobs;
GRANT SELECT ON agoston_api.jobs TO "##DEVELOPER_USER##";

CREATE OR REPLACE VIEW agoston_api.job_queues AS
SELECT * FROM "##WORKER_SCHEMA##"._private_job_queues;
GRANT SELECT ON agoston_api.job_queues TO "##DEVELOPER_USER##";

CREATE OR REPLACE VIEW agoston_api.known_crontabs AS
SELECT * FROM "##WORKER_SCHEMA##"._private_known_crontabs;
GRANT SELECT ON agoston_api.known_crontabs TO "##DEVELOPER_USER##";

CREATE OR REPLACE VIEW agoston_api.tasks AS
SELECT * FROM "##WORKER_SCHEMA##"._private_tasks;
GRANT SELECT ON agoston_api.tasks TO "##DEVELOPER_USER##";



