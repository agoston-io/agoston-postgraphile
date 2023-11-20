const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));
const { recaptchaSecretKey, recaptchaScoreThreshold } = require('../config-environment')

const recaptchaHookFromBuild = build => fieldContext => {
    const {
        scope: { isRootMutation, isPgCreateMutationField, pgFieldIntrospection }
    } = fieldContext;

    // Hook should only apply to mutations you can do this:
    if (!isRootMutation) return null;

    if (typeof (pgFieldIntrospection.tags.recaptcha) === 'undefined') return null;
    if (pgFieldIntrospection.tags.recaptcha !== 'true') return null;

    // Defining the callback up front makes the code easier to read.
    const verifyRecaptchaError = (error) => {
        console.log(error);
        return error;
    };

    const verifyRecaptcha = async (input, args, context, resolveInfo) => {

        secretKey = recaptchaSecretKey;
        scoreThreshold = recaptchaScoreThreshold;
        recaptchaToken = context.getHeader("Recaptcha-Token");
        console.log("scoreThreshold: %o", scoreThreshold);
        console.log("secretKey: %o", secretKey);
        console.log("recaptchaToken: %o", recaptchaToken);

        // Here get token and validate recaptcha
        // Return error recaptcha verification error if not ok
        const response = await fetch(
            `https://www.google.com/recaptcha/api/siteverify?secret=${secretKey}&response=${recaptchaToken}`,
            { method: "POST" })
            .then(response => response.json());

        console.log(response);
        if (!response.success) throw new Error(
            `recaptcha: ${response["error-codes"]}`
        );
        if (response.score < parseFloat(scoreThreshold)) throw new Error(
            `recaptcha: we believe we are a robot. Sorry. [score ${response.score}]`
        );
        return input;

    };

    // Now we tell the hooks system to use it:
    return {
        // An optional list of callbacks to call before the operation
        before: [
            // You may register more than one callback if you wish, they will be mixed
            // in with the callbacks registered from other plugins and called in the
            // order specified by their priority value.
            {
                // Priority is a number between 0 and 1000; if you're not sure where to
                // put it, then 500 is a great starting point.
                priority: 500,
                // This function (which can be asynchronous) will be called before the
                // operation; it will be passed a value that it must return verbatim;
                // the only other valid return is `null` in which case an error will be thrown.
                callback: verifyRecaptcha
            }
        ],

        // As `before`, except the callback is called after the operation and will
        // be passed the result of the operation; you may returna derivative of the
        // result.
        after: [],

        // As `before`; except the callback is called if an error occurs; it will be
        // passed the error and must return either the error or a derivative of it.
        error: [{
            priority: 500,
            callback: verifyRecaptchaError
        }]
    };
};

// This exports a standard Graphile Engine plugin that adds the operation
// hook.
module.exports = function MyOperationHookPlugin(builder) {
    builder.hook("init", (_, build) => {
        // Register our operation hook (passing it the build object):
        build.addOperationHook(recaptchaHookFromBuild(build));

        // Graphile Engine hooks must always return their input or a derivative of
        // it.
        return _;
    });
};
