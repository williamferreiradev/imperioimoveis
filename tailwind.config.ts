import type { Config } from 'tailwindcss'

export default <Partial<Config>>{
  content: [
    './components/**/*.{js,vue,ts}',
    './layouts/**/*.vue',
    './pages/**/*.vue',
    './plugins/**/*.{js,ts}',
    './app.vue',
    './error.vue'
  ],
  darkMode: 'class',
  theme: {
    extend: {
      fontFamily: {
        // Removendo Playfair para algo mais esportivo e corporativo (Inter para tudo)
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        serif: ['Inter', 'Georgia', 'serif'],
        mono: ['IBM Plex Mono', 'ui-monospace', 'SFMono-Regular', 'monospace'],
      },
      colors: {
        primary: {
          DEFAULT: '#00539B', // Goodyear Blue
          50: '#eef6ff',
          100: '#d9ecff',
          200: '#bddfff',
          300: '#8ccbff',
          400: '#54afff',
          500: '#00539B',
          600: '#004280',
          700: '#003366',
          800: '#00224d',
          900: '#001133',
          glow: '#00539B30'
        },
        dark: {
          bg: '#050505',
          surface: '#111111',
          card: '#181A20',
          border: '#2A2D35',
          text: '#F3F4F6',
          muted: '#9CA3AF'
        },
        accent: {
          DEFAULT: '#FFDD00', // Goodyear Yellow
        }
      },
      boxShadow: {
        luxury: '0 10px 30px -5px rgba(0, 83, 155, 0.25)', // Sombra Azul
        card: '0 1px 3px 0 rgba(0, 0, 0, 0.3), 0 1px 2px -1px rgba(0, 0, 0, 0.2)',
        'card-hover': '0 10px 15px -3px rgba(0, 0, 0, 0.3), 0 4px 6px -4px rgba(0, 0, 0, 0.2)',
      },
      borderRadius: {
        card: '4px',
      }
    }
  }
}
