const lwcConfig = require("@salesforce/eslint-config-lwc");

module.exports = [
    ...lwcConfig.configs.recommended,
    {
        ignores: ["coverage/**", "mdapi-output/**", "node_modules/**"]
    }
];
