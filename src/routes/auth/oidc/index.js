const Router = require('express-promise-router')
const passport = require('passport');
const db = require('../../../db-pool-postgraphile');
const { backendOrigin, authOidc, authOidcTimeout } = require('../../../config-environment')
const logger = require('../../../log')
var { custom, Issuer, Strategy } = require('openid-client');
const { buildAuthState } = require('../../../helpers')

const router = new Router()
module.exports = router

custom.setHttpOptionsDefaults({
    timeout: authOidcTimeout,
});

logger.debug(`AUTH_OIDC | Starting configuration using following input: ${JSON.stringify(authOidc, null, 4)}`);

authOidc.forEach(function (oidcConfig) {

    if (oidcConfig.enable || false) {
        logger.info(`AUTH_OIDC[${oidcConfig.name}]: adding oidc issuer...`);

        Issuer.discover(oidcConfig.params.domain).then(issuer => {

            logger.info(`AUTH_OIDC[${oidcConfig.name}]: Discovered issuer ${issuer.issuer} ${JSON.stringify(issuer.metadata, null, 4)}`);

            var client = new issuer.Client({
                client_id: oidcConfig.params.clientId,
                client_secret: oidcConfig.params.clientSecret,
                redirect_uris: [`${backendOrigin}/auth/oidc/${oidcConfig.name}/callback`],
                response_types: [oidcConfig.params.responseTypes],
            });

            passport.use(
                oidcConfig.name,
                new Strategy({
                    client: client,
                    passReqToCallback: true
                },
                    async function (tokenset, userinfo, done) {
                        logger.debug(`AUTH_OIDC[${oidcConfig.name}]: id_token => ${JSON.stringify(userinfo.id_token)}`)
                        logger.debug(`AUTH_OIDC[${oidcConfig.name}]: userinfo => ${JSON.stringify(userinfo.claims())}`)
                        var userPayload = userinfo.claims()
                        let result;
                        try {
                            result = await db.query('SELECT * from agoston_api.set_authenticated_user(p_provider => $1, p_subject => $2, p_raw => $3)', [
                                oidcConfig.name,
                                userPayload.sub,
                                userPayload
                            ])
                        } catch (err) {
                            logger.error(`ERROR | AUTH_OIDC[${oidcConfig.name}]: query error: ${err.message}`);
                            return done(null, null)
                        }
                        // the ID token is stored into the user_sessions table
                        return done(null, { ...result.rows[0], ...{ oidc: { issuer_name: oidcConfig.name, issuer_metadata: issuer.metadata, session_id_token: userinfo.id_token } } });
                    }
                ));


            router.get(`/${oidcConfig.name}`, (req, res, next) => {
                passport.authenticate(oidcConfig.name, { scope: oidcConfig.params.scope, state: buildAuthState(req) })(req, res, next);
            });

            router.get(`/${oidcConfig.name}/callback`, function (req, res, next) {
                passport.authenticate(oidcConfig.name, function (err, user, info, status) {
                    logger.debug(`AUTH_OIDC[${oidcConfig.name}]: info:${JSON.stringify(info)}, status: ${status}`)
                    if (err) {
                        res.redirect(`${JSON.parse(req.query.state).r.error}?message=bad-request&error=${encodeURI(err.message)}`);
                        return
                    }
                    if (!user) {
                        res.redirect(`${JSON.parse(req.query.state).r.error}?message=login-failed`);
                        return
                    }
                    req.logIn(user, function (err) {
                        if (err) {
                            res.redirect(`${JSON.parse(req.query.state).r.error}?message=internal-error&error=${encodeURI(err.message)}`);
                            return
                        }
                        res.redirect(`${JSON.parse(req.query.state).r.success}?message=login-success`);
                        return
                    });
                })(req, res, next)
            });

        }).catch(error => logger.error(`AUTH_OIDC[${oidcConfig.name}]: failed: ${error}`));
    } else {
        logger.info(`AUTH_OIDC[${oidcConfig.name}]: is disabled.`);
    }

});


