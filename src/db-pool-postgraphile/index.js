// Dependencies
const { Pool } = require('pg')
const { pgPostgraphileUri } = require('../config-environment')

// DB Pool
const pool = new Pool({
    connectionString: pgPostgraphileUri,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
})

module.exports = {
    pool: pool,
    query: (text, params) => pool.query(text, params),
}

