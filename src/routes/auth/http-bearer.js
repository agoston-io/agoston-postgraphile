
const Router = require('express-promise-router');
const passport = require('passport');
const db = require('../../db-pool-postgraphile');
const logger = require('../../log');
const { isInt } = require('../../helpers');

const router = new Router()
module.exports = router

const BearerStrategy = require('passport-http-bearer').Strategy;

passport.use(new BearerStrategy({ passReqToCallback: true },
    async function (req, token, cb) {
        let user_id = token.substr(0, token.indexOf(":"));
        let token_text = token.substr(token.indexOf(":") + 1);
        logger.debug(`token => ${token}`);
        logger.debug(`user_id => ${user_id}`);
        logger.debug(`token_text => ${token_text}`);
        if (!isInt(user_id)) {
            logger.error(`user_id is not an int (user_id = ${user_id}).`)
            return cb(null, false);
        }
        let result;
        try {
            result = await db.query('SELECT * from agoston_api.get_user_by_token($1, $2)', [
                user_id,
                token_text
            ])
        } catch (err) {
            logger.error(`auth[passport-http-bearer] query error: ${err.message}`);
            return cb(err);
        }
        if (result.rows.length === 0) { return cb(null, false); } // returns 401
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
