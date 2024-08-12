
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const bodyParser = require('body-parser');
const {
    corsOrigins,
    backendHttpListening,
    backendHttpPortListening,
    backendHttpsListening,
    backendHttpsPortListening,
    backendHttpsCertificate,
    backendHttpsPrivateKey,
    environment,
    version
} = require('./config-environment');
const logger = require('./log');


// Applications
module.exports = async function app() {

    const app = express();
    app.use(bodyParser.urlencoded({ extended: true }));
    app.set('trust proxy', 1);
    app.set('views', './views')
    app.set('view engine', 'pug')

    // CORS Origin
    logger.info(`CORS: ${JSON.stringify(corsOrigins, null, 4)}`)
    app.use(cors({
        "origin": function (origin, callback) {
            if (corsOrigins.allowedlist.indexOf(origin) !== -1 || !origin) {
                callback(null, true)
            } else {
                callback(new Error(`Origin '${origin}' rejected by CORS. Allowed: ${corsOrigins.allowedlist}.`))
            }
        },
        "methods": ['GET', 'PUT', 'POST', 'DELETE', 'OPTIONS'],
        "credentials": true,
        "preflightContinue": true,
        "allowedHeaders": ['Content-Type', 'Content-Length', 'Authorization', 'Recaptcha-Token', 'stripe-signature']
    }));

    // Morgan logger
    morgan.token('auth', req => {
        if (req.user === undefined) {
            return `auth=anonymous`
        }
        return `auth=${req.user.auth_provider || 'none'}|${req.user.role_name || 'none'}|user_id=${req.user.user_id || 'none'}`
    })
    morgan.token('origin', req => {
        return req.get('origin');
    })

    app.use(morgan('origin[:origin] :method :url :status :res[content-length] - :response-time ms - :auth', { stream: logger.stream }));


    // Routes
    const mountRoutes = require('./routes')
    mountRoutes(app)

    // Listening Http
    if (backendHttpListening) {
        var http = require('http');
        var httpServer = http.createServer(app);
        httpServer.listen(backendHttpPortListening, () => {
            logger.info(`SERVER | ${environment} HTTP server v${version} listening on ${backendHttpPortListening}.`);
        });
    }

    // Listening Https
    if (backendHttpsListening) {
        var fs = require('fs');
        var https = require('https');
        var privateKey = fs.readFileSync(backendHttpsPrivateKey, 'utf8');
        var certificate = fs.readFileSync(backendHttpsCertificate, 'utf8');
        var credentials = { key: privateKey, cert: certificate };
        var httpsServer = https.createServer(credentials, app);
        httpsServer.listen(backendHttpsPortListening, () => {
            logger.info(`SERVER | ${environment} HTTPS server v${version} listening on ${backendHttpsPortListening}.`);
        });
    }
}