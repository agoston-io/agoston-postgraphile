const { run, runMigrations, parseCronItems } = require("graphile-worker");
const { Client } = require('pg');
const { pgPostgresUri } = require('../config-environment');
var assert = require('assert');
const logger = require('../log');


exports.runMigrations = async function (pgURI, pgDB, pgUser, pgUserPassword, workerSchema) {
    /*
        https://github.com/graphile/worker#running
        Graphile Worker expects the Postgres role used at runtime to be the same as the role used while running the migrations.
        Must run under the developer account because the default pgPool is reused for the sql tasks.
    */
    try {
        client = new Client({
            connectionString: pgPostgresUri
        });
        await client.connect()
        await client.query(`
            do $$
            begin
                if not exists( select 1 from pg_roles where lower(rolname) = lower('${pgUser}') ) then
                    execute 'create role "${pgUser}" login password ''${pgUserPassword}''';
                    execute 'alter database "${pgDB}" owner to "${pgUser}"';
                end if;
            end $$;
        `);
    } catch (err) {
        logger.error(err)
    }

    await runMigrations({
        connectionString: pgURI,
        schema: workerSchema
    });

    try {
        await client.end()
    } catch (err) {
        logger.error(err)
    }
}


exports.run = async function (pgUser, workerSchema, workerCronJobLimit, workerConcurrency, workerPollInterval) {

    assert(workerCronJobLimit < 100, 'workerCronJobLimit should NOT be higher than 100.');
    assert(workerConcurrency < 50, 'workerConcurrency should NOT be higher than 50.');
    assert(workerPollInterval >= 1000, 'workerPollInterval should be higher than 999.');

    try {
        client = new Client({
            connectionString: pgPostgresUri
        });
        await client.connect()
        var crontabs = await client.query(`
            select json_agg(cts.ct) crontabs from (
            select  jsonb_build_object(
                        'task', task,
                        'match', match,
                        'options', jsonb_build_object(
                            'backfillPeriod', backfillPeriod,
                            'maxAttempts', maxAttempts,
                            'queueName', queue_name,
                            'priority', priority
                        ),
                        'payload', payload,
                        'identifier', identifier
                    ) ct
            from    agoston_api.crontabs
            where   enable = true
            limit ${workerCronJobLimit}
            ) cts;
        `);
    } finally {
        await client.end()
    }

    logger.info(`[WORKER] Crontab(s) discovered: ${JSON.stringify(crontabs.rows[0]["crontabs"], null, 4)}`)

    const runner = run({
        connectionString: pgUser,
        schema: workerSchema,
        concurrency: workerConcurrency,
        pollInterval: workerPollInterval,
        taskDirectory: `${__dirname}/tasks`,
        parsedCronItems: parseCronItems(crontabs.rows[0]["crontabs"] || []),
    });

    // If the worker exits (whether through fatal error or otherwise), this
    // promise will resolve/reject:
    runner.promise;
}