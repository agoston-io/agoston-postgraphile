drop FUNCTION if exists agoston_api.set_user_role (p_user_id int DEFAULT NULL, p_role_id int DEFAULT NULL);
drop FUNCTION if exists agoston_api.add_user_role ( p_role_name text );
drop FUNCTION if exists agoston_api.rename_user_role ( p_role_id int, p_new_role_name text );
drop FUNCTION if exists agoston_api.delete_user_role ( p_role_id int );
drop FUNCTION if exists agoston_api.set_default_role_id_when_anonymous (p_role_id int);
drop FUNCTION if exists agoston_api.get_default_role_id_when_anonymous ();
drop FUNCTION if exists agoston_api.set_default_role_id_when_authenticated (p_role_id int);
drop FUNCTION if exists agoston_api.get_default_role_id_when_authenticated ();
drop FUNCTION if exists agoston_api.get_default_role_name_when_anonymous ();
drop FUNCTION if exists agoston_api.add_user (p_role_id int DEFAULT NULL);
alter table agoston_identity.user_roles drop column is_authenticated_default;
alter table agoston_identity.user_roles drop column is_anonymous_default;
drop sequence if exists agoston_identity.user_roles_id_seq;

--

CREATE OR REPLACE FUNCTION agoston_api.add_user ()
    RETURNS int
    AS $$
DECLARE
    v_user_id integer := NULL;
BEGIN
    INSERT INTO agoston_identity.user_identities (id)
        VALUES (nextval('agoston_identity.user_identities_id_seq'))
    RETURNING
        id INTO v_user_id;
    RETURN v_user_id;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION agoston_api.add_user OWNER TO "##POSTGRAPHILE_USER##";
