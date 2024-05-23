const Router = require('express-promise-router')
const bodyParser = require('body-parser');
const { stripeApiKey, stripeHookEndPointSecret } = require('../../config-environment')
const stripe = require('stripe')(stripeApiKey);
const db = require('../../db-pool-postgraphile');

const router = new Router()
module.exports = router

router.post('/', bodyParser.raw({ type: 'application/json' }), async (request, response) => {
    const payload = request.body;
    const sig = request.headers['stripe-signature'];

    let event;

    try {
        event = stripe.webhooks.constructEvent(payload, sig, stripeHookEndPointSecret);
    } catch (err) {
        console.error(`Stripe webhook Error: ${err.message}`);
        return response.status(400).send(`Stripe webhook Error: ${err.message}`);
    }

    let result;

    try {
        result = await db.query(`select agoston_private.stripe_hook($1) as "return"`, [
            event,
        ])
    } catch (err) {
        console.log(`Stripe webhook Error: ${err.message}`);
        return response.status(400).send(`Stripe webhook Error: ${err.message}`);
    }

    return response.status(result.rows[0]["return"]).send(`returned ${result.rows[0]["return"]}`);

});