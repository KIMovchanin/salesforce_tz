module.exports = {
  plugins: ["prettier-plugin-apex", "@prettier/plugin-xml"],
  trailingComma: "none",
  overrides: [
    {
      files: "**/lwc/**/*.html",
      options: { parser: "lwc" }
    },
    {
      files: "**/*.{cls,trigger}",
      options: { parser: "apex" }
    }
  ]
};
