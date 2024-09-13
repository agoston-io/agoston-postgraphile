const Router = require('express-promise-router')
const { authStrategies, authStrategiesAvailable, authOidc, version, backendOrigin, pgPostgresUri, pgpSchema, pgDefaultAnonymousRole } = require('../../config-environment')
const { watchPostGraphileSchema, withPostGraphileContext } = require('postgraphile');
const { getPgSettings } = require('../../helpers');
const { graphql } = require('graphql');
const logger = require('../../log')
const { pgPoolPostgraphile } = require('./../../db-pool-postgraphile');
const PgSimplifyInflectorPlugin = require("@graphile-contrib/pg-simplify-inflector");
const PgAggregatesPlugin = require("@graphile/pg-aggregates").default;

const router = new Router()
module.exports = router

// For custom local configuration queries.
// Avoid client round trip when calling the configuration file with a custom GraphQL query.
let graphqlSchema;
watchPostGraphileSchema(
    pgPostgresUri,
    pgpSchema,
    {
        dynamicJson: true,
        appendPlugins: [
            PgAggregatesPlugin,
            PgSimplifyInflectorPlugin
        ],
    },
    (newSchema) => {
        graphqlSchema = newSchema;
    },
).then(() => { logger.info("CONFIGURATION | GraphQL schema generated and watched.") })
    .catch(error => { logger.error(error) });

async function performQuery(graphqlSchema, req, query, variables, operationName = null) {
    return await withPostGraphileContext(
        {
            pgPool: pgPoolPostgraphile,
            pgSettings: getPgSettings(req, pgDefaultAnonymousRole),
        },
        async context => {
            return await graphql(
                graphqlSchema,
                query,
                null,
                { ...context },
                variables,
                operationName
            );
        }
    );
}

router.get('/configuration', async (req, res) => {
    var authStrategiesWithLinkExposed = {}
    var authStrategiesWithoutLinkExposed = {}
    for (const strategy of authStrategiesAvailable) {
        if (!strategy.hasAuthLink) {
            authStrategiesWithoutLinkExposed[strategy.name] = {
                type: 'passport',
                has_auth_link: strategy.hasAuthLink,
                auth_link: strategy.hasAuthLink ? `${backendOrigin}/auth/${strategy.name}` : null,
                post_auth_endpoint: strategy.name === 'user-pwd' ? `${backendOrigin}/auth/user-pwd/login` : null,
                patch_auth_endpoint: strategy.name === 'user-pwd' ? `${backendOrigin}/auth/user-pwd/login` : null,
                post_signup_endpoint: strategy.name === 'user-pwd' ? `${backendOrigin}/auth/user-pwd/signup` : null,
                is_cookie_based: strategy.isCookieBased,
                enable: authStrategies[strategy.name]?.enable || false
            }
        }
    }
    for (const strategy of authStrategiesAvailable) {
        if (strategy.hasAuthLink) {
            authStrategiesWithLinkExposed[strategy.name] = {
                type: 'passport',
                has_auth_link: strategy.hasAuthLink,
                auth_link: strategy.hasAuthLink ? `${backendOrigin}/auth/${strategy.name}` : null,
                is_cookie_based: strategy.isCookieBased,
                enable: authStrategies[strategy.name]?.enable || false
            };
        }
    }
    for (const oidcConfig of authOidc) {
        authStrategiesWithLinkExposed[oidcConfig.name] = {
            type: 'oidc',
            has_auth_link: true,
            auth_link: `${backendOrigin}/auth/oidc/${oidcConfig.name}`,
            is_cookie_based: true,
            enable: true
        };
    }

    // Get current session data
    var currentSession = await performQuery(graphqlSchema, req, `query {session}`)

    // Execute custom query if any
    var customGraphQLQueryResult = null
    if (req.query.gq !== undefined) {
        graphQlQuery = decodeURI(req.query.gq)
        graphQlQueryVariables = null
        if (req.query.gqv !== undefined) {
            graphQlQueryVariables = JSON.parse(decodeURI(req.query.gqv))
        }
        customGraphQLQueryResult = await performQuery(graphqlSchema, req, graphQlQuery, graphQlQueryVariables)
    }

    res.header("Content-Type", 'application/json');
    var body = {
        version: version,
        graphiql: `${backendOrigin}/data/graphiql`,
        endpoints: {
            graphql: `${backendOrigin}/data/graphql`,
            graphql_ws: `wss://${backendOrigin.replace(/^https?:\/\//, '')}/data/graphql`,
        },
        authentication: {
            logout_link: `${backendOrigin}/auth/logout`,
            logout_link: `${backendOrigin}/auth/logout`,
            session_link: `${backendOrigin}/auth/session`,
            with_link: authStrategiesWithLinkExposed,
            without_link: authStrategiesWithoutLinkExposed,
        },
        currentSession: currentSession.data?.session || null,
        customGraphQLQueryResult: customGraphQLQueryResult
    }
    res.send(JSON.stringify(body, null, 4));
})
