/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        tactical: {
          bg: '#070b12',
          surface: '#0d131f',
          panel: '#111927',
          card: '#151f30',
          border: '#1e293b',
          borderHighlight: '#00f0ff',
          cyan: '#00f0ff',
          neonBlue: '#38bdf8',
          amber: '#f59e0b',
          crimson: '#ff3366',
          purple: '#a855f7',
          emerald: '#10b981',
          textMuted: '#64748b',
          textSubtle: '#94a3b8',
          textBright: '#e2e8f0',
        },
        forensic: {
          bg: '#f1f5f9',
          surface: '#ffffff',
          panel: '#f8fafc',
          card: '#ffffff',
          border: '#cbd5e1',
          borderHighlight: '#0284c7',
          textDark: '#0f172a',
          textMuted: '#64748b',
          textBright: '#0f172a',
        }
      },
      fontFamily: {
        mono: ['JetBrains Mono', 'Fira Code', 'Courier New', 'monospace'],
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
      },
      boxShadow: {
        'glow-cyan': '0 0 15px rgba(0, 240, 255, 0.25)',
        'glow-crimson': '0 0 15px rgba(255, 51, 102, 0.25)',
        'glow-amber': '0 0 15px rgba(245, 158, 11, 0.25)',
      }
    },
  },
  plugins: [],
}
