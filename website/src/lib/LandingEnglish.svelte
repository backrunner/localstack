<script lang="ts">
  import { resolveLocalizedHref } from 'svedocs/theme/headless';
  import type { SvedocsThemeContext } from 'svedocs/theme/types';
  import { release } from './release';

  export let context: SvedocsThemeContext;
  let appearance = 'dark';
  let selected = 'Vite';
  let copyStatus = '';
  const integrations = {
    Vite: {
      file: 'vite.config.ts',
      code: `import { defineConfig } from 'vite';\nimport LocalStack from 'unplugin-localstack/vite';\n\nexport default defineConfig({\n  plugins: [\n    LocalStack({ name: 'My next big thing' }),\n  ],\n});`,
      note: 'Name your project and register it on startup. Your dev server keeps running if LocalStack is unavailable.',
      href: '/docs/vite'
    },
    CLI: {
      file: 'Terminal',
      code: `# List your local sites\nlocalstack list\n\n# Check the local Coordinator\nlocalstack status\n\n# Get structured output for scripts\nlocalstack --json list`,
      note: 'List services and check status from the terminal. Use JSON output in your own scripts.',
      href: '/docs/cli'
    },
    MCP: {
      file: 'Terminal',
      code: `# Install into a supported client\nlocalstack mcp install --target auto\n\n# Check configuration and the local connection\nlocalstack --json mcp doctor\n\n# Or start the stdio MCP server directly\nlocalstack mcp serve`,
      note: 'Let MCP-capable coding assistants discover, register, and stop local services. Supports Codex, Claude Code, and Cursor.',
      href: '/docs/cli'
    }
  };
  $: active = integrations[selected as keyof typeof integrations];
  const href = (path: string) => resolveLocalizedHref(path, context);
  async function copyCode() {
    try {
      await navigator.clipboard.writeText(active.code);
      copyStatus = 'Copied';
    } catch {
      copyStatus = 'Select the code to copy';
    }
  }
</script>

