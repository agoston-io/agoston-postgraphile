const { Client } = require('pg')
const softwareVersion = require('../package.json').version;
const logger = require('../log');

const {
    pgPostgresUri,
    workerSchema,
} = require('../config-environment')


async function isFirstStartBackend(client) {
    var res = {}
    try {
        res = await client.query("select not exists ( select * FROM pg_tables WHERE tablename = 'agoston_metadata') isfirststartbackend")
    } catch (err) {
        throw new Error(err);
    }
    return res.rows[0]["isfirststartbackend"]
}

async function getDatabaseVersion(client) {
    var res = {}
    try {
        res = await client.query("select agoston_api.get_backend_version () as version")
    } catch (err) {
        throw new Error(err);
    }
    return res.rows[0]["version"]
}

/**
 * When the Worker has breaking change, it's must be reinstall from scratch.
 */
module.exports = async function migrationPreWorker() {

    try {
        client = new Client({
            connectionString: pgPostgresUri
        });
        await client.connect()
    } catch (err) {
        throw new Error(err);
    }

    var isFirstStartedBackend = await isFirstStartBackend(client)
    var databaseVersion = ''
    if (!isFirstStartedBackend) {
        databaseVersion = await getDatabaseVersion(client)
    }

    if (softwareVersion === '3.15.0' && databaseVersion !== '3.15.0' && !isFirstStartedBackend) {


        logger.info(`MIGRATIONPREWORKER | Worker for Agoston v${softwareVersion} must be upgraded (removed and installed again).`)

        await client.query(`
            drop schema if exists ${workerSchema} cascade;
        `)

    }

    await client.end()
}
