# Agoston

Build and scale Apps like a team of experts in a week.

Agoston extends the powerful [Postgraphile](https://github.com/graphile/crystal/tree/main/postgraphile/postgraphile) with all the features you need to develop a complete, full-stack, application:

- Authentication: Google, Facebook, Github, Auth0, OIDC, HTTP Bearer token, user/password.
- Session: Agoston creates a user session and stores it in the Postgres database.
- User permissions: In Postgres, requests are identified with an `user_id` to allow fine-grained permissions with Postgres RLS.
- [Files upload](https://github.com/graphile-contrib/postgraphile-upload-example): Upload files to your backend via standard GraphQL mutation.
- [Job queue](https://worker.graphile.org/docs): Job queue which uses PostgreSQL to store jobs, and executes them on Node.js.
- [Recurring tasks (crontab)](https://worker.graphile.org/docs/cron): Recurring tasks according to a cron-like schedule.

## Cloud deployment

We provide Agoston in the cloud if your don't want to bother with the technical implementation.
Create an account here: [https://agoston.io/](https://agoston.io/).

## Run backend

```bash
docker compose -f ./docker-compose.yml up
```

### To restart on a fresh environment (with new db)

```bash
docker rm agoston-postgraphile-postgres-1 agoston-postgraphile-postgraphile-1
docker rmi agoston-postgraphile-dev
```

## Backend configuration

```bash
#---------- HTTP configuration
export HTTP_LISTENING=1
export HTTP_PORT_LISTENING=8080
#---------- HTTPS configuration
export HTTPS_LISTENING=0
export HTTPS_PORT_LISTENING=8043
export HTTPS_PORT_CERTIFICATE=/tmp/server.crt
export HTTPS_PORT_PRIVATEKEY=/tmp/server.key
#---------- All
export ENVIRONMENT_NAME=development
export HTTP_BACKEND_ORIGIN='https://graphile.agoston-dev.io'
export PGHOST=localhost
export PGDATABASE=agoston-1
export POSTGRES_PASSWORD=agoston
export POSTGRAPHILE_USER='postgraphile-1'
export POSTGRAPHILE_PASSWORD=agoston
export DEVELOPER_USER='developer-1'
export DEVELOPER_PASSWORD=agoston
export CORS_ORIGIN='https://127.0.0.1:5173'
export SESSION_COOKIE_SECRET=JWaaEHOnJyMYvB06Q0cqRDhMgRpD0Cfy
#---------- Recaptcha
export RECAPTCHA_SCORE_THRESHOLD=
export RECAPTCHA_SECRET_KEY=
#---------- Auth
export AUTH_STRATEGIES='{"http-bearer": {"enable": true}, "user-pwd": {"enable": true }}'
export AUTH_OIDC='[]'
#---------- Stripe
export STRIPE_HOOK_ENABLE=true
export STRIPE_API_KEY=
export STRIPE_HOOK_ENDPOINT_SECRET=
#---------- Env
export NODE_ENV=development
#---------- Worker
export GRAPHILE_LOGGER_DEBUG=1
export WORKER_SCHEMA=
export WORKER_CRON_JOB_LIMIT=10
export WORKER_CONCURRENCY=5
export WORKER_POLL_INTERVAL=1000
export WORKER_EMAIL_ENABLE=false
export WORKER_EMAIL_SMTP_HOST=
export WORKER_EMAIL_SMTP_PORT=25
export WORKER_EMAIL_SMTP_SECURE=true
export WORKER_EMAIL_SMTP_AUTH_USER=
export WORKER_EMAIL_SMTP_AUTH_PASS=
#---------- GraphQL upload file location
export UPLOAD_DIR_NAME='./uploads'
```

## Test

```bash
. ./src/test/test_environment.sh
# export SKIP_FINAL_CLEANUP=1
./src/test/test.sh
```

## Stripe hook

```
stripe listen --forward-to localhost:4000/hook/stripe
```

## GraphQL file upload

To turn a GrahpQL attribute to an `upload` data type and thus accept uploads through GraphQL mutations, you must add a Postgraphile tag `@upload` in the table column. Such a column will then receive the file path and file metadata, and the file will be uploaded in the upload directory defined by `UPLOAD_DIR_NAME` (default value: `./uploads`). Example:

```
comment on column post.header_image_file is E'@upload';
```

**NOTE**: You may need to adjust the reverse proxy configuration to allow bigger file uploads (e.g., `client_max_body_size 64M;` in nginx). Otherwise, the client would receive a `HTTP 413 (Request Entity Too Large)` error.
