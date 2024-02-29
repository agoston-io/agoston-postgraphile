const { Client } = require('pg')
const fs = require('fs');
const semver = require('semver');
const softwareVersion = require('../package.json').version
const dbInitVersion = require('../package.json').dbInitVersion
const sql = require('../package.json').sql
const {
    pgPostgresUri,
    pgDeveloperUser,
    pgDeveloperPassword,
    pgPostgraphileUser,
    pgPostgraphilePassword,
    pgPostgresDatabase,
    workerSchema,
} = require('../config-environment')

async function updateUserPassword(client, username, password) {
    var query = {
        text: `ALTER USER "${username}" PASSWORD '${password}'`
    }
    var res = {}
    try {
        console.log(`INFO | MIGRATION | ALTER USER "${username}" PASSWORD '****************'`);
        res = await client.query(query)
    } catch (err) {
        throw new Error(err);
    }
    return res
}

async function isFirstStartBackend(client) {
    var res = {}
    try {
        res = await client.query("select not exists ( select * FROM pg_tables WHERE tablename = 'agoston_metadata') isfirststartbackend")
    } catch (err) {
        throw new Error(err);
    }
    return res.rows[0]["isfirststartbackend"]
}

async function updateVersion(client, version) {
    var query = {
        text: "select agoston_api.set_backend_version($1) new_version",
        values: [version]
    }
    var res = {}
    try {
        res = await client.query(query)
    } catch (err) {
        throw new Error(err);
    }
    return res.rows[0]["new_version"]
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

function replacePlaceHolders(str, find, replace) {
    return str.replace(new RegExp(find, 'g'), replace);
}

async function executeSqlScript(client, script) {
    var sqlCode = ""
    try {
        var sqlCode = fs.readFileSync(script).toString();
    } catch (err) {
        throw new Error(err);
    }
    // Replace placeholders '##<NAME>##' in scripts
    try {
        sqlCode = replacePlaceHolders(sqlCode, '##DEVELOPER_USER##', pgDeveloperUser)
        sqlCode = replacePlaceHolders(sqlCode, '##DEVELOPER_PASSWORD##', pgDeveloperPassword)
        sqlCode = replacePlaceHolders(sqlCode, '##POSTGRAPHILE_USER##', pgPostgraphileUser)
        sqlCode = replacePlaceHolders(sqlCode, '##POSTGRAPHILE_PASSWORD##', pgPostgraphilePassword)
        sqlCode = replacePlaceHolders(sqlCode, '##DATABASE_NAME##', pgPostgresDatabase)
        sqlCode = replacePlaceHolders(sqlCode, '##WORKER_SCHEMA##', workerSchema)
    } catch (err) {
        throw new Error(err);
    }
    try {
        console.log(`INFO | MIGRATION | executeSqlScript | Executing script: ${script}`)
        const res = await client.query(sqlCode)
    } catch (err) {
        console.log(sqlCode)
        throw new Error(err);
    }
}

async function executeDirSqlScript(client, initSqlDirectory) {
    try {
        files = await fs.readdirSync(initSqlDirectory)
    } catch (err) {
        throw new Error("executeInitSqlScript: Could not list the directory.", err.stack);
    }

    for (const file of files) {
        await executeSqlScript(client, `${initSqlDirectory}/${file}`)
    }
}

async function upgrade(client, databaseVersion, upgradeSqlDirectory) {
    var versionDir = []
    var versionToApply = []
    try {
        versionDir = fs.readdirSync(upgradeSqlDirectory, { withFileTypes: true })
            .filter(dirent => dirent.isDirectory())
            .map(dirent => dirent.name)
            .sort(semver.compare);
    } catch (err) {
        throw new Error(err)
    }
    console.log(`INFO | MIGRATION | SQL patch(es) detected: ${JSON.stringify(versionDir)}`)
    versionDir.forEach(function (item) {
        if (semver.gt(item, databaseVersion) && semver.lte(item, softwareVersion)) {
            versionToApply.push(item);
        }
    });
    console.log(`INFO | MIGRATION | SQL patch(es) to apply: ${JSON.stringify(versionToApply)}`)
    for (const version of versionToApply) {
        await executeDirSqlScript(client, `${upgradeSqlDirectory}/${version}`)
    }
}

module.exports = async function migration() {

    console.log(`INFO | MIGRATION | initSqlDirectory: ${sql.initSqlDirectory}`)
    console.log(`INFO | MIGRATION | upgradeSqlDirectory: ${sql.upgradeSqlDirectory}`)

    try {
        client = new Client({
            connectionString: pgPostgresUri
        });
        await client.connect()
    } catch (err) {
        throw new Error(err);
    }

    // Start migration process
    if (await isFirstStartBackend(client)) {
        console.log(`INFO | MIGRATION | dbInitVersion: ${dbInitVersion}`)
        await executeDirSqlScript(client, sql.initSqlDirectory)
        databaseUpdatedVersion = await updateVersion(client, dbInitVersion)
        console.log(`INFO | MIGRATION | databaseUpdatedVersion: ${databaseUpdatedVersion}`)
    }
    databaseVersion = await getDatabaseVersion(client)
    console.log(`INFO | MIGRATION | softwareVersion: ${softwareVersion}`)
    console.log(`INFO | MIGRATION | databaseVersion (current): ${databaseVersion}`)
    switch (true) {
        case (databaseVersion === softwareVersion):
            console.log('INFO | MIGRATION | No SQL upgrade necessary.');
            break;
        case (semver.gt(databaseVersion, softwareVersion)):
            throw new Error(`Cannot run older backend version on current database version`);
        case (semver.lt(databaseVersion, softwareVersion)):
            console.log('INFO | MIGRATION | SQL upgrade maybe require.');
            await upgrade(client, databaseVersion, sql.upgradeSqlDirectory);
            break;
        default:
            console.log(`INFO | MIGRATION | Sorry, cannot be.`);
    }

    // Update version in database
    databaseFinalVersion = await updateVersion(client, softwareVersion)
    console.log(`INFO | MIGRATION | databaseFinalVersion: ${databaseFinalVersion}`)

    // Update users' password
    await updateUserPassword(client, pgDeveloperUser, pgDeveloperPassword)
    await updateUserPassword(client, pgPostgraphileUser, pgPostgraphilePassword)

    await client.end()
}
