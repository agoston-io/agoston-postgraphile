// Dependencies
const { Pool } = require('pg')
const { pgPostgraphileUri, pgPoolMaxSize } = require('../config-environment')

// DB Pool
const pool = new Pool({
    connectionString: pgPostgraphileUri,
    max: pgPoolMaxSize,
    idleTimeoutMillis: 30 * 1000,
    connectionTimeoutMillis: 20 * 1000,
})

module.exports = {
    pgPoolPostgraphile: pool,
    query: (text, params) => pool.query(text, params),
}

