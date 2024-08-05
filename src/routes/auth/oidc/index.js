const Router = require('express-promise-router')
const passport = require('passport');
const db = require('../../../db-pool-postgraphile');
const { backendOrigin, authOidc, authOidcTimeout } = require('../../../config-environment')
var { custom, Issuer, Strategy } = require('openid-client');
const { buildAuthState } = require('../../../helpers')

const router = new Router()
module.exports = router

custom.setHttpOptionsDefaults({
    timeout: authOidcTimeout,
});

console.log(`INFO | AUTH_OIDC | Starting configuration using following input: ${JSON.stringify(authOidc, null, 2)}`);

authOidc.forEach(function (oidcConfig) {

    if (oidcConfig.enable || false) {
        console.log(`INFO | AUTH_OIDC[${oidcConfig.name}]: adding oidc issuer...`);

        Issuer.discover(oidcConfig.params.domain).then(issuer => {

            console.log('INFO | AUTH_OIDC[%s]: Discovered issuer %s %O', oidcConfig.name, issuer.issuer, issuer.metadata);

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
                    async function (tokenSet, userinfo, done) {
                        console.log(`INFO | AUTH_OIDC[${oidcConfig.name}]: userinfo => ${JSON.stringify(userinfo.claims())}`)
                        var u = userinfo.claims()
                        let result;
                        try {
                            result = await db.query('SELECT user_id, role_name, auth_provider, auth_subject, auth_data from agoston_api.set_authenticated_user(p_provider => $1, p_subject => $2, p_raw => $3) as (user_id int, role_name text, auth_provider text, auth_subject text, auth_data text)', [
                                oidcConfig.name,
                                u.sub,
                                u
                            ])
                        } catch (err) {
                            console.error(`ERROR | AUTH_OIDC[${oidcConfig.name}]: query error: ${err.message}`);
                            return done(null, null)
                        }
                        return done(null, result.rows[0]);
                    }
                ));


            router.get(`/${oidcConfig.name}`, (req, res, next) => {
                passport.authenticate(oidcConfig.name, { scope: oidcConfig.params.scope, state: buildAuthState(req) })(req, res, next);
            });

            router.get(`/${oidcConfig.name}/callback`, function (req, res, next) {
                passport.authenticate(oidcConfig.name, function (err, user, info, status) {
                    console.log(`INFO | AUTH_OIDC[${oidcConfig.name}]: info:${info}, status: ${status}`)
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

        }).catch(error => console.error(`ERROR | AUTH_OIDC[${oidcConfig.name}]: failed: ${error}`));
    } else {
        console.log(`INFO | AUTH_OIDC[${oidcConfig.name}]: is disabled.`);
    }

});


