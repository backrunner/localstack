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
      note: '为项目命名，启动时自动注册。即使 LocalStack 尚未运行，也不会阻塞你的开发服务器。',
      href: '/docs/vite'
    },
    CLI: {
      file: 'Terminal',
      code: `# 看看现在有哪些站点\nlocalstack list\n\n# 检查本地 Coordinator\nlocalstack status\n\n# 给脚本一个结构化结果\nlocalstack --json list`,
      note: '在终端里列出服务、检查状态。用 JSON 输出，把本地服务接入你自己的脚本。',
      href: '/docs/cli'
    },
    MCP: {
      file: 'Terminal',
      code: `# 安装到已有的受支持客户端\nlocalstack mcp install --target auto\n\n# 检查配置和本地连接\nlocalstack --json mcp doctor\n\n# 或直接启动 stdio MCP server\nlocalstack mcp serve`,
      note: '让支持 MCP 的编程助手发现、注册和停止本地服务。支持 Codex、Claude Code 与 Cursor。',
      href: '/docs/cli'
    }
  };
  $: active = integrations[selected as keyof typeof integrations];
  const href = (path: string) => resolveLocalizedHref(path, context);
  async function copyCode() {
    try {
      await navigator.clipboard.writeText(active.code);
      copyStatus = '已复制';
    } catch {
      copyStatus = '请选中代码复制';
    }
  }
</script>

