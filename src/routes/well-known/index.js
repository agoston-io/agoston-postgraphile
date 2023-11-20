const Router = require('express-promise-router')
const { authStrategies, authStrategiesAvailable, authOidc, version, backendOrigin } = require('../../config-environment')

const router = new Router()
module.exports = router

router.get('/configuration', (req, res) => {
    var authStrategiesWithLinkExposed = {}
    var authStrategiesWithoutLinkExposed = {}
    for (const strategy of authStrategiesAvailable) {
        if (!strategy.hasAuthLink) {
            authStrategiesWithoutLinkExposed[strategy.name] = {
                type: 'passport',
                has_auth_link: strategy.hasAuthLink,
                auth_link: strategy.hasAuthLink ? `${backendOrigin}/auth/${strategy.name}` : null,
                post_auth_endpoint: strategy.name === 'user-pwd' ? `${backendOrigin}/auth/user-pwd` : null,
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
        }
    }
    res.send(JSON.stringify(body, null, 4));
})
