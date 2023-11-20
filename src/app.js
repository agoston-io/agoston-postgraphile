
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const bodyParser = require('body-parser');

const { corsOrigins, backendHttpPortListening, environment, version } = require('./config-environment')

// Applications
module.exports = async function app() {

    const app = express();
    app.use(bodyParser.urlencoded({ extended: true }));
    app.set('trust proxy', 1);
    app.set('views', './views')
    app.set('view engine', 'pug')

    // CORS Origin
    app.use(cors({
        "origin": function (origin, callback) {
            if (corsOrigins.allowedlist.indexOf(origin) !== -1 || !origin) {
                callback(null, true)
            } else {
                callback(new Error(`Origin '${origin}' rejected by CORS. Allowed: ${corsOrigins.allowedlist}. Skipped: ${corsOrigins.skippedlist}.`))
            }
        },
        "methods": ['GET', 'PUT', 'POST', 'DELETE', 'OPTIONS'],
        "credentials": true,
        "preflightContinue": true,
        "allowedHeaders": ['Content-Type', 'Authorization', 'Recaptcha-Token', 'stripe-signature']
    }));

    // Morgan logger
    morgan.token('auth', req => {
        if (req.log_message === undefined) {
            return 'anonymous query'
        }
        return req.log_message
    })
    morgan.token('origin', req => {
        return req.get('origin');
    })
    app.use(morgan('origin[:origin] :method :url :status :res[content-length] - :response-time ms - :auth'))


    // Routes
    const mountRoutes = require('./routes')
    mountRoutes(app)

    // Listening
    app.listen(backendHttpPortListening, () => {
        console.info(`INFO: ${environment} server v${version} listening on ${backendHttpPortListening}.`);
    });
}
