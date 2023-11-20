const nodemailer = require('nodemailer');
const {
    workerEmailEnable,
    workerStmpHost,
    workerStmpPort,
    workerStmpSecure,
    workerStmpAuthUser,
    workerStmpAuthPass,

} = require('../../config-environment');

/*
## payload format
message

## Example
SELECT add_job(
    'send-email',
    json_build_object(
        'from', 'nicolas@agoston.io',
        'to', 'nicolas@agoston.io',
        'subject', 'Message from PG!',
        'text', 'Coucou',
        'html', '<p>Coucou</p>',
        'attachments', jsonb_build_array(
            json_build_object(
                'filename', 'hello.txt',
                 'content', 'Hello world!'
            )
        )
    )
);
*/

if (workerEmailEnable === true) {
    console.log(`EMAIL: email enabled, creating transporter...`);
    var transporter = nodemailer.createTransport({
        pool: true,
        host: workerStmpHost,
        port: workerStmpPort,
        secure: workerStmpSecure,
        auth: {
            user: workerStmpAuthUser,
            pass: workerStmpAuthPass,
        },
    });
    transporter.verify(function (error, success) {
        if (error) {
            console.log(error);
        } else {
            console.log("EMAIL: Server is ready to handle messages");
        }
    });
    console.log(`EMAIL: email enabled, transporter created.`);
}

module.exports = async (payload, helpers) => {

    helpers.logger.debug(`Received ${JSON.stringify(payload)}`);

    if (workerEmailEnable !== true) {
        helpers.logger.info(`Message received, but email sending disable [workerEmailEnable=${workerEmailEnable}]`);
    } else {
        let info = await transporter.sendMail(payload);
        helpers.logger.debug(`Message sent: ${info.messageId}`);
    }
}
