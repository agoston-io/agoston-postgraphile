CREATE OR REPLACE FUNCTION agoston_api.auto_subscription()
  RETURNS event_trigger
 LANGUAGE plpgsql
  AS $$
DECLARE
  d_object_type text;
  d_schema_name text;
  d_table_name text;
BEGIN
  SELECT  lower(object_type), lower(schema_name), lower(objid::regclass::text)
  into    d_object_type, d_schema_name, d_table_name
  FROM    pg_event_trigger_ddl_commands();
  if d_object_type = 'table' and d_schema_name = 'agoston_public' then
    execute format('create or replace trigger %I after insert or update or delete or truncate on %I for each statement execute function agoston_api.graphql_subscription();', 'trgsub_'||d_table_name, d_table_name);
    RAISE NOTICE 'Trigger % for auto subscription created', 'TRGSUB_'||d_table_name;
  end if;
END;
$$;
CREATE EVENT TRIGGER auto_subscription ON ddl_command_end EXECUTE FUNCTION agoston_api.auto_subscription();

CREATE OR REPLACE FUNCTION agoston_api.apply_auto_subscription()
    RETURNS boolean
    AS $$
declare
    t record;
begin
    for t in ( SELECT * FROM information_schema.tables WHERE lower(table_schema) = 'agoston_public' and table_type = 'BASE TABLE' ) loop
        execute format('create or replace trigger %I after insert or update or delete or truncate on %I for each statement execute function agoston_api.graphql_subscription();', 'trgsub_'||t.table_name, t.table_name);
        RAISE NOTICE 'Trigger % for auto subscription created', 'TRGSUB_'||t.table_name;
    end loop;
    RETURN true;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION agoston_api.add_user OWNER TO ##POSTGRAPHILE_USER##;

select agoston_api.apply_auto_subscription();
