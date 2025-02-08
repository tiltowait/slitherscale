<script>
  import '../style.css';
</script>

<div class="min-h-screen flex flex-col">
  <header class="container mx-auto flex items-center justify-center gap-4 p-6 w-9/10 border-b">
    <img src="/slitherscale.png" alt="A snake on a scale" class="w-14 h-14">
    <h1 class="text-5xl font-bold">SlitherScale</h1>
  </header>

  <main class="container mx-auto flex-grow pt-4 w-4/5">
    <slot />
  </main>

  <footer class="footer footer-center bg-base-300 text-base-content p-4">
    <aside class="md:w-3/5">
      <p>
        This tool does not use cookies. It does not collect analytics. 
        It does not harvest your data. Images are not uploaded anywhere 
        and never leave your system.
      </p>
      <p>
        <a class="link link-primary" href="https://github.com/tiltowait/slitherscale" title="View the source on GitHub">
          View the source on GitHub.
        </a>
      </p>
    </aside>
  </footer>
</div>

