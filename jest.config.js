const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  collectCoverageFrom: [
    "**/lwc/**/*.js",
    "!**/lwc/**/__tests__/**",
    "!mdapi-output/**"
  ],
  coverageDirectory: "coverage"
};