<div class="landing">
  <section class="hero wrap" aria-labelledby="hero-title">
    <div class="hero-copy">
      <a class="release" href={release.notes}><span class="live-dot"></span> v{release.version} <span class="release-divider"></span> 现已发布 <span aria-hidden="true">↗</span></a>
      <p class="eyebrow hero-eyebrow">A LITTLE ORDER FOR YOUR LOCALHOST.</p>
      <h1 id="hero-title">让本地开发，<br /><span>一目了然。</span></h1>
      <p class="hero-description">你的项目开在哪个端口？<br />把散落的本地站点，收进一个安静的菜单栏。<br class="desktop-break" />自动发现，一键打开，随时掌握。</p>
      <div class="actions">
        <a class="button primary" href={release.download}>
          <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M16.4 3.4c-.8 1-1.8 1.6-2.8 1.5-.2-1 .3-2.1.9-2.9.8-.8 1.8-1.4 2.8-1.5.1 1.1-.3 2.1-.9 2.9ZM20.4 17c-.5 1.2-.8 1.7-1.5 2.8-.9 1.2-2.1 2.7-3.5 2.7-1.3 0-1.7-.9-3.5-.9s-2.2.9-3.5.9c-1.4 0-2.6-1.3-3.5-2.6C2.4 16.4 2 11.6 3.6 9.1c1.2-1.8 3-2.8 4.7-2.8 1.5 0 2.5.9 3.7.9 1.1 0 2.1-.9 3.8-.9 1.4 0 2.8.8 3.9 2.1-3.4 1.9-2.9 6.9.7 8.6Z" /></svg>
          {context.t('home.primaryAction')} <span aria-hidden="true">↓</span>
        </a>
        <a class="button secondary" href={href('/docs')}>{context.t('home.secondaryAction')} <span aria-hidden="true">↗</span></a>
      </div>
      <p class="download-meta">macOS 15+ <span>·</span> Apple Silicon & Intel <span>·</span> 免费开源</p>
      <div class="hero-footnote"><span class="tiny-stack" aria-hidden="true">≋</span> 专为 Mac 打造。只关心你的 localhost。</div>
    </div>

    <div class="product-stage">
      <div class="stage-grid" aria-hidden="true"></div>
      <div class="stage-word" aria-hidden="true">localhost</div>
      <div class="desktop-bar" aria-hidden="true"><span>Finder</span><span>文件　编辑　显示</span><span class="bar-right">⌁　<img src="/brand/mark.svg" alt="" />　◷</span></div>
      <div class="terminal-ghost" aria-hidden="true"><div class="traffic"><i></i><i></i><i></i><span>~/projects/website</span></div><p><span>❯</span> npm run dev</p><p>VITE <span>ready</span></p><p class="terminal-url">➜ Local: http://localhost:5173/</p></div>
      <div class="app-window"><img src={`/brand/panel-${appearance}.png`} width="864" height="1200" alt={`LocalStack ${appearance === 'dark' ? '深色' : '浅色'}面板：四个已验证的本地站点，包含名称、端口和来源。应用真实渲染，使用示例数据。`} fetchpriority="high" /></div>
      <div class="verified"><span class="check-icon">✓</span><div>发现服务，确认可达<small>localhost:5173 · HTTP 200</small></div></div>
      <div class="preview-controls"><span>原生界面 · 示例数据</span><div class="segmented" aria-label="应用预览外观"><button aria-pressed={appearance === 'dark'} on:click={() => appearance = 'dark'}>深色</button><button aria-pressed={appearance === 'light'} on:click={() => appearance = 'light'}>浅色</button></div></div>
    </div>
  </section>

  <div class="compatibility wrap"><span class="compat-label">你的工作流，原样保留</span><div><span class="tool-name"><b class="vite-mark">ϟ</b> Vite</span><span class="tool-name"><b>▲</b> Next.js</span><span class="tool-name"><b class="astro-mark">A</b> Astro</span><span class="tool-name"><b class="svelte-mark">S</b> SvelteKit</span><span class="tool-name"><b>▧</b> 任何本地 HTML 站点</span></div></div>

  <section id="features" class="features wrap" aria-labelledby="features-title">
    <div class="section-heading"><div><p class="eyebrow">LESS HUNTING. MORE BUILDING.</p><h2 id="features-title">少找一个端口。<br />多留一点心流。</h2></div><p>不必翻遍终端标签，也不必记住每个端口。<br />从启动项目的那一刻起，LocalStack 就在这里。</p></div>
    <div class="feature-grid">
      <article class="feature-card discovery"><div class="feature-number">01 / DISCOVER</div><h3>启动，就能找到。</h3><p>自动发现本机监听端口，独立检查页面。<br />列表里的每一项，都是真正可打开的 HTML 站点。</p><div class="probe-visual" aria-label="HTTP 页面验证示意"><div><span class="probe-port">:5173</span><span class="probe-track"></span><span class="probe-result">✓ text/html</span></div><div><span class="probe-port">:3000</span><span class="probe-track"></span><span class="probe-result">✓ text/html</span></div><div class="muted-probe"><span class="probe-port">:5432</span><span class="probe-track"></span><span class="probe-result">— 非网页服务</span></div></div><a href={href('/docs/discovery')}>了解自动发现 <span aria-hidden="true">↗</span></a></article>
      <article class="feature-card native"><div class="feature-number">02 / STAY IN FLOW</div><h3>熟悉的 Mac 手感。</h3><p>原生 SwiftUI 与 AppKit，配合 Liquid Glass。<br />搜索、打开、复制地址，几次按键就够了。</p><div class="shortcut-visual"><div><kbd>⌘</kbd><kbd>F</kbd><span>搜索站点</span></div><div><kbd>↵</kbd><span>打开选中站点</span></div><div><kbd>⌘</kbd><kbd>R</kbd><span>刷新服务</span></div></div><a href={href('/docs/usage')}>认识菜单栏面板 <span aria-hidden="true">↗</span></a></article>
      <article class="feature-card safety"><div class="feature-number">03 / KEEP IT LOCAL</div><h3>本地的，就留在本地。</h3><p>只查看当前用户的 loopback 服务。<br />停止前重新验证进程身份，让每次操作都有依据。</p><div class="local-visual"><span class="local-label">YOUR MAC</span><div><span>App</span><i>↔</i><img src="/brand/mark.svg" width="48" height="48" alt="Coordinator" /><i>↔</i><span>localhost</span></div><small>用户私有 Unix socket</small></div><a href={href('/docs/privacy')}>了解隐私与安全 <span aria-hidden="true">↗</span></a></article>
    </div>
  </section>

  <section class="integrations wrap" aria-labelledby="integration-title">
    <div class="integration-copy"><p class="eyebrow">FITS RIGHT INTO YOUR STACK.</p><h2 id="integration-title">顺手的工具，<br />也懂你的工具。</h2><p>自动发现之外，还能主动告诉 LocalStack<br class="desktop-break" />你的项目叫什么、住在哪里。</p><p>从 Vite 插件到 CLI，再到编程助手的 MCP。<br class="desktop-break" />所有入口，共用同一个可靠的本地 Coordinator。</p><div class="integration-pills"><span>Vite plugin</span><span>TypeScript SDK</span><span>CLI</span><span>MCP</span></div><a class="text-link" href={href('/docs/vite')}>把 LocalStack 接入你的项目 <span aria-hidden="true">↗</span></a></div>
    <div class="code-panel"><div class="code-tabs" role="tablist" aria-label="集成示例">{#each Object.keys(integrations) as name}<button id={`tab-${name}`} role="tab" aria-selected={selected === name} aria-controls="integration-code" tabindex={selected === name ? 0 : -1} on:click={() => { selected = name; copyStatus = ''; }} on:keydown={(event) => { const names = Object.keys(integrations); let index = names.indexOf(selected); if (event.key === 'ArrowRight') index = (index + 1) % names.length; else if (event.key === 'ArrowLeft') index = (index - 1 + names.length) % names.length; else if (event.key === 'Home') index = 0; else if (event.key === 'End') index = names.length - 1; else return; event.preventDefault(); selected = names[index]; copyStatus = ''; document.getElementById(`tab-${selected}`)?.focus(); }}>{name}</button>{/each}<span>{active.file}</span></div><div id="integration-code" role="tabpanel" aria-labelledby={`tab-${selected}`} tabindex="0"><pre><code>{#each active.code.split('\n') as line, i}<span class="code-line"><span class="line-number" aria-hidden="true">{i + 1}</span><span class:comment={line.trim().startsWith('#')} class:import-line={line.startsWith('import')}>{line || ' '}</span></span>{/each}</code></pre></div><div class="code-bottom"><span class="code-status" aria-live="polite">{copyStatus || '小小接入，自然融入。'}</span><button on:click={copyCode} aria-label="复制当前集成示例">复制代码 <span aria-hidden="true">⧉</span></button></div><div class="integration-note"><span class="live-dot"></span><p>{active.note} <a href={href(active.href)}>接入指南 ↗</a></p></div></div>
  </section>

  <section class="getting-started wrap" aria-labelledby="start-title"><div class="section-heading"><div><p class="eyebrow">FROM DOWNLOAD TO DONE.</p><h2 id="start-title">准备好，收拾一下 localhost。</h2></div><a class="text-link" href={href('/docs')}>完整安装指南 ↗</a></div><div class="steps"><article><span>01</span><div><h3>下载并安装</h3><p>打开 DMG，把 LocalStack 安装到应用程序。<br />支持 Apple Silicon 与 Intel Mac。</p></div></article><article><span>02</span><div><h3>照常启动项目</h3><p>运行熟悉的开发命令。<br />LocalStack 自动发现可访问的本地页面。</p></div></article><article><span>03</span><div><h3>在菜单栏相遇</h3><p>点击三层堆叠的图标。<br />你的站点，已经各就各位。</p></div></article></div></section>

  <section class="faq wrap" aria-labelledby="faq-title"><div><p class="eyebrow">A FEW GOOD QUESTIONS.</p><h2 id="faq-title">你可能还想知道。</h2></div><div class="questions"><details><summary>需要为每个项目安装插件吗？<span aria-hidden="true">+</span></summary><p>不需要。LocalStack 会自动发现当前用户的本地 HTTP 服务，并验证 HTML 页面。Vite 插件与 SDK 是可选项，适合需要自定义名称、项目路径等元数据的项目。</p></details><details><summary>支持哪些 Mac？<span aria-hidden="true">+</span></summary><p>支持 macOS 15 及以上版本，DMG 包含 Apple Silicon 和 Intel 通用应用。在 macOS 26 上使用 Liquid Glass，较早版本使用系统材质。</p></details><details><summary>会上传我的项目或端口信息吗？<span aria-hidden="true">+</span></summary><p>不会上传服务名、端口、标题或页面内容，也不会扫描局域网。应用更新会访问 GitHub Releases；这与本地服务发现是独立的。<a href={href('/docs/privacy')}>阅读隐私说明 ↗</a></p></details><details><summary>它和同名的 AWS 模拟器是什么关系？<span aria-hidden="true">+</span></summary><p>这是一个独立的开源 macOS 本地开发服务管理项目，与 LocalStack 云服务模拟器没有关联。它的职责是帮你找到、打开和管理本机的开发网页。</p></details><details><summary>现在可以免费使用吗？<span aria-hidden="true">+</span></summary><p>可以。LocalStack 使用 MIT 许可证，源代码公开。正式版已在 GitHub 发布，你可以提交问题或参与改进。</p></details></div></section>

  <section class="closing wrap"><div class="closing-mark"><img src="/brand/mark.svg" width="60" height="60" alt="" /></div><p class="eyebrow">YOUR LOCALHOST. A LITTLE MORE TOGETHER.</p><h2>好好写代码。<br class="mobile-break" />剩下的，一目了然。</h2><a class="button primary" href={release.download}>{context.t('home.primaryAction')} <span aria-hidden="true">↓</span></a><p class="download-meta">v{release.version} <span>·</span> macOS 15+ <span>·</span> MIT 开源</p><span class="closing-address" aria-hidden="true">127.0.0.1, sweet 127.0.0.1.</span></section>
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
