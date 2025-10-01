import {defineConfig} from 'vite';
import react from '@vitejs/plugin-react-swc'
import {transformReadmePlugin} from './vite-transform-readme';
import path from 'path';

export default defineConfig({
  plugins: [react(),
    transformReadmePlugin(),
    // viteStaticCopy({
    //   targets: [
    //     {
    //       src: "../incontainer/README.md",
    //       dest: "", // Wird nach /public kopiert
    //     },
    //   ],
    // }),
  ],
  base: '/f/',
  server: {
    port: 3000,
    proxy: {
      // Leitet alle Anfragen, die mit /func beginnen, an deinen lokalen Server weiter
      '/func': {
        target: 'http://localhost:8338',
        changeOrigin: true,
        secure: false,
      },
      // Falls du auch andere API-Pfade hast, kannst du sie ebenfalls weiterleiten
      '/api': {
        target: 'http://localhost:8338',
        changeOrigin: true,
        secure: false,
      },
      '/decrypt': {
        target: 'http://localhost:8338',
        changeOrigin: true,
        secure: false,
      },
      '/git_timeset/': {
        target: 'http://localhost:8338',
        changeOrigin: true,
        secure: false,
      },
      '/local/': {
        target: 'http://localhost:8338',
        changeOrigin: true,
        secure: false,
      }
    }
  },
  build: {
    outDir: path.resolve(__dirname, '../incontainer/react-dist'),
    emptyOutDir: true,
    sourcemap: true,
  }
});