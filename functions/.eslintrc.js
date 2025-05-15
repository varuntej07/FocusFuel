module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2020,
  },
  extends: ["eslint:recommended"],
  rules: {
    "no-restricted-globals": "off",
    "prefer-arrow-callback": "off",
    "require-jsdoc": "off",
    "quotes": "off",
    "max-len": "off",
    "quote-props": "off",
  },
};