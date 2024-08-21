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

```bash
## Switch to a revious version
git checkout v3.14.3
cd src/
rm -rf ./node_modules/
npm i
cd ..
```

### Access GraphiQL

- HTTP: http://graphile.agoston.dev.local:8080/data/graphiql
- HTTPS: https://graphile.agoston.dev.local:8043/data/graphiql

### Connect to the Postgres database

```bash
psql postgresql://postgres:agoston@localhost:5552/agoston
```

### To restart on a fresh environment (with new db)

```bash
docker rm agoston-postgraphile-postgres-1 agoston-postgraphile-postgraphile-1; \
docker rmi agoston-postgraphile-dev agoston-postgres-dev
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
export HTTP_BACKEND_ORIGIN='https://graphile.agoston.dev.local'
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

## Tests

```bash
# export SKIP_FINAL_CLEANUP=1
./tests/run.sh
```

## Authentication

### HTTP Bearer

You can enable the HTTP Bearer authentication by appending the following configuration to the `AUTH_STRATEGIES` run time environment variable:

```json
{
  "http-bearer": {
    "enable": true
  }
}
```

#### Generate a token for a user

Generate a bearer token for a user (or a new user created on the fly with `agoston_api.add_user()`):

```sql
select set_user_token(p_user_id => 1) as "token";
select set_user_token(p_user_id => agoston_api.add_user()) as "token";
                                                             token
-------------------------------------------------------------------------------------------------------------------------------
 uYNtAHQ5tRuByn8X7WBaK6TQRSdA9EzbR7zn8lq7tnJntfnwksLGVbnn2BxhhYj14RrnE2REB2Uxx11luAuGGP5afmQNQp4tR7vHd992wNXGfn6X2AF
(1 row)
```

#### Example without bearer token

```bash
$ curl -s -X POST \
-H "Content-Type: application/json" \
-d '{"query": "query {session}"}' \
'http://localhost:8080/data/graphql' | jq
```

```json
{
  "data": {
    "session": {
      "role": "anonymous",
      "user_id": 0,
      "auth_data": null,
      "session_id": "iDYWVlGp5OYU6JyEd3zfOZH5RFVRwaZ0",
      "auth_subject": null,
      "auth_provider": null,
      "is_authenticated": false
    }
  }
}
```

#### Example with bearer token

```bash
curl -s -X POST \
-H ""Authorization": Bearer uYNtAHQ5tRuByn8X7WBaK6TQRSdA9EzbR7zn8lq7tnJntfnwksLGVbnn2BxhhYj14RrnE2REB2Uxx11luAuGGP5afmQNQp4tR7vHd992wNXGfn6X2AF" \
-H "Content-Type: application/json" \
-d '{"query": "query {session}"}' \
'http://localhost:8080/data/graphql' | jq
```

```json
{
  "data": {
    "session": {
      "role": "authenticated",
      "user_id": 1,
      "auth_data": {},
      "session_id": "PPDqL4IwaIZ3WmQmGyz5e_bV_iWgFnBj",
      "auth_subject": "1",
      "auth_provider": "http-bearer",
      "is_authenticated": true
    }
  }
}
```

### Local user and password

You can enable the local user and password authentication by appending the following configuration to the `AUTH_STRATEGIES` run time environment variable:

```json
{
  "user-pwd": {
    "enable": true,
    "params": {
      "usernameComplexityPattern": "^[a-z0-9-_.@]{5,}$",
      "passwordComplexityPattern": "^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$%^&*,-_])(?=.{8,})"
    }
  }
}
```

## Backend run time configuration

You can see the run-time configuration that the backend uses by calling the URL `<HTTP_BACKEND_ORIGIN>/.well-known/configuration`:

```json
{
    "version": "3.11.1",
    "endpoints": {
        "graphql": "https://graphile.agoston.dev.local/data/graphql",
        "graphql_ws": "wss://graphile.agoston.dev.local/data/graphql"
    },
    ...
    // The JSON configuration will also show the session values:
    "currentSession": {
        "role": "authenticated",
        "user_id": 1,
        "auth_data": {
            "attr1": "val1",
            "attr2": "val2"
        },
        "session_id": "KzNcgOEk-HkpKQcrPGTY00VS57crj2G6",
        "auth_subject": "niolap2",
        "auth_provider": "user-pwd",
        "is_authenticated": true
    },
    // The JSON configuration can render an optional custom query:
    "customGraphQLQueryResult": {
        "data": {
            "post": {
                "id": 2
            }
        }
    }
}
```

### Custom query

You can also add a custom query as a URL parameter `?gq=` with optional query variables parameter `&gqv=`.
It's useful when you load from the frontend configuration and want to load some application data without having to perform an additional round trip to the backend.

- gq: a GraphQL query or mutation (no subscription supported) URL-encoded.
- gqv: a JSON string URL-encoded holding the variables of your graphQL query.

For instance:

```json
// $ curl 'http://localhost:8080/.well-known/configuration?gq=query%20MyQuery%28%24id%3A%20Int%20%3D%201%29%20%7B%0A%20%20post%28id%3A%20%24id%29%20%7B%0A%20%20%20%20id%0A%20%20%7D%0A%7D%0A&gqv=%7B%22id%22%3A2%7D'
{
    "version": "3.11.1",
    "endpoints": {
        "graphql": "https://graphile.agoston.dev.local/data/graphql",
        "graphql_ws": "wss://graphile.agoston.dev.local/data/graphql"
    },
    ...
    "customGraphQLQueryResult": {
        "data": {
            "post": {
                "id": 2
            }
        }
    }
}
```

## GraphQL file upload

To turn a GrahpQL attribute to an `upload` data type and thus accept uploads through GraphQL mutations, you must add a Postgraphile tag `@upload` in the table column. Such a column will then receive the file path and file metadata, and the file will be uploaded in the upload directory defined by `UPLOAD_DIR_NAME` (default value: `./uploads`). Example:

```
comment on column post.header_image_file is E'@upload';
```

**NOTE**: You may need to adjust the reverse proxy configuration to allow bigger file uploads (e.g., `client_max_body_size 64M;` in nginx). Otherwise, the client would receive a `HTTP 413 (Request Entity Too Large)` error.

## Stripe hook

```
stripe listen --forward-to localhost:4000/hook/stripe
```
