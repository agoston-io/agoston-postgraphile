const winston = require('winston');
const { logLevel, logColor } = require('./config-environment')

const genericFormat = winston.format.printf(({ level, message, timestamp }) => {
    return `${timestamp} | ${level} | ${message}`;
});

const logger = winston.createLogger({
    level: logLevel,
    format: winston.format.combine(
        winston.format.simple(),
        winston.format.timestamp(),
        genericFormat,
        winston.format.colorize({ all: logColor }), // Must be last to avoid curious behaviors
    ),
    transports: [new winston.transports.Console()],
});

// Stream for Express morgan logger
logger.stream = {
    write: function (message) {
        logger.info(message.substring(0, message.lastIndexOf('\n')));
    }
};

module.exports = logger;
