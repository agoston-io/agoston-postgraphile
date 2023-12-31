const pool = require('../../db-pool-developer');
/*
## payload format
payload.sql

## Example
SELECT add_job(
    'run-sql',
    json_build_object(
        'sql', 'create table agoston_public.test_worker (id int);'
    )
);
*/

module.exports = async (payload, helpers) => {
    helpers.logger.debug(`Received ${JSON.stringify(payload)}`);
    var result;
    try {
        result = await pool.query(payload.sql);
    } finally {
        await client.end()
    }
    helpers.logger.debug(`${result}`)
};
