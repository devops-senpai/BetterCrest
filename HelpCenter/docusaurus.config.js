const {themes: prismThemes} = require('prism-react-renderer');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Arma Help',
  tagline: 'Help articles for Arma, a fork of Crest.',
  favicon: 'img/arma-logo.svg',
  // Placeholder: the fork publishes its guides nowhere yet.
  url: 'https://devops-senpai.github.io',
  baseUrl: '/BetterCrest/guides/',
  organizationName: 'devops-senpai',
  projectName: 'Arma',
  trailingSlash: true,
  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },
  plugins: [require.resolve('./plugins/help-search-index')],
  presets: [
    [
      'classic',
      {
        docs: {
          routeBasePath: '/',
          sidebarPath: require.resolve('./sidebars.js'),
          breadcrumbs: true,
          showLastUpdateAuthor: false,
          showLastUpdateTime: false,
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
        sitemap: {
          changefreq: 'weekly',
          priority: 0.7,
        },
      },
    ],
  ],
  themeConfig: {
    image: 'img/arma-logo.svg',
    metadata: [
      {
        name: 'description',
        content: 'Help articles for Crest on Mac, iPad, and iPhone.',
      },
    ],
    colorMode: {
      defaultMode: 'light',
      disableSwitch: true,
      respectPrefersColorScheme: false,
    },
    navbar: {
      title: 'Arma Help',
      logo: {
        alt: 'Arma',
        src: 'img/arma-logo.svg',
      },
      items: [
        {type: 'docSidebar', sidebarId: 'helpSidebar', position: 'left', label: 'Articles'},
        {to: '/keyboard-shortcuts/', label: 'Shortcuts', position: 'left'},
        {to: '/extension-api-compatibility/', label: 'Compatibility', position: 'left'},
        {href: 'https://github.com/devops-senpai/BetterCrest', label: 'GitHub', position: 'right'},
      ],
    },
    docs: {
      sidebar: {
        hideable: true,
        autoCollapseCategories: false,
      },
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Arma',
          items: [
            {label: 'Repository', href: 'https://github.com/devops-senpai/BetterCrest'},
            {label: 'Based on Crest (not affiliated)', href: 'https://github.com/pauljoda/Crest'},
          ],
        },
        {
          title: 'Help',
          items: [
            {label: 'All articles', to: '/'},
            {label: 'Keyboard shortcuts', to: '/keyboard-shortcuts/'},
            {label: 'Split View', to: '/split-view/'},
            {label: 'Extension compatibility', to: '/extension-api-compatibility/'},
            {label: 'Support', href: 'https://github.com/devops-senpai/BetterCrest/blob/main/SUPPORT.md'},
          ],
        },
        {
          title: 'Community',
          items: [
            {label: 'GitHub Issues', href: 'https://github.com/devops-senpai/BetterCrest/issues/new/choose'},
            // Placeholder: no forum, chat, sponsorship or privacy page yet.
          ],
        },
      ],
      copyright: `BetterCrest is a fork of Crest and is not affiliated with Crest, Paul Davis or Arc. Crest © Paul Davis; Arma changes © ${new Date().getFullYear()} the Arma contributors.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  },
};

module.exports = config;
