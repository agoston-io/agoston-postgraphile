-- Schema
CREATE SCHEMA agoston_metadata;

CREATE SCHEMA agoston_api;

CREATE SCHEMA agoston_public;

CREATE SCHEMA agoston_identity;


-- Ownership
ALTER SCHEMA agoston_metadata OWNER TO "##POSTGRAPHILE_USER##";

ALTER SCHEMA agoston_api OWNER TO "##POSTGRAPHILE_USER##";

ALTER SCHEMA agoston_public OWNER TO "##POSTGRAPHILE_USER##";

ALTER SCHEMA agoston_identity OWNER TO "##POSTGRAPHILE_USER##";
