const { Client } = require('pg')

async function sleep(millis) {
    return new Promise(resolve => setTimeout(resolve, millis));
}

module.exports = async function waitForDb(pgPostgresUri) {

    var connectionRetry = 15;
    var connectionDelay = 500;
    var client = { "_connected": false }
    while (!client['_connected'] && connectionRetry > 0) {
        try {
            client = new Client({
                connectionString: pgPostgresUri
            });
            await client.connect()
        } catch (err) {
            console.log(err)
            connectionRetry--;
            if (connectionRetry === 0) { throw new Error('Connection not ready yet, maximum reties reached.') }
            console.log(`WAIT FOR DB: Connection not ready yet, retesting in ${connectionDelay} ms. Retry count ${connectionRetry}`)
            await sleep(connectionDelay);
            connectionDelay = connectionDelay * 1.25;
        }

    }
    if (!client['_connected']) {
        throw new Error("WAIT FOR DB: Unable to connection to the database.");
    }

    await client.end()
}





