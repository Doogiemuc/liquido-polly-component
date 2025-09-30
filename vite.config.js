import { defineConfig } from 'vite';
import path from 'path';
import { fileURLToPath, URL } from 'node:url';
import vue from '@vitejs/plugin-vue';

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      // map @ to ./src   but imports MUST have file endings (.js or .vue) !
      '@': fileURLToPath(new URL('./src', import.meta.url)),

      // laod a specific config file per environment
      //config: path.join(__dirname, 'config/config.' + process.env.NODE_ENV),
    },
  },
});