<div class="landing">
  <section class="hero wrap" aria-labelledby="hero-title">
    <div class="hero-copy">
      <a class="release" href={release.notes}><span class="live-dot"></span> v{release.version} <span class="release-divider"></span> Now available <span aria-hidden="true">↗</span></a>
      <p class="eyebrow hero-eyebrow">A LITTLE ORDER FOR YOUR LOCALHOST.</p>
      <h1 id="hero-title">Your localhost.<br /><span>All in one place.</span></h1>
      <p class="hero-description">A quiet menu bar for your local dev servers.<br />Discover, open, and manage every local site in one place.</p>
      <div class="actions">
        <a class="button primary" href={release.download}>
          <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M16.4 3.4c-.8 1-1.8 1.6-2.8 1.5-.2-1 .3-2.1.9-2.9.8-.8 1.8-1.4 2.8-1.5.1 1.1-.3 2.1-.9 2.9ZM20.4 17c-.5 1.2-.8 1.7-1.5 2.8-.9 1.2-2.1 2.7-3.5 2.7-1.3 0-1.7-.9-3.5-.9s-2.2.9-3.5.9c-1.4 0-2.6-1.3-3.5-2.6C2.4 16.4 2 11.6 3.6 9.1c1.2-1.8 3-2.8 4.7-2.8 1.5 0 2.5.9 3.7.9 1.1 0 2.1-.9 3.8-.9 1.4 0 2.8.8 3.9 2.1-3.4 1.9-2.9 6.9.7 8.6Z" /></svg>
          {context.t('home.primaryAction')} <span aria-hidden="true">↓</span>
        </a>
        <a class="button secondary" href={href('/docs')}>{context.t('home.secondaryAction')} <span aria-hidden="true">↗</span></a>
      </div>
      <p class="download-meta">macOS 15+ <span>·</span> Apple Silicon & Intel <span>·</span> Free and open source</p>
      <div class="hero-footnote"><span class="tiny-stack" aria-hidden="true">≋</span> Made for Mac. Focused on your localhost.</div>
    </div>

    <div class="product-stage">
      <div class="stage-grid" aria-hidden="true"></div>
      <div class="stage-word" aria-hidden="true">localhost</div>
      <div class="desktop-bar" aria-hidden="true"><span>Finder</span><span>File　Edit　View</span><span class="bar-right">⌁　<img src="/brand/mark.svg" alt="" />　◷</span></div>
      <div class="terminal-ghost" aria-hidden="true"><div class="traffic"><i></i><i></i><i></i><span>~/projects/website</span></div><p><span>❯</span> npm run dev</p><p>VITE <span>ready</span></p><p class="terminal-url">➜ Local: http://localhost:5173/</p></div>
      <div class="app-window"><img src={`/brand/panel-${appearance}.png`} width="864" height="1200" alt={`LocalStack ${appearance === 'dark' ? 'Dark' : 'Light'}panel:four verified local sites with names, ports, and sources. Real app render with sample data.`} fetchpriority="high" /></div>
      <div class="verified"><span class="check-icon">✓</span><div>Service found, verified, reachable<small>localhost:5173 · HTTP 200</small></div></div>
      <div class="preview-controls"><span>Native UI · Sample data</span><div class="segmented" aria-label="Preview appearance"><button aria-pressed={appearance === 'dark'} on:click={() => appearance = 'dark'}>Dark</button><button aria-pressed={appearance === 'light'} on:click={() => appearance = 'light'}>Light</button></div></div>
    </div>
  </section>

  <div class="compatibility wrap"><span class="compat-label">Your workflow, exactly as it is</span><div><span class="tool-name"><b class="vite-mark">ϟ</b> Vite</span><span class="tool-name"><b>▲</b> Next.js</span><span class="tool-name"><b class="astro-mark">A</b> Astro</span><span class="tool-name"><b class="svelte-mark">S</b> SvelteKit</span><span class="tool-name"><b>▧</b> Any local HTML site</span></div></div>

  <section id="features" class="features wrap" aria-labelledby="features-title">
    <div class="section-heading"><div><p class="eyebrow">LESS HUNTING. MORE BUILDING.</p><h2 id="features-title">Less hunting.<br />More building.</h2></div><p>No terminal tab hunting and no port memorization.<br />LocalStack is there from the moment your project starts.</p></div>
    <div class="feature-grid">
      <article class="feature-card discovery"><div class="feature-number">01 / DISCOVER</div><h3>Start it. Find it.</h3><p>Automatically find local listeners and verify each page.<br />Every item is a real, browser-openable HTML site.</p><div class="probe-visual" aria-label="HTTP page verification"><div><span class="probe-port">:5173</span><span class="probe-track"></span><span class="probe-result">✓ text/html</span></div><div><span class="probe-port">:3000</span><span class="probe-track"></span><span class="probe-result">✓ text/html</span></div><div class="muted-probe"><span class="probe-port">:5432</span><span class="probe-track"></span><span class="probe-result">— Not a web service</span></div></div><a href={href('/docs/discovery')}>How discovery works <span aria-hidden="true">↗</span></a></article>
      <article class="feature-card native"><div class="feature-number">02 / STAY IN FLOW</div><h3>A familiar Mac feel.</h3><p>Native SwiftUI and AppKit with Liquid Glass.<br />Search, open, and copy addresses with a few keystrokes.</p><div class="shortcut-visual"><div><kbd>⌘</kbd><kbd>F</kbd><span>Search sites</span></div><div><kbd>↵</kbd><span>Open selected site</span></div><div><kbd>⌘</kbd><kbd>R</kbd><span>Refresh services</span></div></div><a href={href('/docs/usage')}>Use the menu bar panel <span aria-hidden="true">↗</span></a></article>
      <article class="feature-card safety"><div class="feature-number">03 / KEEP IT LOCAL</div><h3>Local means local.</h3><p>Only the current user’s loopback services are shown.<br />Process identity is re-verified before every stop.</p><div class="local-visual"><span class="local-label">YOUR MAC</span><div><span>App</span><i>↔</i><img src="/brand/mark.svg" width="48" height="48" alt="Coordinator" /><i>↔</i><span>localhost</span></div><small>User-owned Unix socket</small></div><a href={href('/docs/privacy')}>Privacy and security <span aria-hidden="true">↗</span></a></article>
    </div>
  </section>

  <section class="integrations wrap" aria-labelledby="integration-title">
    <div class="integration-copy"><p class="eyebrow">FITS RIGHT INTO YOUR STACK.</p><h2 id="integration-title">Fits right into<br />your stack.</h2><p>Beyond discovery, tell LocalStack<br class="desktop-break" />what your project is called and where it lives.</p><p>From the Vite plugin to the CLI and MCP.<br class="desktop-break" />Every entry point shares one reliable local Coordinator.</p><div class="integration-pills"><span>Vite plugin</span><span>TypeScript SDK</span><span>CLI</span><span>MCP</span></div><a class="text-link" href={href('/docs/vite')}>Add LocalStack to your project <span aria-hidden="true">↗</span></a></div>
    <div class="code-panel"><div class="code-tabs" role="tablist" aria-label="Integration examples">{#each Object.keys(integrations) as name}<button id={`tab-${name}`} role="tab" aria-selected={selected === name} aria-controls="integration-code" tabindex={selected === name ? 0 : -1} on:click={() => { selected = name; copyStatus = ''; }} on:keydown={(event) => { const names = Object.keys(integrations); let index = names.indexOf(selected); if (event.key === 'ArrowRight') index = (index + 1) % names.length; else if (event.key === 'ArrowLeft') index = (index - 1 + names.length) % names.length; else if (event.key === 'Home') index = 0; else if (event.key === 'End') index = names.length - 1; else return; event.preventDefault(); selected = names[index]; copyStatus = ''; document.getElementById(`tab-${selected}`)?.focus(); }}>{name}</button>{/each}<span>{active.file}</span></div><div id="integration-code" role="tabpanel" aria-labelledby={`tab-${selected}`} tabindex="0"><pre><code>{#each active.code.split('\n') as line, i}<span class="code-line"><span class="line-number" aria-hidden="true">{i + 1}</span><span class:comment={line.trim().startsWith('#')} class:import-line={line.startsWith('import')}>{line || ' '}</span></span>{/each}</code></pre></div><div class="code-bottom"><span class="code-status" aria-live="polite">{copyStatus || 'A small integration that fits naturally.'}</span><button on:click={copyCode} aria-label="Copy current integration example">Copy code <span aria-hidden="true">⧉</span></button></div><div class="integration-note"><span class="live-dot"></span><p>{active.note} <a href={href(active.href)}>Integration guide ↗</a></p></div></div>
  </section>

  <section class="getting-started wrap" aria-labelledby="start-title"><div class="section-heading"><div><p class="eyebrow">FROM DOWNLOAD TO DONE.</p><h2 id="start-title">Ready to tidy up localhost.</h2></div><a class="text-link" href={href('/docs')}>Full installation guide ↗</a></div><div class="steps"><article><span>01</span><div><h3>Download and install</h3><p>Open the DMG and move LocalStack to Applications.<br />Supports Apple Silicon and Intel Macs.</p></div></article><article><span>02</span><div><h3>Start your project</h3><p>Run your usual dev command.<br />LocalStack finds reachable local pages.</p></div></article><article><span>03</span><div><h3>Meet in the menu bar</h3><p>Click the three-layer stack icon.<br />Your sites are ready to go.</p></div></article></div></section>

  <section class="faq wrap" aria-labelledby="faq-title"><div><p class="eyebrow">A FEW GOOD QUESTIONS.</p><h2 id="faq-title">A few good questions.</h2></div><div class="questions"><details><summary>Do I need a plugin for every project?<span aria-hidden="true">+</span></summary><p>No. LocalStack automatically discovers and verifies local HTTP services. The Vite plugin and SDK are optional when you need custom names or project metadata.</p></details><details><summary>Which Macs are supported?<span aria-hidden="true">+</span></summary><p>LocalStack supports macOS 15 and newer with a universal Apple Silicon and Intel DMG. macOS 26 uses Liquid Glass; earlier versions use system materials.</p></details><details><summary>Do you upload my project or port information?<span aria-hidden="true">+</span></summary><p>No service names, ports, titles, or page contents are uploaded, and the LAN is never scanned. App updates access GitHub Releases separately from local discovery.<a href={href('/docs/privacy')}>Read the privacy policy ↗</a></p></details><details><summary>Is this related to the AWS emulator with the same name?<span aria-hidden="true">+</span></summary><p>This is an independent open source macOS local development service manager, unrelated to the LocalStack cloud emulator. It helps you find, open, and manage local web pages.</p></details><details><summary>Is it free to use?<span aria-hidden="true">+</span></summary><p>Yes. LocalStack is MIT licensed and open source. The stable release is available on GitHub, where you can report issues or contribute.</p></details></div></section>

  <section class="closing wrap"><div class="closing-mark"><img src="/brand/mark.svg" width="60" height="60" alt="" /></div><p class="eyebrow">YOUR LOCALHOST. A LITTLE MORE TOGETHER.</p><h2>Build great things. <br class="mobile-break" />The rest is in one place.</h2><a class="button primary" href={release.download}>{context.t('home.primaryAction')} <span aria-hidden="true">↓</span></a><p class="download-meta">v{release.version} <span>·</span> macOS 15+ <span>·</span> MIT open source</p><span class="closing-address" aria-hidden="true">127.0.0.1, sweet 127.0.0.1.</span></section>
</div>

<style>
  .landing { color: #edf4ef; overflow: clip; }
  .wrap { width: min(1200px, calc(100% - 64px)); margin-inline: auto; }
  a { text-decoration: none; }
  .hero { display: grid; grid-template-columns: 1.04fr 1fr; align-items: center; gap: 40px; min-height: 728px; padding-block: 54px 50px; }
  .hero-copy { position: relative; z-index: 2; }
  .release { display: inline-flex; align-items: center; gap: 10px; padding: 7px 11px; background: #91f4cc07; border: 1px solid #91f4cc23; border-radius: 6px; color: #b3c8bd; font-size: 11px; letter-spacing: .02em; }
  .live-dot { width: 5px; height: 5px; display: inline-block; flex-shrink: 0; background: #91f4cc; border-radius: 50%; box-shadow: 0 0 9px #91f4cc55; }
  .release-divider { width: 1px; height: 10px; background: #91f4cc30; }
  .eyebrow { color: #7eaa95; font: 10px/1.5 var(--font-mono); letter-spacing: .16em; margin: 0 0 22px; }
  .hero-eyebrow { margin-top: 34px; margin-bottom: 17px; font-size: 10px; }
  h1 { font-size: clamp(45px, 4.6vw, 66px); letter-spacing: -.055em; line-height: 1.3; font-weight: 650; margin: 0; }
  h1 > span { color: #91f4cc; }
  .hero-description { color: #a0afa7; line-height: 1.95; font-size: 15px; margin: 25px 0 30px; }
  .actions { display: flex; align-items: center; flex-wrap: wrap; gap: 12px; }
  .button { display: inline-flex; justify-content: center; align-items: center; gap: 12px; border: 1px solid transparent; border-radius: 8px; min-height: 49px; padding: 0 20px; font-size: 13px; font-weight: 600; transition: background .18s, transform .18s; }
  .button:hover { transform: translateY(-2px); }
  .primary { background: #91f4cc; color: #10291f; box-shadow: 0 2px 0 #c5ffe226 inset; }
  .primary:hover { background: #b1ffdf; }
  .button svg { width: 17px; height: 20px; }
  .button > span:last-child { margin-left: 10px; }
  .secondary { color: #d1ddd5; border-color: #ffffff20; background: #ffffff03; }
  .secondary:hover { background: #ffffff09; }
  .download-meta { color: #7d9186; font-size: 10px; letter-spacing: .02em; margin-top: 15px; }
  .download-meta span { margin-inline: 6px; }
  .hero-footnote { display: flex; align-items: center; gap: 9px; margin-top: 37px; color: #7b8f83; font-size: 11px; }
  .tiny-stack { font-size: 24px; line-height: 1; color: #91f4cc; transform: rotate(-15deg); }
  .product-stage { position: relative; min-width: 0; height: 596px; }
  .stage-grid { position: absolute; inset: -60px -130px -20px -60px; background: radial-gradient(ellipse at 56% 40%, #58956f29, transparent 65%), linear-gradient(#91f4cc06 1px, transparent 1px), linear-gradient(90deg, #91f4cc06 1px, transparent 1px); background-size: auto, 40px 40px, 40px 40px; mask-image: radial-gradient(ellipse, #000 25%, transparent 73%); }
  .stage-word { position: absolute; top: 230px; left: -85px; color: #91f4cc04; font: 700 122px var(--font-mono); letter-spacing: -.07em; transform: rotate(-90deg); }
  .desktop-bar { position: absolute; top: 25px; left: 5px; right: -25px; height: 33px; background: linear-gradient(90deg, #52635820, #66826e3a, #52635810); border: 1px solid #ffffff09; border-radius: 7px; color: #98b1a1; display: flex; align-items: center; gap: 22px; font-size: 10px; padding: 0 16px; }
  .desktop-bar > span:first-child { font-weight: 650; }
  .bar-right { display: flex; align-items: center; margin-left: auto; gap: 5px; }
  .bar-right img { width: 24px; height: 24px; }
  .terminal-ghost { position: absolute; left: -28px; top: 153px; width: 270px; height: 180px; border: 1px solid #69997e24; border-radius: 10px; background: #0e1713; transform: rotate(-5deg); padding: 14px; font: 10px/1.9 var(--font-mono); color: #789584; box-shadow: 0 25px 40px #0002; }
  .traffic { display: flex; align-items: center; gap: 5px; border-bottom: 1px solid #ffffff08; padding-bottom: 12px; margin-bottom: 16px; }
  .traffic i { width: 6px; height: 6px; border-radius: 50%; background: #66756b; }
  .traffic i:first-child { background: #a97166; }.traffic i:nth-child(2) { background: #ac9c69; }.traffic i:nth-child(3) { background: #769780; }
  .traffic span { font-size: 8px; margin-left: 12px; }
  .terminal-ghost p { margin: 5px 0; }.terminal-ghost p span { color: #91f4cc; }.terminal-url { font-size: 9px; }
  .app-window { position: absolute; width: 338px; top: 72px; right: 34px; border-radius: 16px; overflow: hidden; border: 1px solid #bacfbb30; box-shadow: 0 40px 100px #0009, 0 0 65px #91f4cc07; transform: rotate(2deg); transition: transform .35s; }
  .product-stage:hover .app-window { transform: rotate(0); }
  .app-window img { display: block; width: 100%; height: auto; }
  .verified { position: absolute; left: 0; top: 446px; display: flex; align-items: center; gap: 12px; padding: 14px 18px; border-radius: 10px; border: 1px solid #476754; background: #192b21f5; box-shadow: 0 12px 30px #0004; transform: rotate(-3deg); font-size: 11px; color: #d6e7dc; }
  .check-icon { display: grid; place-items: center; width: 28px; height: 28px; background: #91f4cc15; border: 1px solid #91f4cc30; border-radius: 50%; color: #91f4cc; font-size: 14px; }
  .verified small { display: block; font: 9px var(--font-mono); color: #8ea999; margin-top: 6px; }
  .preview-controls { position: absolute; bottom: 0; right: 32px; left: 65px; display: flex; justify-content: space-between; align-items: center; color: #82958b; font-size: 10px; }
  .segmented { display: flex; border: 1px solid #ffffff12; border-radius: 6px; padding: 3px; gap: 2px; }
  .segmented button { color: #8a9a90; font-size: 10px; padding: 4px 9px; border: none; border-radius: 4px; cursor: pointer; background: transparent; }
  .segmented button[aria-pressed="true"] { color: #cfdfd4; background: #ffffff10; }
  .compatibility { display: flex; align-items: center; gap: 45px; border-block: 1px solid #ffffff0e; padding-block: 25px; }
  .compat-label { color: #7e9186; font-size: 11px; white-space: nowrap; }
  .compatibility > div { display: flex; flex: 1; align-items: center; justify-content: space-between; gap: 20px; }
  .tool-name { color: #b7c4bc; display: flex; align-items: center; gap: 9px; font-size: 14px; font-weight: 600; white-space: nowrap; }
  .tool-name:last-child { font-size: 11px; font-weight: 400; }.tool-name b { color: #99ada1; font-size: 21px; }.tool-name .vite-mark { font-size: 30px; }.tool-name .svelte-mark { font-style: italic; }.astro-mark { font-family: serif; }
  .features { padding-block: 104px 76px; scroll-margin-top: 25px; }
  .section-heading { display: flex; justify-content: space-between; align-items: flex-end; gap: 35px; margin-bottom: 35px; }
  h2 { font-size: clamp(28px, 3vw, 38px); font-weight: 550; letter-spacing: -.04em; line-height: 1.45; margin: 0; }
  .section-heading > p, .integration-copy > p:not(.eyebrow) { color: #93a59a; font-size: 13px; line-height: 1.9; margin: 0 0 5px; }
  .feature-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; }
  .feature-card { padding: 28px 26px 22px; background: linear-gradient(145deg, #14221970, #10191460); border: 1px solid #ffffff0d; border-radius: 12px; }
  .feature-number { font: 9px var(--font-mono); letter-spacing: .1em; color: #788e80; margin-bottom: 29px; }
  h3 { font-size: 19px; letter-spacing: -.025em; font-weight: 550; margin: 0 0 12px; }
  .feature-card > p { color: #8ea094; font-size: 11px; line-height: 1.95; min-height: 48px; margin: 0; }
  .feature-card > a { display: flex; justify-content: space-between; color: #c0d3c6; font-size: 11px; border-top: 1px solid #ffffff0a; padding-top: 18px; }
  .feature-card > a:hover, .text-link:hover { color: #91f4cc; }
  .probe-visual { padding: 29px 4px 32px; }.probe-visual > div { display: flex; align-items: center; gap: 14px; padding: 8px 0; font: 10px var(--font-mono); }.probe-port { color: #c0d7c9; }.probe-track { height: 1px; flex: 1; background: linear-gradient(90deg, #91f4cc18, #91f4cc60); }.probe-result { color: #91f4cc; width: 96px; }.muted-probe { opacity: .42; }.muted-probe .probe-result { color: #c0d0c5; }
  .shortcut-visual { padding: 20px 2px 22px; display: flex; flex-direction: column; gap: 9px; }.shortcut-visual > div { display: flex; align-items: center; gap: 6px; }.shortcut-visual kbd { display: grid; place-items: center; width: 32px; height: 29px; border: 1px solid #ffffff15; border-bottom-width: 3px; background: #ffffff05; color: #bed0c4; border-radius: 5px; font-size: 13px; }.shortcut-visual span { color: #8ca393; margin-left: auto; font-size: 10px; }
  .local-visual { margin: 21px 0 22px; padding: 8px 13px 9px; border: 1px dashed #91f4cc26; border-radius: 8px; position: relative; }.local-label { font: 8px var(--font-mono); color: #8baf98; letter-spacing: .1em; }.local-visual > div { display: flex; align-items: center; justify-content: space-between; gap: 6px; margin: 8px 0; font: 9px var(--font-mono); }.local-visual i { color: #588268; font-style: normal; }.local-visual small { display: block; color: #87a291; text-align: center; font-size: 9px; }
  .integrations { display: grid; grid-template-columns: .92fr 1.08fr; gap: 95px; padding-block: 55px 100px; align-items: center; }.integration-copy h2 { margin-bottom: 24px; }.integration-copy > p:not(.eyebrow) { margin-bottom: 13px; }.integration-pills { display: flex; flex-wrap: wrap; gap: 7px; margin-top: 24px; }.integration-pills span { border: 1px solid #ffffff13; background: #ffffff03; border-radius: 5px; padding: 6px 9px; color: #a0b5a8; font: 9px var(--font-mono); }.text-link { display: inline-flex; align-items: center; gap: 25px; font-size: 12px; color: #cadbce; margin-top: 25px; }
  .code-panel { background: #101a15; border: 1px solid #ffffff16; border-radius: 12px; overflow: hidden; box-shadow: 0 15px 50px #0002; }.code-tabs { display: flex; align-items: center; border-bottom: 1px solid #ffffff0e; padding-inline: 14px; gap: 2px; }.code-tabs button { padding: 16px 13px; font: 11px var(--font-mono); color: #869d8e; background: transparent; border: 0; border-bottom: 2px solid transparent; cursor: pointer; }.code-tabs button[aria-selected="true"] { color: #91f4cc; border-bottom-color: #91f4cc; }.code-tabs > span { margin-left: auto; font: 9px var(--font-mono); color: #6f8677; }.code-panel pre { padding: 25px 15px; overflow-x: auto; font: 11px/2.2 var(--font-mono); margin: 0; min-height: 240px; }.code-line { display: flex; white-space: pre; color: #c6d9ca; }.line-number { width: 30px; text-align: center; color: #6c7e72; flex-shrink: 0; margin-right: 10px; user-select: none; }.import-line { color: #91d7ba; }.comment { color: #7f9a88; }.code-bottom { display: flex; justify-content: space-between; padding: 10px 20px 16px; gap: 10px; font-size: 10px; color: #80998a; }.code-bottom button { background: none; border: none; color: #bbd5c5; font-size: 10px; cursor: pointer; }.code-bottom button span { margin-left: 8px; }.integration-note { display: flex; align-items: flex-start; gap: 10px; background: #ffffff02; border-top: 1px solid #ffffff0a; padding: 15px 20px; }.integration-note .live-dot { margin-top: 6px; }.integration-note p { margin: 0; font-size: 10px; line-height: 1.8; color: #8ea997; }.integration-note a { color: #b2d8c2; white-space: nowrap; }
  .getting-started { padding-block: 60px 70px; border-top: 1px solid #ffffff0e; }.getting-started h2 { font-size: 30px; }.steps { display: grid; grid-template-columns: repeat(3, minmax(0,1fr)); gap: 28px; margin-top: 42px; }.steps article { display: flex; gap: 18px; }.steps article > span { font: 12px var(--font-mono); color: #91f4cc; padding-top: 3px; }.steps h3 { font-size: 14px; }.steps p { font-size: 11px; line-height: 1.9; color: #8b9f91; margin: 0; }
  .faq { display: grid; grid-template-columns: .8fr 1.2fr; gap: 75px; padding-block: 65px 95px; }.faq h2 { font-size: 28px; }.questions details { border-bottom: 1px solid #ffffff10; }.questions summary { display: flex; justify-content: space-between; align-items: center; cursor: pointer; list-style: none; padding: 19px 0; font-size: 12px; color: #c8d7cd; gap: 15px; }.questions summary::-webkit-details-marker { display: none; }.questions summary > span { color: #819b8b; font-size: 18px; }.questions details[open] summary > span { transform: rotate(45deg); }.questions p { font-size: 12px; line-height: 1.95; color: #98b0a0; padding-bottom: 18px; margin: 0; }.questions a { color: #91f4cc; }
  .closing { text-align: center; padding: 60px 25px 45px; border: 1px solid #91f4cc16; border-radius: 16px; background: radial-gradient(ellipse at 50% 0%, #345c3c36, transparent 75%), #101914; margin-bottom: 70px; position: relative; }.closing-mark { display: flex; justify-content: center; margin-bottom: 22px; }.closing .eyebrow { font-size: 8px; margin-bottom: 14px; }.closing h2 { font-size: 34px; margin-bottom: 30px; }.closing .button { min-height: 45px; }.closing-address { font: 9px var(--font-mono); letter-spacing: .08em; color: #668571; display: block; margin-top: 34px; }.mobile-break { display: none; }
  @media (min-width: 1450px) { .hero { min-height: 780px; }.product-stage { transform: scale(1.04); } }
  @media (max-width: 1080px) { .hero { gap: 10px; }.app-window { right: 4px; width: 310px; }.product-stage { height: 566px; }.desktop-bar { right: 0; }.verified { left: -5px; top: 430px; }.preview-controls { right: 0; left: 10px; }.terminal-ghost { left: 0; }.compatibility { gap: 25px; }.compatibility > div { flex-wrap: wrap; justify-content: flex-start; gap: 20px 30px; }.integrations { gap: 45px; }.feature-card { padding: 25px 18px 20px; }.faq { gap: 45px; } }
  @media (max-width: 800px) { .wrap { width: calc(100% - 40px); }.hero { grid-template-columns: 1fr; gap: 20px; padding-block: 40px 30px; }.hero-copy { padding-inline: 6px; }h1 { font-size: 54px; }.hero-description { font-size: 14px; }.hero-footnote { margin-top: 25px; }.product-stage { max-width: 520px; width: 100%; height: 590px; margin-inline: auto; }.app-window { width: 330px; right: 45px; }.terminal-ghost { left: 0; top: 160px; }.verified { left: 15px; top: 447px; }.desktop-bar { left: 0; right: 0; }.preview-controls { left: 40px; right: 40px; }.compatibility { flex-direction: column; align-items: flex-start; gap: 20px; padding-block: 24px; }.compatibility > div { gap: 18px 26px; }.tool-name { font-size: 12px; }.features { padding-block: 65px 35px; }.section-heading { align-items: flex-start; flex-direction: column; gap: 20px; }.section-heading > p { font-size: 12px; }.feature-grid { grid-template-columns: 1fr; }.feature-card { padding: 24px; }.feature-card > p { font-size: 13px; }.feature-number { margin-bottom: 19px; }.probe-visual { max-width: 430px; }.shortcut-visual { max-width: 430px; }.local-visual { max-width: 430px; }.feature-card > a { font-size: 12px; }.integrations { grid-template-columns: 1fr; padding-block: 45px 65px; gap: 30px; }.integration-copy > p:not(.eyebrow) { font-size: 13px; }.code-panel pre { font-size: 11px; }.steps { grid-template-columns: 1fr; gap: 30px; }.steps p { font-size: 12px; }.getting-started { padding-block: 45px; }.getting-started h2 { font-size: 25px; }.getting-started .text-link { margin-top: 0; }.faq { grid-template-columns: 1fr; gap: 20px; padding-block: 35px 60px; }.closing { margin-bottom: 40px; padding: 42px 20px 30px; }.closing h2 { font-size: 27px; }.mobile-break { display: block; } }
  @media (max-width: 400px) { h1 { font-size: 46px; }.hero-copy { padding-inline: 0; }.button { padding-inline: 15px; font-size: 12px; gap: 8px; }.product-stage { height: 534px; }.app-window { width: 288px; right: 9px; }.verified { left: 0; top: 419px; padding: 11px 13px; }.preview-controls { left: 0; right: 0; bottom: 0; }.terminal-ghost { left: -5px; width: 230px; }.desktop-bar { font-size: 9px; gap: 12px; }.code-tabs > span { font-size: 8px; }.code-tabs button { padding-inline: 10px; }.hero-eyebrow { font-size: 9px; }.download-meta { font-size: 9px; } }
</style>
