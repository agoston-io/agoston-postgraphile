const axios = require('axios').default;

/*
## payload format
payload.url
payload.payload
payload.headers.Content-Type: 'Application/json'
payload.headers.Authorization: 'Bearer <existing oauth2 access token>'

## Example
SELECT add_job(
    'rest-put',
    json_build_object(
        'url', 'https://httpbin.org/put',
        'payload', json_build_object('var1', 'val1'),
        'headers', json_build_object(
            'Content-Type', 'Application/json',
            'Authorization', 'Bearer <existing oauth2 access token>'
        )
    )
);
*/

module.exports = async (payload, helpers) => {
    helpers.logger.debug(`Received ${JSON.stringify(payload)}`);
    const response = await axios.patch(`${payload.url}`, payload.payload, { headers: payload.headers });
    helpers.logger.debug(`response.data: ${JSON.stringify(response.data)}`);
    helpers.logger.debug(`response.status: ${JSON.stringify(response.status)}`);
    helpers.logger.debug(`response.headers: ${JSON.stringify(response.headers)}`);
    helpers.logger.debug(`response.config: ${JSON.stringify(response.config)}`);
};
