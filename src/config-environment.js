const version = require('./package.json').version;
const authStrategiesAvailable = require('./package.json').authStrategiesAvailable;
const helpers = require('./helpers');

const pgHost = process.env.PGHOST || 'postgres';
const pgPostgresPort = parseInt(process.env.PGPORT || 5432);
const pgPostgresDatabase = process.env.PGDATABASE || 'agoston';
const pgPostgresPassword = process.env.POSTGRES_PASSWORD || 'agoston';
const pgDeveloperUser = process.env.DEVELOPER_USER || 'developer';
const pgDeveloperPassword = process.env.DEVELOPER_PASSWORD || 'agoston';
const pgPostgraphileUser = process.env.POSTGRAPHILE_USER || 'postgraphile';
const pgPostgraphilePassword = process.env.POSTGRAPHILE_PASSWORD || 'agoston';

module.exports = {
    version: version,
    versionMajor: version.split('.')[0],
    versionMinor: version.split('.')[1],
    versionPatch: version.split('.')[2],
    debug: parseInt(process.env.DEBUG || 0),
    authStrategiesAvailable: authStrategiesAvailable,
    environment: process.env.ENVIRONMENT_NAME || 'production',
    backendHttpListening: helpers.stringToBoolean(process.env.HTTP_LISTENING || true),
    backendHttpPortListening: parseInt(process.env.HTTP_PORT_LISTENING || 8080),
    backendHttpsListening: helpers.stringToBoolean(process.env.HTTPS_LISTENING || false),
    backendHttpsPortListening: parseInt(process.env.HTTPS_PORT_LISTENING || 8043),
    backendHttpsCertificate: process.env.HTTPS_PORT_CERTIFICATE || '/tmp/server.crt',
    backendHttpsPrivateKey: process.env.HTTPS_PORT_PRIVATEKEY || '/tmp/server.key',
    backendOrigin: process.env.HTTP_BACKEND_ORIGIN || '',
    corsOrigins: helpers.formatCORSInput(`${process.env.HTTP_BACKEND_ORIGIN || ''},${process.env.CORS_ORIGIN || ''}`),
    pgDefaultAnonymousRole: "anonymous",
    pgPostgresPassword: pgPostgresPassword,
    pgPostgresPort: pgPostgresPort,
    pgPostgresDatabase: pgPostgresDatabase,
    pgPostgresUri: `postgres://postgres:${pgPostgresPassword}@${pgHost}:${pgPostgresPort}/${pgPostgresDatabase}?sslmode=disable`,
    pgPostgraphileUser: pgPostgraphileUser,
    pgPostgraphilePassword: pgPostgraphilePassword,
    pgPostgraphileUri: `postgres://${pgPostgraphileUser}:${pgPostgraphilePassword}@${pgHost}:${pgPostgresPort}/${pgPostgresDatabase}?sslmode=disable`,
    pgpSchema: 'agoston_public',
    pgDeveloperUser: pgDeveloperUser,
    pgDeveloperPassword: pgDeveloperPassword,
    pgDeveloperUri: `postgres://${pgDeveloperUser}:${pgDeveloperPassword}@${pgHost}:${pgPostgresPort}/${pgPostgresDatabase}?sslmode=disable`,
    sessionCookieSecret: process.env.SESSION_COOKIE_SECRET || 'agoston',
    recaptchaSecretKey: process.env.RECAPTCHA_SECRET_KEY,
    recaptchaScoreThreshold: process.env.RECAPTCHA_SCORE_THRESHOLD || 0.7,
    authStrategies: JSON.parse(process.env.AUTH_STRATEGIES || '{}'),
    authOidc: JSON.parse(process.env.AUTH_OIDC || '[]'),
    authOidcTimeout: parseInt(process.env.AUTH_OIDC_TIMEOUT || 10000),
    stripeHookEnable: helpers.stringToBoolean(process.env.STRIPE_HOOK_ENABLE) || false,
    stripeApiKey: process.env.STRIPE_API_KEY || '',
    stripeHookEndPointSecret: process.env.STRIPE_HOOK_ENDPOINT_SECRET || '',
    // Worker
    workerSchema: process.env.WORKER_SCHEMA || 'agoston_job',
    workerCronJobLimit: parseInt(process.env.WORKER_CRON_JOB_LIMIT || 10),
    workerConcurrency: parseInt(process.env.WORKER_CONCURRENCY || 5),
    workerPollInterval: parseInt(process.env.WORKER_POLL_INTERVAL || 1000),
    workerEmailEnable: helpers.getBoolean(process.env.WORKER_EMAIL_ENABLE || false),
    workerStmpHost: process.env.WORKER_EMAIL_SMTP_HOST || '',
    workerStmpPort: parseInt(process.env.WORKER_EMAIL_SMTP_PORT || 25),
    workerStmpSecure: helpers.getBoolean(process.env.WORKER_EMAIL_SMTP_SECURE || true),
    workerStmpAuthUser: process.env.WORKER_EMAIL_SMTP_AUTH_USER || '',
    workerStmpAuthPass: process.env.WORKER_EMAIL_SMTP_AUTH_PASS || '',
    // Upload
    UploadDirName: process.env.UPLOAD_DIR_NAME || './uploads'
}
