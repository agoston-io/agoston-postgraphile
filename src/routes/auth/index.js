const Router = require('express-promise-router')
const { getAuthStrategiesAvailable, authStrategyIsEnable, deriveAuthRedirectUrl } = require('../../helpers')
const logger = require('../../log')

const { authStrategies, authStrategiesAvailable, authOidc, version } = require('../../config-environment')
const oidc = require('./oidc')


const router = new Router()
module.exports = router

router.get(`/session`, (req, res) => {
    var hasSession = false
    if (req.user !== undefined) {
        if (req.user.user_id > 0) {
            var hasSession = true
        }
    }
    res.render('auth', {
        version: version,
        authStrategiesAvailable: authStrategiesAvailable,
        authStrategies: authStrategies,
        authOidc: authOidc,
        hasSession: hasSession,
        session: req.session,
        user: req.user,
        authStrategyIsEnable: authStrategyIsEnable,
    })
})

for (const authStrategy of getAuthStrategiesAvailable('cookie-based')) {
    if (authStrategyIsEnable(authStrategy)) {
        router.use(require(`./${authStrategy.name}`))
    }
}

router.use('/oidc', oidc)

router.get(`/logout`, (req, res) => {
    var logout_frontend_redirect_url = deriveAuthRedirectUrl(req, 'auth_redirect_logout');
    logger.debug(`logout_frontend_redirect_url => ${logout_frontend_redirect_url}`)
    logger.debug(`req.session => ${JSON.stringify(req.session)}`)
    var logout_redirect_url = logout_frontend_redirect_url
    if (req.session?.passport?.user?.oidc?.issuer_metadata?.end_session_endpoint != undefined) {
        logout_redirect_url = req.session?.passport?.user?.oidc?.issuer_metadata?.end_session_endpoint + '?id_token_hint=' + req.session?.passport?.user?.oidc?.session_id_token + '&post_logout_redirect_uri=' + logout_frontend_redirect_url;
    }
    logger.debug(`logout_redirect_url => ${logout_redirect_url}`)
    req.session.destroy(function (err) {
        res.redirect(logout_redirect_url);
    });
})

router.post(`/logout`, (req, res) => {
    if (req.session.hasOwnProperty("passport")) {
        if (req.session.passport.hasOwnProperty("user")) {
            if (req.session.passport.user.hasOwnProperty("role_name")) {
                if (req.session.passport.user.role_name === 'authenticated') {
                    req.session.destroy(function (err) {
                        res.status(201).json({
                            message: 'session destroyed'
                        });
                    });
                }
            }
        }
    } else {
        res.status(404).json({
            message: 'session unknown'
        });
    }
})
