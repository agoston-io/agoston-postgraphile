do $$
begin
    if not exists( select 1 from pg_roles where lower(rolname) = lower('##DEVELOPER_USER##') ) then
        execute 'create role "##DEVELOPER_USER##" login password ''##DEVELOPER_PASSWORD##''';
    end if;
end $$;


do $$
begin
    if not exists( select 1 from pg_roles where lower(rolname) = lower('##POSTGRAPHILE_USER##') ) then
        execute 'create role "##POSTGRAPHILE_USER##" login password ''##POSTGRAPHILE_PASSWORD##''';
    end if;
end $$;

