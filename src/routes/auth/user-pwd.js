
const Router = require('express-promise-router');
const passport = require('passport');
const bodyParser = require('body-parser');
const { deriveAuthRedirectUrl, authStrategyGetParameterValue } = require('../../helpers');
const db = require('../../db-pool-postgraphile');
const logger = require('../../log');

const router = new Router()
module.exports = router

const LocalStrategy = require('passport-local').Strategy;
const usernameComplexityPattern = authStrategyGetParameterValue('user-pwd', 'usernameComplexityPattern');
if (typeof usernameComplexityPattern !== 'string') { throw new Error('"usernameComplexityPattern" is not a string!'); }
const passwordComplexityPattern = authStrategyGetParameterValue('user-pwd', 'passwordComplexityPattern');
if (typeof passwordComplexityPattern !== 'string') { throw new Error('"passwordComplexityPattern" is not a string!'); }

passport.use(new LocalStrategy({ passReqToCallback: true },
    async function verify(req, username, password, cb) {
        var createUserIfNotExits = false;
        var createSessionOnSignup = false;
        console.log(`req.path => ${req.path}`)
        if (req.path === '/user-pwd/login') { createUserIfNotExits = false; }
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
        if (req.path === '/user-pwd/signup' && result.rows.length > 0 && !createSessionOnSignup && result.rows[0]['user_created']) { return cb(null, false, { message: 'user-created' }); }
        if (req.path === '/user-pwd/signup' && result.rows.length > 0 && !createSessionOnSignup && !result.rows[0]['user_created']) { return cb(null, false, { message: 'user-exists' }); }
        if (result.rows.length === 0) { return cb(null, false, { message: 'user-not-found' }); }
        return cb(null, result.rows[0], { scope: 'all' });
    }
));

const authenticateCallBack = function (req, res, next) {
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
                res.status(401).json({ message: info.message });
            } else {
                res.redirect(`${deriveAuthRedirectUrl(req, 'auth_redirect_error')}?message=${encodeURI(info.message)}`);
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
}

// Cannot create user but can create session
router.post('/user-pwd/login', bodyParser.json(), authenticateCallBack);

// Can create user and if ok create session
router.post('/user-pwd/signup', bodyParser.json(), authenticateCallBack);
