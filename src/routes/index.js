const helpers = require('../helpers');
const session = require('./session')
const wellKnown = require('./well-known')
const auth = require('./auth')
const data = require('./data')
const error404 = require('./error404')
const { stripeHookEnable } = require('../config-environment')

module.exports = app => {
    if (stripeHookEnable) {
        app.use('/hook/stripe', require('./hook/stripe'))
    }
    app.get('/', (req, res) => { res.redirect("https://agoston.io"); })
    app.use('/', session) // passport sessions to init before Passport strategies
    for (const authStrategy of helpers.getAuthStrategiesAvailable('header-based')) {
        if (helpers.authStrategyIsEnable(authStrategy)) {
            app.use(require(`./auth/${authStrategy.name}`))
        }
    }
    app.use('/auth', auth)
    app.use('/.well-known', wellKnown)
    app.use('/data', data)
    const error404 = require('./error404')
    error404(app)
}
