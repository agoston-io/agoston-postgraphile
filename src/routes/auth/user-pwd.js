
const Router = require('express-promise-router');
const passport = require('passport');
const bodyParser = require('body-parser');
const { deriveAuthRedirectUrl, authStrategyGetParameterValue } = require('../../helpers');
const db = require('../../db-pool-postgraphile');
const logger = require('../../log');

const router = new Router()
module.exports = router

const LocalStrategy = require('passport-local').Strategy;
var createUserIfNotExits = authStrategyGetParameterValue('user-pwd', 'createUserIfNotExits');
if (typeof createUserIfNotExits !== 'boolean') { throw new Error('"createUserIfNotExits" is not a boolean!'); }
const usernameComplexityPattern = authStrategyGetParameterValue('user-pwd', 'usernameComplexityPattern');
if (typeof usernameComplexityPattern !== 'string') { throw new Error('"usernameComplexityPattern" is not a string!'); }
const passwordComplexityPattern = authStrategyGetParameterValue('user-pwd', 'passwordComplexityPattern');
if (typeof passwordComplexityPattern !== 'string') { throw new Error('"passwordComplexityPattern" is not a string!'); }

passport.use(new LocalStrategy({ passReqToCallback: true },
    async function verify(req, username, password, cb) {
        logger.debug(`req.path => ${req.path}`)
        if (req.path === '/user-pwd/signup') { createUserIfNotExits = true; }
        try {
            result = await db.query('select * from agoston_api.set_authenticated_user(p_provider => $1, p_subject => $2, p_raw => $3, p_password => $4, p_username_complexity_pattern => $5, p_password_complexity_pattern => $6, p_create_user_if_not_exits => $7)', [
                'user-pwd',
                username,
                req.body.free_value || {},
                password,
                usernameComplexityPattern,
                passwordComplexityPattern,
                createUserIfNotExits,
            ])
        } catch (err) {
            logger.error(`auth[passport-local] query error: ${err.message}`);
            return cb(err);
        }
        logger.debug(`result.rows[0] ${JSON.stringify(result.rows)}`)
        if (result.rows.length === 0) { return cb(null, false, { message: 'user-not-found' }); }
        return cb(null, result.rows[0], { scope: 'all' });
    }
));

router.post('/user-pwd/login', bodyParser.json(), function (req, res, next) {
    passport.authenticate('local', function (err, user, info, status) {
        var skipRedirect = (req.query?.redirect === "false");
        if (err) {
            if (skipRedirect) {
                res.status(400).json({ message: err.message });
            } else {
                res.redirect(`${deriveAuthRedirectUrl(req, 'auth_redirect_error')}?message=bad-request&error=${encodeURI(err.message)}`);
            }
            return
        }
        if (!user) {
            if (skipRedirect) {
                res.status(401).json({ message: 'not-found' });
            } else {
                res.redirect(`${deriveAuthRedirectUrl(req, 'auth_redirect_error')}?message=not-found`);
            }
            return
        }
        req.logIn(user, function (err) {
            if (err) {
                if (skipRedirect) {
                    res.status(500).json({ message: 'internal-error', error: err.message });
                } else {
                    res.redirect(`${deriveAuthRedirectUrl(req, 'auth_redirect_error')}?message=internal-error&error=${encodeURI(err.message)}`);
                }
                return
            }
            if (skipRedirect) {
                res.status(200).json({ message: 'login-success' });
            } else {
                res.redirect(`${deriveAuthRedirectUrl(req, 'auth_redirect_success')}?message=login-success`);
            }
            return
        });
    })(req, res, next)
});

router.post('/user-pwd/signup', bodyParser.json(), function (req, res, next) {
    passport.authenticate('local', function (err, user, info, status) {
        var skipRedirect = (req.query?.redirect === "false");
        if (err) {
            if (skipRedirect) {
                res.status(400).json({ message: err.message });
            } else {
                res.redirect(`${deriveAuthRedirectUrl(req, 'auth_redirect_error')}?message=bad-request&error=${encodeURI(err.message)}`);
            }
            return
        }
        if (!user) {
            if (skipRedirect) {
                res.status(401).json({ message: 'internal-error' });
            } else {
                res.redirect(`${deriveAuthRedirectUrl(req, 'auth_redirect_error')}?message=internal-error`);
            }
            return
        }
        var message = 'user-created';
        if (!user['user_existed']) { message = 'user-existed'; }
        if (skipRedirect) {
            res.status(200).json({ message: message });
        } else {
            res.redirect(`${deriveAuthRedirectUrl(req, 'auth_redirect_error')}?message=${message}`);
        }
        return

    })(req, res, next)
});
