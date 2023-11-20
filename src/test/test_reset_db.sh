#!/bin/bash
set -x
set -e

echo "## Reseting database..."

sudo su - postgres -c "
sudo systemctl stop postgresql@15-main.service
sudo rm -rf /var/lib/postgresql/15/main
sudo mkdir -p /var/lib/postgresql/15/main
sudo chown -R postgres:postgres /var/lib/postgresql
/usr/lib/postgresql/15/bin/initdb /var/lib/postgresql/15/main -E utf8
sudo systemctl start postgresql@15-main.service
psql <<eos
create database \"agoston-1\" ;
create database \"agoston-2\";
create database \"agoston-3\";
ALTER USER postgres WITH PASSWORD 'agoston';
ALTER SYSTEM SET search_path=agoston_public,agoston_api,agoston_identity,agoston_metadata,agoston_job,public;
ALTER SYSTEM SET timezone='Europe/Zurich';
ALTER SYSTEM SET tcp_keepalives_idle=60;
select pg_reload_conf();
eos
sudo systemctl restart postgresql@15-main.service
"
