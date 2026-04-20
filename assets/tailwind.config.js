/** @type {import('tailwindcss').Config} */
const colors = require('tailwindcss/colors')
const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  darkMode: 'class',
  content: [
    './js/**/*.js',
    '../lib/zcash_explorer_web/**/*.*ex'
  ],
  theme: {
    extend: {
      colors: {
        green: colors.emerald,
        yellow: colors.amber,
        purple: colors.violet,
      },
      fontFamily: {
        sans: ['Inter', defaultTheme.fontFamily.sans],
      }
    },
  },
  plugins: [require('@tailwindcss/forms')],
}