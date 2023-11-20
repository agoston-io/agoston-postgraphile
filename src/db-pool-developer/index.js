// Dependencies
const { Pool } = require('pg')
const { pgDeveloperUri } = require('../config-environment')

// DB Pool
const pool = new Pool({
    connectionString: pgDeveloperUri,
    max: 5,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
})

module.exports = {
    pool: pool,
    query: (text, params) => pool.query(text, params),
}

