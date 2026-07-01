import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      // Any request to /api goes to Spring Boot
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true
      }
    }
  }
})