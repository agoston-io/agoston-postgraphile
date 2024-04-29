// Dependencies
const { Pool } = require('pg')
const { pgDeveloperUri, pgPoolMaxSize } = require('../config-environment')

// DB Pool
const pool = new Pool({
    connectionString: pgDeveloperUri,
    max: pgPoolMaxSize,
    idleTimeoutMillis: 30 * 1000,
    connectionTimeoutMillis: 20 * 1000,
})

module.exports = {
    pgPoolDeveloper: pool,
    query: (text, params) => pool.query(text, params),
}

