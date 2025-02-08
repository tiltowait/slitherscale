<svelte:head>
		<meta property="og:description" content="A simple tool for measuring your pet snake using a photograph and a reference object." />
		<meta property="og:image" content="/slitherscale.png" />
		<meta property="og:title" content="SlitherScale - Measure snakes!" />
		<title>SlitherScale - Measure snakes!</title>
</svelte:head>

<script lang="ts">
  import Measurer from '$lib/Measurer.svelte'

  const tip = "Tip: Use a ruler!"
  const whatever = "Or anything you want. I'm not your mom."
</script>

<p class="my-4 mx-20 pb-4">
  Select an image, specify reference points and a <span class="tooltip underline" data-tip={tip}><strong>reference length</strong></span>, then click along <span class="tooltip underline" data-tip={whatever}><strong>your pet's spine</strong></span> to measure it. For more accurate results, use an overhead image.
</p>

<Measurer />
