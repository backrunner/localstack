import { defineConfig } from 'svedocs/config';

export default defineConfig({
  site: {
    name: 'LocalStack',
    title: 'LocalStack',
    description: '让本地开发，一目了然。原生 macOS 菜单栏工具，自动发现、验证并管理你的本地开发站点。',
    url: 'https://localstack.pwp.sh'
  },
  build: { mode: 'edge' },
  theme: {
    defaultMode: 'dark',
    palette: { accent: '#91f4cc', neutral: '#101c1b' },
    fonts: {
      sans: '"Inter", -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif',
      display: '"Inter", -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif',
      mono: '"SFMono-Regular", Consolas, "Liberation Mono", monospace'
    },
    radius: '12px',
    brand: { label: 'LocalStack', href: '/', logo: '/brand/mark.svg', mark: false },
    nav: [
      { label: '功能', labelKey: 'nav.features', href: '/#features' },
      { label: '文档', labelKey: 'nav.docs', href: '/docs' },
      { label: '版本更新', labelKey: 'nav.changelog', href: '/changelog' }
    ],
    social: [{ label: 'GitHub ↗', href: 'https://github.com/backrunner/localstack', external: true }],
    footer: {
      text: 'LocalStack · 为本地开发，留一处清净',
      links: [
        { label: 'MIT 开源', labelKey: 'footer.license', href: 'https://github.com/backrunner/localstack/blob/main/LICENSE', external: true },
        { label: '隐私与安全', labelKey: 'footer.privacy', href: '/docs/privacy' },
        { label: 'Built with svedocs', href: 'https://svedocs.pwp.sh', external: true }
      ]
    }
  },
  i18n: {
    defaultLocale: 'zh',
    prefixDefaultLocale: false,
    locales: [
      { code: 'zh', label: '简体中文', hreflang: 'zh-CN' },
      { code: 'en', label: 'English', hreflang: 'en' }
    ],
    messages: { zh: {
      'footer.text': 'LocalStack · 为本地开发，留一处清净', 'footer.license': 'MIT 开源', 'footer.privacy': '隐私与安全',
      'nav.skipToContent': '跳转到正文',
      'nav.primary': '主导航',
      'nav.documentation': '使用文档',
      'nav.docs': '文档',
      'nav.footer': '页脚导航',
      'nav.social': '项目链接',
      'nav.mobile.open': '打开菜单',
      'nav.mobile.close': '关闭菜单',
      'search.trigger': '搜索文档',
      'search.placeholder': '搜索文档',
      'search.dialog': '搜索文档',
      'search.query': '搜索内容',
      'search.results': '搜索结果',
      'search.loading': '正在搜索…',
      'search.loadingIndex': '正在加载搜索索引…',
      'search.indexError': '无法加载搜索索引，请稍后重试。',
      'search.empty': '没有找到匹配的文档。',
      'toc.label': '本页内容',
      'heading.anchor': '此章节的链接',
      'article.kind.doc': '使用文档',
      'article.kind.page': 'LocalStack',
      'article.breadcrumb': '当前位置',
      'article.updated': '更新于 {date}',
      'article.edit': '编辑此页',
      'article.previous': '上一篇',
      'article.next': '下一篇',
      'code.copy': '复制代码',
      'code.copied': '已复制',
      'tools.label': '页面工具',
      'tools.backToTop': '返回顶部',
      'error.notFound.title': '这里还没有页面',
      'error.notFound.description': '这个地址不存在。可以返回首页，或在文档中继续寻找。',
      'error.generic.title': '页面暂时无法打开',
      'error.generic.description': '请稍后重试，或从导航前往其他页面。',
      'error.status': '错误 {status}',
      'error.home': '返回首页',
      'error.docs': '查看文档',
      'home.primaryAction': '下载 macOS 版',
      'home.secondaryAction': '快速开始', 'nav.features': '功能', 'nav.changelog': '版本更新'
    }, en: {
      'footer.text': 'LocalStack · A quiet place for local development', 'footer.license': 'MIT open source', 'footer.privacy': 'Privacy and security',
      'nav.skipToContent': 'Skip to content', 'nav.primary': 'Primary navigation', 'nav.documentation': 'Documentation',
      'nav.docs': 'Docs', 'nav.features': 'Features', 'nav.changelog': 'Changelog', 'nav.footer': 'Footer navigation', 'nav.social': 'Project links',
      'nav.mobile.open': 'Open menu', 'nav.mobile.close': 'Close menu', 'search.trigger': 'Search docs', 'search.placeholder': 'Search docs',
      'search.dialog': 'Search documentation', 'search.query': 'Search query', 'search.results': 'Search results', 'search.loading': 'Searching…',
      'search.loadingIndex': 'Loading search index…', 'search.indexError': 'Could not load the search index.', 'search.empty': 'No matching documentation.',
      'toc.label': 'On this page', 'heading.anchor': 'Link to this section', 'article.kind.doc': 'Documentation', 'article.kind.page': 'LocalStack',
      'article.breadcrumb': 'Breadcrumb', 'article.updated': 'Updated {date}', 'article.edit': 'Edit this page', 'article.previous': 'Previous', 'article.next': 'Next',
      'code.copy': 'Copy code', 'code.copied': 'Copied', 'tools.label': 'Page tools', 'tools.backToTop': 'Back to top',
      'error.notFound.title': 'Page not found', 'error.notFound.description': 'This address does not exist.', 'error.generic.title': 'Page unavailable',
      'error.generic.description': 'Please try again or use the navigation.', 'error.status': 'Error {status}', 'error.home': 'Back home', 'error.docs': 'View docs',
      'home.primaryAction': 'Download for macOS', 'home.secondaryAction': 'Get started'
    } }
  },
  search: { provider: 'local', scope: 'current' },
  ai: false,
  seo: {
    ogImage: false,
    head: {
      meta: [
        { name: 'theme-color', content: '#0b1211' },
        { property: 'og:site_name', content: 'LocalStack' },
        { property: 'og:image', content: 'https://localstack.pwp.sh/brand/social.png' },
        { property: 'og:image:alt', content: 'LocalStack — your localhost, all in one place' },
        { name: 'twitter:card', content: 'summary_large_image' }
      ],
      jsonLd: [{
        '@context': 'https://schema.org',
        '@type': 'SoftwareApplication',
        name: 'LocalStack', applicationCategory: 'DeveloperApplication', operatingSystem: 'macOS 15+',
        description: 'A native macOS menu bar app for discovering and managing local development sites.',
        url: 'https://localstack.pwp.sh',
        downloadUrl: 'https://github.com/backrunner/localstack/releases/download/v0.2.3-beta.3/LocalStack-0.2.3-beta.3.dmg',
        license: 'https://github.com/backrunner/localstack/blob/main/LICENSE',
        offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' }
      }]
    }
  },
  checks: { translations: true },
  source: { editBaseUrl: 'https://github.com/backrunner/localstack/edit/main/website' }
});
