const Router = require('express-promise-router')
const { postgraphile, makePluginHook } = require("postgraphile");
const { default: PgPubsub } = require("@graphile/pg-pubsub");
const PgSimplifyInflectorPlugin = require("@graphile-contrib/pg-simplify-inflector");
const PgAggregatesPlugin = require("@graphile/pg-aggregates").default;
const { environment, pgpSchema, pgPostgresUri, pgPostgraphileUri, pgDefaultAnonymousRole } = require('../config-environment')

const router = new Router()
module.exports = router

const pluginHook = makePluginHook([
    PgPubsub,
    require("@graphile/operation-hooks").default
]);

function getPgRole(req) {
    if (req.user === undefined) {
        return pgDefaultAnonymousRole;
    }
    return req.user.role_name;
}
function getAuthProvider(req) {
    if (req.user === undefined) {
        return null;
    }
    return req.user.auth_provider;
}
function getAuthSubject(req) {
    if (req.user === undefined) {
        return null;
    }
    return req.user.auth_subject;
}
function getAuthData(req) {
    if (req.user === undefined) {
        return null;
    }
    return req.user.auth_data;
}
function getSessionId(req) {
    if (req.sessionID === undefined) {
        return 'no-session-id';
    }
    return req.sessionID;
}
function isSessionAuthenticated(req) {
    if (req.user === undefined) {
        return false;
    }
    return true;
}
function getPgUserId(req) {
    if (req.user === undefined) {
        return 0;
    }
    return req.user.user_id;
}

const postgraphileOptions = {
    pluginHook,
    appendPlugins: [
        PgAggregatesPlugin,
        PgSimplifyInflectorPlugin,
        require("../postgraphile-hooks/recaptcha.js")
    ],
    websocketMiddlewares: [
        require('../expressSession').get(),
        require('passport').authenticate('session'),
    ],
    pgSettings: async req => ({
        'role': getPgRole(req),
        'session.id': getSessionId(req),
        'session.is_authenticated': isSessionAuthenticated(req),
        'session.user_id': getPgUserId(req),
        'session.auth_provider': getAuthProvider(req),
        'session.auth_subject': getAuthSubject(req),
        'session.auth_data': getAuthData(req),
    }),
    retryOnInitFail: true,
    pgExtendedTypes: true,
    subscriptions: true,
    simpleSubscriptions: true,
    pgStrictFunctions: true,
    disableDefaultMutations: false,
    dynamicJson: true,
    enableQueryBatching: true,
    disableQueryLog: true,
    ignoreRBAC: true,
    noSetofFunctionsContainNulls: true,
    async additionalGraphQLContextFromRequest(req, res) {
        return {
            user: req.user,
            getHeader(name) {
                return req.get(name);
            },

        };
    },
};

// User environment
switch (environment) {
    case 'development':
        postgraphileOptions.watchPg = true;
        postgraphileOptions.graphiql = true;
        postgraphileOptions.enhanceGraphiql = true;
        postgraphileOptions.ownerConnectionString = pgPostgresUri;
        postgraphileOptions.showErrorStack = "json";
        postgraphileOptions.extendedErrors = ['severity', 'code', 'detail', 'hint', 'position', 'internalPosition', 'internalQuery', 'where', 'schema', 'table', 'column', 'dataType', 'constraint', 'file', 'line', 'routine'];
        break;
    case 'production':
        postgraphileOptions.watchPg = false;
        postgraphileOptions.graphiql = false;
        postgraphileOptions.enhanceGraphiql = false;
        postgraphileOptions.extendedErrors = ["errcode"];
        break;
    default:
        throw `Unknown environment '${environment}'.`;
}


router.use('/', postgraphile(
    pgPostgraphileUri,
    pgpSchema,
    postgraphileOptions
));
