const Router = require('express-promise-router')
const { version } = require('../../config-environment')


module.exports = app => {
    app.use(function (req, res, next) {
        res.status(404);

        // respond with html page
        if (req.accepts('html')) {
            res.render('404', {
                version: version,
            });
            return;
        }

        // respond with json
        if (req.accepts('json')) {
            res.json({ error: 'Not found' });
            return;
        }

        // default to plain-text. send()
        res.type('txt').send('Not found');
    });
}
