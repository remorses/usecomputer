import { defineConfig } from 'vite'

import { holocron } from '@holocron.so/vite'
import { cloudflare } from '@cloudflare/vite-plugin'

export default defineConfig({
  plugins: [
    holocron({ entry: './src/server.tsx', pagesDir: './src' }),
    cloudflare({
      viteEnvironment: {
        name: 'rsc',
        childEnvironments: ['ssr'],
      },
    }),
  ],
})
