# LocalStack website

The official site at **https://localstack.pwp.sh**, built with svedocs 0.3.0 and SvelteKit 3, deployed to Cloudflare Workers.

## Develop

The site ships in Simplified Chinese (default) and English at `/en`, with localized docs, navigation, search records, canonical URLs, reciprocal hreflang, `x-default`, sitemap alternates, Open Graph metadata, and SoftwareApplication JSON-LD.


Requires Node.js 22.17+ and npm.

```sh
npm ci
npm run dev
```

## Validate and deploy

```sh
npm run check
npm run check:content
npm run build
npm exec wrangler deploy -- --dry-run
npm run deploy
```

`npm run deploy` repeats validation and the production build before publishing. Wrangler needs an authenticated Cloudflare account with Workers and custom-domain access to `pwp.sh`. Credentials belong in Wrangler's local credential store or environment variables, never in the repository.

`wrangler.jsonc` declares the `localstack-website` Worker and its custom domain. The site uses the edge build; svedocs owns routing, search, metadata, sitemap, Markdown twins, `/llms.txt`, `/llms-full.txt`, and agent content negotiation. Ask AI is disabled. Search runs locally.

## Edit

- `src/lib/Landing.svelte`: bespoke product homepage inside the svedocs landing slot.
- `src/lib/site.css`: shared brand and documentation styling.
- `svedocs.config.ts`: site, navigation, locale, search and SEO configuration.
- `content/docs`: user documentation.
- `content/pages`: homepage metadata and release notes.
- `src/lib/release.ts`: current download and release URLs. Update the installation guide, changelog and root README together when publishing a new release.
- `static/brand`: original project logo, real SwiftUI preview renders with sample data, and social image.

Run `node scripts/generate-social.mjs` to regenerate the social image and README banner. App screenshots originate from `LocalStack.app --render-previews <directory>`; they never connect demo records to the real Coordinator.

## Dependency audit

On October 18, 2026, `npm audit` reported 15 transitive dependency advisories (4 high, 7 moderate, 4 low) after the svedocs 0.3.0 upgrade and available non-breaking fixes. Affected trees include fast-glob/micromatch/braces, gray-matter/js-yaml/argparse/sprintf-js, nested KaTeX dependencies, and satori/fflate. npm's suggested forced fix downgrades svedocs and is not applied. This is not a clean dependency-audit result; review upstream fixes and exposure before accepting untrusted authored content. The site serves repository-owned content, uses local search, and keeps Ask AI and generated OG endpoints disabled by configuration. This does not prove every advisory is unreachable.

The SvelteKit 3 configuration lives in `vite.config.ts`; `#lib/*` imports replace `$lib`, and `tsconfig.json` extends `$app/tsconfig`. `npm ci` uses the committed lockfile.
