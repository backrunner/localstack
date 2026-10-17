import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import adapterCloudflare from '@sveltejs/adapter-cloudflare';
import adapterStatic from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { defineConfig } from 'vite';
import { svedocs } from 'svedocs/vite';
import { svedocsPreprocess, svedocsSvelteExtensions } from 'svedocs/svelte';
import svedocsConfig from './svedocs.config.ts';

const mode = process.env.SVEDOCS_BUILD_MODE ?? 'edge';
const adapter = mode === 'edge'
  ? adapterCloudflare({ platformProxy: { remoteBindings: false, persist: false } })
  : adapterStatic(mode === 'spa' ? { fallback: '200.html' } : { strict: false });

export default defineConfig({
  plugins: [
    svedocs({ config: svedocsConfig }),
    tailwindcss(),
    sveltekit({
      adapter,
      extensions: [...svedocsSvelteExtensions],
      preprocess: [vitePreprocess(), svedocsPreprocess()]
    })
  ]
});
