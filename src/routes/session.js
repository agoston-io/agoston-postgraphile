const Router = require('express-promise-router')
const expressSession = require('../expressSession').get();
const passport = require('passport');

const router = new Router()
module.exports = router

router.use(expressSession);
router.use(passport.authenticate('session'));

passport.serializeUser(function (user, cb) {
    process.nextTick(function () {
        cb(null, { user_id: user.user_id, role_name: user.role_name, auth_provider: user.auth_provider, auth_subject: user.auth_subject, auth_data: user.auth_data });
    });
});

passport.deserializeUser(function (req, user, cb) {
    process.nextTick(function () {
        return cb(null, user);
    });
});
