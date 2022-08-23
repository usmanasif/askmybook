module.exports = {
  extends: ['prettier'],
  plugins: ['prettier'],
  rules: {
    'jsx-quotes': [2, 'prefer-single'],
    'max-lines': ['error', { max: 200, skipBlankLines: true }],
    'no-console': 'warn',
    'no-debugger': 'warn',
    'no-duplicate-imports': 'off',
    'no-undef': 'off',
    'prefer-arrow-callback': 0,
    'prefer-const': 0,
    quotes: [0, 'double'],
    'react/jsx-no-useless-fragment': 'off',
    'react/react-in-jsx-scope': 0,
    'react/prop-types': 'off',
    'react/no-unescaped-entities': 'off',
    "no-unused-vars": "off",
  }
}