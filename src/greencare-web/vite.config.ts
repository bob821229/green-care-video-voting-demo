import vue from '@vitejs/plugin-vue'
import { loadEnv } from 'vite'
import { defineConfig } from 'vitest/config'

export default defineConfig(({mode})=>{
  const env=loadEnv(mode,process.cwd(),'')
  return {
  base:env.VITE_PAGES_BASE||'/',
  plugins: [vue({template:{transformAssetUrls:false}})],
  server: {
    port: 5173,
    strictPort: true,
    proxy: {
      '/api': {
        target: 'http://localhost:5080',
        changeOrigin: false,
      },
    },
  },
  test: {
    environment: 'jsdom',
    environmentOptions: {
      jsdom: { url: 'http://localhost/' },
    },
  },
}})
