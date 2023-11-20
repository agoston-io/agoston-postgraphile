const expressSession = require('express-session');
const pgSession = require('connect-pg-simple')(expressSession);
const db = require('./db-pool-postgraphile');
const { sessionCookieSecret } = require('./config-environment')

const sessions = expressSession({
    store: new pgSession({
        pool: db.pool,
        schemaName: 'agoston_identity',
        tableName: 'user_sessions'
    }),
    secret: sessionCookieSecret,
    resave: false,
    saveUninitialized: false,
    cookie: {
        secure: true,
        httpOnly: true,
        sameSite: 'None',
        maxAge: 30 * 24 * 60 * 60 * 1000, // 30 days
    },
})

module.exports = {
    get: function () {
        return sessions;
    }
}
