-- new private schema for developers
create schema agoston_private;
alter schema agoston_private owner to "##POSTGRAPHILE_USER##";
grant create, usage on schema agoston_private to "##DEVELOPER_USER##";
grant usage on schema agoston_private to anonymous;
grant usage on schema agoston_private to authenticated;
