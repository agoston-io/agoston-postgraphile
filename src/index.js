const migration = require("./sql/migration");
const waitForDb = require("./sql/waitForDb");
const {
    pgPostgresUri,
    pgPostgresDatabase,
    pgPostgraphileUri,
    pgPostgraphileUser,
    pgPostgraphilePassword,
    workerSchema,
    workerCronJobLimit,
    workerConcurrency,
    workerPollInterval
} = require("./config-environment");
const worker = require("./worker");
const app = require("./app");

waitForDb(pgPostgresUri).then(() => {
    worker.runMigrations(
        pgPostgraphileUri,
        pgPostgresDatabase,
        pgPostgraphileUser,
        pgPostgraphilePassword,
        workerSchema
    ).then(() => {
        migration().then(() => {
            app();
            worker.run(
                pgPostgraphileUri,
                workerSchema,
                workerCronJobLimit,
                workerConcurrency,
                workerPollInterval
            );
        })
    })
})
