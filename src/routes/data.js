const Router = require('express-promise-router')
const { postgraphile, makePluginHook } = require("postgraphile");
const { default: PgPubsub } = require("@graphile/pg-pubsub");
const PgSimplifyInflectorPlugin = require("@graphile-contrib/pg-simplify-inflector");
const PgAggregatesPlugin = require("@graphile/pg-aggregates").default;
const PostGraphileUploadFieldPlugin = require("postgraphile-plugin-upload-field");
const { graphqlUploadExpress } = require("graphql-upload");
const fs = require("fs");
const path = require("path");
const { getPgSettings } = require('../helpers');
const { environment, pgpSchema, pgPostgresUri, pgPostgraphileUri, UploadDirName, pgDefaultAnonymousRole } = require('../config-environment')

const router = new Router()
module.exports = router

// https://github.com/graphile-contrib/postgraphile-upload-example
router.use(graphqlUploadExpress());
// Ensure upload directory exists and is a directory
try {
    if (fs.statSync(UploadDirName).isDirectory()) {
        console.log(`INFO | DIRECTORY | upload directory is: ${UploadDirName}`);
    }
} catch (err) {
    throw new Error(`The directory '${UploadDirName}' does NOT exist (${err.message}).`);
}

async function resolveUpload(upload, _args, _context, _info) {
    const { filename, mimetype, encoding, createReadStream } = upload;
    const stream = createReadStream();
    // Save file to the local filesystem
    const { id, path } = await saveLocal({ stream, filename });
    // Return metadata to save it to Postgres
    return {
        id,
        path,
        filename,
        mimetype,
        encoding
    };
}

function saveLocal({ stream, filename }) {
    const timestamp = new Date().toISOString().replace(/\D/g, "");
    const id = `${timestamp}_${filename}`;
    const filepath = path.join(UploadDirName, id);

    return new Promise((resolve, reject) =>
        stream
            .on("error", error => {
                if (stream.truncated)
                    // Delete the truncated file
                    fs.unlinkSync(filepath);
                reject(error);
            })
            .on("end", () => resolve({ id, filepath }))
            .pipe(fs.createWriteStream(filepath))
    );
}


const pluginHook = makePluginHook([
    PgPubsub,
    require("@graphile/operation-hooks").default
]);

const postgraphileOptions = {
    pluginHook,
    appendPlugins: [
        PgAggregatesPlugin,
        PgSimplifyInflectorPlugin,
        require("../postgraphile-hooks/recaptcha.js"),
        PostGraphileUploadFieldPlugin
    ],
    websocketMiddlewares: [
        require('../expressSession').get(),
        require('passport').authenticate('session'),
    ],
    pgSettings: async req => (getPgSettings(req, pgDefaultAnonymousRole)),
    graphileBuildOptions: {
        uploadFieldDefinitions: [
            {
                match: ({ schema, table, column, tags }) => tags.upload || false,
                resolve: resolveUpload,
            },
        ],
    },
    retryOnInitFail: true,
    pgExtendedTypes: true,
    subscriptions: true,
    simpleSubscriptions: true,
    pgStrictFunctions: true,
    disableDefaultMutations: false,
    dynamicJson: true,
    enableQueryBatching: true,
    disableQueryLog: true,
    ignoreRBAC: true,
    noSetofFunctionsContainNulls: true,
    async additionalGraphQLContextFromRequest(req, res) {
        return {
            user: req.user,
            getHeader(name) {
                return req.get(name);
            },

        };
    },
};

// User environment
switch (environment) {
    case 'development':
        postgraphileOptions.watchPg = true;
        postgraphileOptions.graphiql = true;
        postgraphileOptions.enhanceGraphiql = true;
        postgraphileOptions.ownerConnectionString = pgPostgresUri;
        postgraphileOptions.showErrorStack = "json";
        postgraphileOptions.extendedErrors = ['severity', 'code', 'detail', 'hint', 'position', 'internalPosition', 'internalQuery', 'where', 'schema', 'table', 'column', 'dataType', 'constraint', 'file', 'line', 'routine'];
        break;
    case 'production':
        postgraphileOptions.watchPg = false;
        postgraphileOptions.graphiql = false;
        postgraphileOptions.enhanceGraphiql = false;
        postgraphileOptions.extendedErrors = ["errcode"];
        break;
    default:
        throw `Unknown environment '${environment}'.`;
}


router.use('/', postgraphile(
    pgPostgraphileUri,
    pgpSchema,
    postgraphileOptions
));
