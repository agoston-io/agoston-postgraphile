-- Ression data
CREATE OR REPLACE FUNCTION agoston_public.session(
	)
    RETURNS jsonb
    LANGUAGE 'sql'
    COST 100
    STABLE PARALLEL UNSAFE
AS
$BODY$
    select jsonb_build_object(
      'role', current_user,
      'is_authenticated', current_setting('session.is_authenticated', true)::boolean,
      'user_id', current_setting('session.user_id', true)::int,
      'session_id', current_setting('session.id', true)::text
    );
$BODY$;

-- Insert default anonymous user
insert into agoston_identity.user_identities (id, user_role_id ) values (0, 1) on conflict do nothing;
