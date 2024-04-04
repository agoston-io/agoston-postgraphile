CREATE OR REPLACE FUNCTION agoston_api.graphql_subscription()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'agoston_public', 'agoston_api', 'agoston_identity', 'agoston_metadata', 'agoston_job', 'public'
AS $function$
DECLARE
  v_topic text;
  v_sub text;
  v_record record;
  v_exception_message text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_record = new;
  elsif TG_OP = 'UPDATE' THEN
    v_record = new;
  elsif TG_OP = 'DELETE' THEN
    v_record = old;
  END IF;
  IF TG_ARGV[0] IS NOT NULL THEN
    EXECUTE 'select $1.' || quote_ident(TG_ARGV[0])
    USING v_record INTO v_sub;
    v_topic = lower(TG_TABLE_NAME || ':' || TG_ARGV[0] || ':' || v_sub);
  ELSE
    v_topic = lower(TG_TABLE_NAME);
  END IF;
    IF v_topic IS NOT NULL THEN
      begin
          PERFORM pg_notify('postgraphile:' || v_topic, json_build_object('event', TG_OP, 'topic', v_topic)::text);
	  exception when others then
		  GET STACKED DIAGNOSTICS v_exception_message = MESSAGE_TEXT;
		  RAISE NOTICE 'exception (graphql_subscription) => % (%)', v_exception_message, 'postgraphile:' || v_topic;
	  end;
    END IF;
    RETURN v_record;
END;
$function$
;
