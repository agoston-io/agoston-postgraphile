
const Router = require('express-promise-router');
const passport = require('passport');
const db = require('../../db-pool-postgraphile');
const logger = require('../../log');

const router = new Router()
module.exports = router


const BearerStrategy = require('passport-http-bearer').Strategy;

passport.use(new BearerStrategy({ passReqToCallback: true },
    async function (req, token, cb) {
        let result;
        try {
            result = await db.query('SELECT user_id, role_name, auth_provider, auth_subject, auth_data from agoston_api.get_user_by_token($1) as (user_id int, role_name text, auth_provider text, auth_subject text, auth_data text)', [
                token
            ])
        } catch (err) {
            logger.error(`auth[passport-http-bearer] query error: ${err.message}`);
            return cb(err);
        }
        if (result.rows[0].user_id === null) { return cb(null, false); } // returns 401
        return cb(null, result.rows[0], { scope: 'all' });
    }
));

router.use(function (req, res, next) {
    if (req.headers.authorization !== undefined) {
        passport.authenticate('bearer', { session: false })(req, res, next);
    } else {
        next();
    }
});
