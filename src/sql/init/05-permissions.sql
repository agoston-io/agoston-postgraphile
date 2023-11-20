-- Lock down public
REVOKE ALL ON SCHEMA public FROM public;

GRANT ALL privileges ON SCHEMA public TO "##POSTGRAPHILE_USER##";

GRANT usage ON SCHEMA public TO "##DEVELOPER_USER##";


-- permissions for all groups
GRANT usage ON SCHEMA agoston_api TO public;

-- permissions for "##DEVELOPER_USER##"
GRANT CREATE, usage ON SCHEMA agoston_public TO "##DEVELOPER_USER##";

GRANT usage ON SCHEMA agoston_identity TO "##DEVELOPER_USER##";
