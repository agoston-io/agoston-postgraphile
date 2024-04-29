// Dependencies
const { Pool } = require('pg')
const { pgPostgresUri, pgPoolMaxSize } = require('../config-environment')

// DB Pool
const pool = new Pool({
    connectionString: pgPostgresUri,
    max: pgPoolMaxSize,
    idleTimeoutMillis: 30 * 1000,
    connectionTimeoutMillis: 20 * 1000,
})

module.exports = {
    pgPoolPostgres: pool,
    query: (text, params) => pool.query(text, params),
}

