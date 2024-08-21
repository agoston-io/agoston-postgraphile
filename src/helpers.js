function validURL(str) {
    var pattern = new RegExp('^(https?:\\/\\/)?' + // protocol
        '((([a-z\\d]([a-z\\d-]*[a-z\\d])*)\\.?)+[a-z]{2,}|' + // domain name
        '((\\d{1,3}\\.){3}\\d{1,3}))' + // OR ip (v4) address
        '(\\:\\d+)?(\\/[-a-z\\d%_.~+]*)*' + // port and path
        '(\\?[;&a-z\\d%_.~+=-]*)?' + // query string
        '(\\#[-a-z\\d_]*)?$', 'i'); // fragment locator
    return !!pattern.test(str);
}

function deriveAuthRedirectUrl(req, user_redirect_param) {
    var baseReferrer = '/'
    var redirect = baseReferrer
    if (req.get('Referrer') !== undefined) {
        baseReferrer = req.get('Referrer').match('^.+?[^\/:](?=[?\/]|$)')[0]
        redirect = req.get('Referrer')
    }
    if (req.query[user_redirect_param] !== undefined) {
        if (req.query[user_redirect_param].startsWith("/")) {
            redirect = `${baseReferrer}${req.query[user_redirect_param]}`
        }
        if (req.query[user_redirect_param].startsWith("http")) {
            redirect = req.query[user_redirect_param]
        }
    }
    return redirect;
}

module.exports = {
    validURL: validURL,
    getPgSettings: function (req, pgDefaultAnonymousRole) {
        return {
            'role': req.user === undefined ? pgDefaultAnonymousRole : req.user.role_name,
            'session.id': req.sessionID === undefined ? 'no-session-id' : req.sessionID,
            'session.is_authenticated': req.user === undefined ? false : true,
            'session.user_id': req.user?.user_id === undefined ? 0 : req.user.user_id,
            'session.auth_provider': req.user?.auth_provider === undefined ? null : req.user.auth_provider,
            'session.auth_subject': req.user?.auth_subject === undefined ? null : req.user.auth_subject,
            'session.auth_data': req.user?.auth_data === undefined ? '{}' : JSON.stringify(req.user.auth_data),
        }
    },
    formatCORSInput: function (corsOriginsInput) {
        var corsOrigins = {};
        corsOrigins.allowedlist = [];
        corsOriginsInput.split(',').forEach(function (corsOrigin, i) {
            var corsOriginTrimmed = corsOrigin.trim();
            if (validURL(corsOriginTrimmed)) {
                corsOrigins.allowedlist.push(corsOriginTrimmed);
            } else {
                throw new Error(`Origin '${corsOrigin}' is invalid.`)
            }
        });
        return corsOrigins
    },
    authStrategyGetParameterValue: function (authStrategyName, parameter) {
        const authStrategies = require('./config-environment').authStrategies
        if (!authStrategies.hasOwnProperty(authStrategyName)) {
            throw new TypeError(`No auth strategy '${authStrategyName}'`);
        }
        if (!authStrategies[authStrategyName].hasOwnProperty('params')) {
            throw new TypeError(`No 'params' attribute for auth strategy '${authStrategyName}'`);
        }
        if (!authStrategies[authStrategyName].params.hasOwnProperty(parameter)) {
            throw new TypeError(`No parameter '${parameter}' for auth strategy '${authStrategyName}'`);
        }
        return authStrategies[authStrategyName].params[parameter];
    },
    getAuthStrategiesAvailable: function (strategyType) {
        const authStrategiesAvailable = require('./config-environment').authStrategiesAvailable
        var authStrategiesAvailableFiltered = []
        switch (strategyType) {
            case 'cookie-based':
                for (const authStrategy of authStrategiesAvailable) {
                    if (authStrategy.isCookieBased) {
                        authStrategiesAvailableFiltered.push(authStrategy)
                    }
                }
                break;
            case 'header-based':
                for (const authStrategy of authStrategiesAvailable) {
                    if (!authStrategy.isCookieBased) {
                        authStrategiesAvailableFiltered.push(authStrategy)
                    }
                }
                break;
            default:
                authStrategiesAvailableFiltered = authStrategiesAvailable
                break;
        }
        return authStrategiesAvailableFiltered;
    },
    authStrategyIsEnable: function (authStrategy) {
        const authStrategies = require('./config-environment').authStrategies
        if (authStrategies.hasOwnProperty(authStrategy.name)) {
            if (authStrategies[authStrategy.name].hasOwnProperty('enable')) {
                if (authStrategies[authStrategy.name]['enable']) {
                    return true;
                }
            }
        }
        return false;
    },
    deriveAuthRedirectUrl: deriveAuthRedirectUrl,
    buildAuthState: function (req) {
        return JSON.stringify({
            r: {
                success: deriveAuthRedirectUrl(req, 'auth_redirect_success'),
                error: deriveAuthRedirectUrl(req, 'auth_redirect_error'),
            }
        }).toString('base64')
    },
    getBoolean: function (value) {
        if (typeof value === 'string') {
            switch (value.toLowerCase()) {
                case "true":
                case "1":
                case "on":
                case "yes":
                    return true;
                default:
                    return false;
            }
        }
        if (typeof value === 'number') {
            switch (value) {
                case 1:
                    return true;
                default:
                    return false;
            }
        }
        if (typeof value === 'boolean') {
            switch (value) {
                case true:
                    return true;
                default:
                    return false;
            }
        }
    }
};

