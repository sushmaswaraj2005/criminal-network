import react from '@vitejs/plugin-react'
import { defineConfig, type Plugin } from 'vite'
import { handleApiRoute } from './src/server/router.ts'

function backendApiPlugin(): Plugin {
  return {
    name: 'backend-api-plugin',
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        if (req.url && req.url.startsWith('/api/')) {
          let body = ''
          req.on('data', chunk => {
            body += chunk
          })
          req.on('end', async () => {
            try {
              const apiRes = await handleApiRoute(
                req.method || 'GET',
                req.url || '',
                req.headers as any,
                body || undefined
              )
              res.statusCode = apiRes.status
              for (const [key, value] of Object.entries(apiRes.headers)) {
                if (value !== undefined) {
                  res.setHeader(key, value as any)
                }
              }
              res.end(apiRes.body)
            } catch (err: any) {
              res.statusCode = 500
              res.setHeader('Content-Type', 'application/json')
              res.end(JSON.stringify({ success: false, error: err.message || 'Internal error' }))
            }
          })
        } else {
          next()
        }
      })
    }
  }
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), backendApiPlugin()],
  build: {
    chunkSizeWarningLimit: 1500,
  },
})
