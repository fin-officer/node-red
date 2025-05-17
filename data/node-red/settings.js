module.exports = {
    flowFile: 'flows.json',
    flowFilePretty: true,

    adminAuth: {
        type: "credentials",
        users: [{
            username: process.env.NODERED_USERNAME || "admin",
            password: process.env.NODERED_PASSWORD ? require('bcryptjs').hashSync(process.env.NODERED_PASSWORD) : "$2a$08$zZAdYdNMdqdvIXM4oCQQEuUfGK7tgbWh31h.npVFn4MBgBuLsNowy",
            permissions: "*"
        }]
    },

    httpNodeAuth: {
        user: process.env.NODERED_USERNAME || "admin",
        pass: process.env.NODERED_PASSWORD || "password"
    },

    functionGlobalContext: {
        os: require('os'),
        process: process,
        // Dodatkowe moduły można dodać tutaj
        emailUtils: {
            extractAddresses: function(recipients) {
                if (!recipients) return [];
                return recipients.split(',').map(r => r.trim());
            },
            cleanSubject: function(subject) {
                if (!subject) return '';
                return subject.replace(/^(RE:|FWD:)/i, '').trim();
            },
            htmlToText: function(html) {
                if (!html) return '';
                // Prosta implementacja
                return html.replace(/<[^>]*>/g, ' ')
                          .replace(/\s+/g, ' ')
                          .trim();
            }
        }
    },

    contextStorage: {
        default: "memoryOnly",
        memoryOnly: { module: 'memory' },
        file: { module: 'localfilesystem' }
    },

    logging: {
        console: {
            level: "info",
            metrics: false,
            audit: false
        }
    },

    exportGlobalContextKeys: false,
    externalModules: {},

    // Dodaj endpoint zdrowia dla healthcheck
    httpNodeMiddleware: function(req, res, next) {
        if (req.url === '/health') {
            res.setHeader('Content-Type', 'application/json');
            res.statusCode = 200;
            res.end(JSON.stringify({status: "UP", time: new Date().toISOString()}));
        } else {
            next();
        }
    }
};
