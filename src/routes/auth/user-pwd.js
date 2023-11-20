
const Router = require('express-promise-router')
const passport = require('passport');
const bodyParser = require('body-parser');
const { deriveAuthRedirectUrl } = require('../../helpers')
const db = require('../../db-pool-postgraphile');

const router = new Router()
module.exports = router

const LocalStrategy = require('passport-local').Strategy;

passport.use(new LocalStrategy({ passReqToCallback: true },
    async function verify(req, username, password, cb) {
        let strongUsername = new RegExp("^[a-z0-9\-_.@]{5,}$");
        if (!strongUsername.test(username)) {
            return cb(new Error('invalid username'));
        }
        let strongPassword = new RegExp("^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\$%\^&\*,\-\_])(?=.{8,})");
        if (!strongPassword.test(password)) {
            return cb(new Error('password too weak'));
        }
        try {
            result = await db.query('SELECT user_id, role_name, auth_provider, auth_subject, auth_data from agoston_api.set_authenticated_user($1, $2, $3, $4) as (user_id int, role_name text, auth_provider text, auth_subject text, auth_data text)', [
                'user-pwd',
                username,
                req.body.free_value || {},
                password
            ])
        } catch (err) {
            console.log(`auth[passport-local] query error: ${err.message}`);
            return cb(err);
        }
        if (result.rows[0].user_id === null) { return cb(null, false); } // returns 401
        req.log_message = `auth[passport-local] user_id: ${result.rows[0].user_id} role_name: ${result.rows[0].role_name}`;
        return cb(null, result.rows[0], { scope: 'all' });
    }
));

router.post('/user-pwd', bodyParser.json(), function (req, res, next) {
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
                res.status(401).json({ message: 'login-failed' });
            } else {
                res.redirect(`${deriveAuthRedirectUrl(req, 'auth_redirect_error')}?message=login-failed`);
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
