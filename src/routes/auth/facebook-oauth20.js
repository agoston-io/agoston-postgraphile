const Router = require('express-promise-router');
const passport = require('passport');
const db = require('../../db-pool-postgraphile');
const { backendOrigin } = require('../../config-environment');
const { authStrategyGetParameterValue, buildAuthState } = require('../../helpers');
const logger = require('../../log');

const router = new Router()
module.exports = router

const FacebookStrategy = require('passport-facebook').Strategy;

passport.use(new FacebookStrategy({
    clientID: authStrategyGetParameterValue('facebook-oauth20', 'clientId'),
    clientSecret: authStrategyGetParameterValue('facebook-oauth20', 'clientSecret'),
    callbackURL: `${backendOrigin}/auth/callback/facebook-oauth20`,
    profileFields: ['id', 'email', 'about', 'picture', 'first_name', 'last_name', 'gender'],
    passReqToCallback: true
},
    async function (req, accessToken, refreshToken, profile, cb) {
        let result;
        try {
            result = await db.query('select * from agoston_api.set_authenticated_user(p_provider => $1, p_subject => $2, p_raw => $3)', [
                'facebook',
                profile.id,
                profile
            ])
        } catch (err) {
            logger.error(`auth[facebook-oauth20] query error: ${err.message}`);
            return cb(err);
        }
        return cb(null, result.rows[0]);
    }
));

router.get(`/facebook-oauth20`, function (req, res, next) {
    passport.authenticate('facebook', { scope: ['public_profile', 'email'], state: buildAuthState(req) }, function (err, user, info) {
        res.send(user);
    })(req, res, next);
});

router.get(`/callback/facebook-oauth20`, function (req, res, next) {
    passport.authenticate('facebook', function (err, user, info, status) {
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
