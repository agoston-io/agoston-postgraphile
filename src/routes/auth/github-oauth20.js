const Router = require('express-promise-router')
const passport = require('passport');
const db = require('../../db-pool-postgraphile');
const { backendOrigin } = require('../../config-environment')
const { authStrategyGetParameterValue, buildAuthState } = require('../../helpers')

const router = new Router()
module.exports = router

const GithubStrategy = require('passport-github2').Strategy;

passport.use(new GithubStrategy({
    clientID: authStrategyGetParameterValue('github-oauth20', 'clientId'),
    clientSecret: authStrategyGetParameterValue('github-oauth20', 'clientSecret'),
    callbackURL: `${backendOrigin}/auth/callback/github-oauth20`,
    passReqToCallback: true
},
    async function (req, accessToken, refreshToken, profile, cb) {
        let result;
        try {
            result = await db.query('SELECT user_id, role_name, auth_provider, auth_subject, auth_data from agoston_api.set_authenticated_user(p_provider => $1, p_subject => $2, p_raw => $3) as (user_id int, role_name text, auth_provider text, auth_subject text, auth_data text)', [
                'github',
                profile.id,
                profile
            ])
        } catch (err) {
            console.log(`auth[github-oauth20] query error: ${err.message}`);
            return cb(err);
        }
        return cb(null, result.rows[0]);
    }
));

router.get(`/github-oauth20`, function (req, res, next) {
    passport.authenticate('github', { scope: ['read:user', 'user:email'], state: buildAuthState(req) }, function (err, user, info) {
        res.send(user);
    })(req, res, next);
});

router.get(`/callback/github-oauth20`, function (req, res, next) {
    passport.authenticate('github', function (err, user, info, status) {
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

