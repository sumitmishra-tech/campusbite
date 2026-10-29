import {defineConfig} from 'vitest/config';
import react from '@vitejs/plugin-react';
import {fileURLToPath} from 'node:url';

export default defineConfig({
  plugins: [react()],
  // Read VITE_* variables from the single .env in the project root
  envDir: fileURLToPath(new URL('..', import.meta.url)),
  server: {port: 5173},
  test: {environment: 'node'}
});
