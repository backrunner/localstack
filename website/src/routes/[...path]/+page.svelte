<script lang="ts">
  import { DocsApp } from 'svedocs/theme';
  import themeComponents from 'virtual:svedocs/theme-components';
  import loadSearch from 'virtual:svedocs/search-loader';
  import Landing from '#lib/Landing.svelte';
  import LandingEnglish from '#lib/LandingEnglish.svelte';
  export let data;
</script>

<DocsApp page={data.page} pages={data.pages} tree={data.tree} search={data.search} config={data.config} content={data.content} layout={data.layout} {themeComponents} {loadSearch}>
  <svelte:fragment slot="landing" let:context>
    {#if data.page?.scopePath === '/'}
      {#if context.localeCode === 'en'}
        <LandingEnglish {context} />
      {:else}
        <Landing {context} />
      {/if}
    {/if}
  </svelte:fragment>
</DocsApp>
