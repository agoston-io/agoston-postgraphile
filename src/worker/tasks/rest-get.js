const axios = require('axios').default;

/*
## payload format
payload.url
payload.headers.Content-Type: 'Application/json'
payload.headers.Authorization: 'Bearer <existing oauth2 access token>'

## Example
SELECT add_job(
    'rest-get',
    json_build_object(
        'url', 'https://httpbin.org/get'
    )
);
*/

module.exports = async (payload, helpers) => {
    helpers.logger.debug(`Received ${JSON.stringify(payload)}`);
    const response = await axios.get(`${payload.url}`, { headers: payload.headers });
    helpers.logger.debug(`response.data: ${JSON.stringify(response.data)}`);
    helpers.logger.debug(`response.status: ${JSON.stringify(response.status)}`);
    helpers.logger.debug(`response.headers: ${JSON.stringify(response.headers)}`);
    helpers.logger.debug(`response.config: ${JSON.stringify(response.config)}`);
};
