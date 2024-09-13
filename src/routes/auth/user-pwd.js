
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
        logger.debug(`verify | req.path => ${req.path}`)
        logger.debug(`verify | req.body => ${JSON.stringify(req.body)}`)
        if (req.path === '/user-pwd/signup') { createUserIfNotExits = true; }
        try {
            result = await db.query('select * from agoston_api.set_authenticated_user(p_provider => $1, p_subject => $2, p_raw => $3, p_password => $4, p_username_complexity_pattern => $5, p_password_complexity_pattern => $6, p_create_user_if_not_exits => $7)', [
                'user-pwd',
                username,
                req.body?.free_value || {},
                password,
                usernameComplexityPattern,
                passwordComplexityPattern,
                createUserIfNotExits,
            ])
        } catch (err) {
            logger.error(`auth[passport-local] ${err}`);
            return cb(err);
        }
        logger.debug(`result.rows[0] ${JSON.stringify(result.rows)}`)
        if (result.rows.length === 0) { return cb(null, false, { message: 'user-not-found' }); }
        if (req.path === '/user-pwd/signup' && result.rows.length > 0 && result.rows[0]["user_existed"]) { return cb(null, false, { message: 'user-already-exists' }); }
        if (result.rows[0]["password_expired"]) { return cb(null, false, { message: 'password-expired' }); }
        return cb(null, result.rows[0], { scope: 'all' });
    }
));

router.post('/user-pwd/login', bodyParser.json(), function (req, res, next) {
    logger.debug(`${req.path} | req.body => ${JSON.stringify(req.body)}`)
    passport.authenticate('local', function (err, user, info, status) {
        logger.debug(`${req.path} | err=${err}, user=${JSON.stringify(user)}, info=${JSON.stringify(info)}, status=${status}}`)
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
                res.status(400).json({ message: info?.message || 'internal-error' });
            } else {
                res.redirect(`${deriveAuthRedirectUrl(req, 'auth_redirect_error')}?message=${info?.message || 'internal-error'}`);
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

router.post('/user-pwd/signup', bodyParser.json(), async function (req, res, next) {
    logger.debug(`${req.path} | req.session => ${JSON.stringify(req.session)}`)
    logger.debug(`${req.path} | req.body => ${JSON.stringify(req.body)}`)
    if (req.session?.passport?.user?.role_name || '' === "authenticated") {
        await req.session.destroy(function (err) {
            logger.debug(`${req.path} | session destroy. Err => ${err}`)
        });
    }
    passport.authenticate('local', function (err, user, info, status) {
        logger.debug(`${req.path} | err=${err}, user=${JSON.stringify(user)}, info=${JSON.stringify(info)}, status=${status}}`)
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
                res.status(400).json({ message: info?.message || 'internal-error' });
            } else {
                res.redirect(`${deriveAuthRedirectUrl(req, 'auth_redirect_error')}?message=${info?.message || 'internal-error'}`);
            }
            return
        }
        var message = 'user-created';
        if (skipRedirect) {
            res.status(200).json({ message: message });
        } else {
            res.redirect(`${deriveAuthRedirectUrl(req, 'auth_redirect_error')}?message=${message}`);
        }
        return

    })(req, res, next)
});

router.patch('/user-pwd/login', bodyParser.json(), async function (req, res, next) {
    logger.debug(`${req.path} | req.body => ${JSON.stringify(req.body)}`);
    try {
        result = await db.query('select * from agoston_api.set_user_password(p_username => $1, p_password => $2, p_current_password => $3, p_password_complexity_pattern => $4)', [
            req.body.username,
            req.body.password,
            req.body.currentPassword || 'wrong-password',
            passwordComplexityPattern
        ])
    } catch (err) {
        logger.error(`/user-pwd/update ${err}`);
        res.json(400, {
            message: err.message
        });
        return
    }
    res.json(200, {
        message: 'password-changed'
    });
    return
});
