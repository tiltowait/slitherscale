<svelte:head>
		<meta property="og:description" content="A simple tool for measuring your pet snake using a photograph and a reference object." />
		<meta property="og:image" content="/slitherscale.png" />
		<meta property="og:title" content="SlitherScale - Measure snakes!" />
		<title>SlitherScale - Measure snakes!</title>
</svelte:head>

<script lang="ts">
  import Measurer from '$lib/Measurer.svelte'
</script>

<p class="notice" style="margin-top:0">
  Select an image, specify reference points and a reference length (tip: use a ruler!), then click along your pet's spine to measure it. For more accurate results, use a top-down image.
</p>

<Measurer />
