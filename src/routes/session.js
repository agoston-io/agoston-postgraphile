const Router = require('express-promise-router')
const expressSession = require('../expressSession').get();
const passport = require('passport');
var onHeaders = require('on-headers');
const { agostonSessionIdHeaderName } = require('../config-environment')

const router = new Router()
module.exports = router

router.use((req, res, next) => {
    // https://www.npmjs.com/package/on-headers#onheadersres-listener
    onHeaders(res, function () {
        // If Set-Cookie header has been set by expressSession then we set 
        // the Agoston-Session-Id header with the session id.
        if (this.getHeader('Set-Cookie') !== null && this.getHeader('Set-Cookie') !== undefined) {
            var setCookie = this.getHeader('Set-Cookie').toString()
            var AgostonSessionId = setCookie.substring(
                setCookie.indexOf("=") + 1,
                setCookie.indexOf(";")
            );
            this.setHeader(agostonSessionIdHeaderName, AgostonSessionId)
        } else { // Pass the cookie value parsed by the expressSession.
            res.set(agostonSessionIdHeaderName, null)
            if (req.headers['cookie'] !== undefined) {
                res.set(agostonSessionIdHeaderName, req.headers['cookie'].replace("connect.sid=", ""))
            }
        }
    })

    // Get Agoston-Session-Id header and set it as a cookie for further processing by expressSession.
    // If an Agoston-Session-Id is sent, use it, otherwise use the default cookie behavior.
    if (req.header(agostonSessionIdHeaderName) !== null && req.header(agostonSessionIdHeaderName) !== undefined) {
        req.headers['cookie'] = `connect.sid=${req.header(agostonSessionIdHeaderName)}`;
    }
    next()
})

router.use(expressSession);
router.use(passport.authenticate('session'));

passport.serializeUser(function (user, cb) {
    process.nextTick(function () {
        cb(null, user);
    });
});

passport.deserializeUser(function (req, user, cb) {
    process.nextTick(function () {
        return cb(null, user);
    });
});




