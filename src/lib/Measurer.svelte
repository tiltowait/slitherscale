<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import Konva from "konva/lib/index";
  import type { KonvaEventObject } from "konva/lib/Node";

  type PathType = "reference" | "measurement";
  type Point = { x: number; y: number };
  type Unit = "in" | "cm" | "mm" | "fur";

  const VALID_TYPES = ["image/jpeg", "image/png", "image/webp"];
  const MAX_SIZE_MB = 25;
  const UNIT_LABELS = {
    in: "inches",
    cm: "centimeters",
    mm: "millimeters",
    fur: "furlongs",
  };
  const unitKeys = Object.keys(UNIT_LABELS) as Unit[];

  let fileInput: HTMLInputElement;
  let canvasContainer: HTMLDivElement;

  let currentPathType = $state<PathType>("reference");
  let currentUnit = $state<Unit>("in");
  let referencePoints = $state<Point[]>([]);
  let measurementPoints = $state<Point[]>([]);
  let referenceLength = $state<number | null>(null);
  let touchStartPosition: Point = { x: 0, y: 0 };

  const scaleFactor = $derived(
    referencePoints.length == 2 && referenceLength
      ? referenceLength / calculateTotalDistance(referencePoints)
      : null,
  );

  const currentMeasurementValue = $derived(
    scaleFactor && measurementPoints.length > 1
      ? (calculateTotalDistance(measurementPoints) * scaleFactor).toFixed(2)
      : null,
  );

  // In order to avoid a canvas dependency (which in turn gives a Python
  // dependency), we have to import Konva from konva/lib/index; however, this
  // breaks type-checking, but only in global scope. Inside functions, the
  // checker works just fine. Kludge: ignore the errors for these definitions.
  // @ts-ignore
  let stage: Konva.Stage;
  // @ts-ignore
  let layer: Konva.Layer;
  // @ts-ignore
  let backgroundImage: Konva.Image | null = null;

  async function handleFileSelect(event: Event) {
    const file = (event.target as HTMLInputElement)?.files?.[0];
    if (
      !file ||
      !VALID_TYPES.includes(file.type) ||
      file.size > MAX_SIZE_MB * 1024 ** 2
    ) {
      fileInput.value = "";
      alert(
        file ? `File too large (max ${MAX_SIZE_MB}MB)` : "Invalid file type",
      );
      return;
    }

    try {
      const img = await loadImageFile(file);
      applyImageToCanvas(img);
    } catch {
      fileInput.value = "";
      alert("Failed to load image");
    }
  }

  function initializeCanvas() {
    stage = new Konva.Stage({
      container: canvasContainer,
      width: canvasContainer.clientWidth,
      height: 600,
    });
    stage.on("touchstart", handleTouchStart);
    stage.on("click", handleCanvasClick);

    layer = new Konva.Layer();
    stage.add(layer);

    window.addEventListener("resize", handleResize);

    return () => stage.destroy();
  }

  function clearCanvas() {
    referencePoints = [];
    measurementPoints = [];
    currentPathType = "reference";
    referenceLength = null;

    layer.destroyChildren();
    if (backgroundImage) {
      layer.add(backgroundImage);
    }
    layer.batchDraw();
  }

  function handleResize() {
    stage.width(canvasContainer.clientWidth);
    layer.batchDraw();
  }

  /**
   * Measure the start of a tap so we don't add a point on a pan.
   */
  function handleTouchStart(_: KonvaEventObject<TouchEvent>) {
    const pos = stage.getPointerPosition();
    if (pos) touchStartPosition = pos;
  }

  function handleCanvasClick(e: KonvaEventObject<MouseEvent>) {
    if (!fileInput.value) return;

    const pos = stage.getPointerPosition();
    if (!pos) return;

    if (e.type === "tap") {
      let distance = Math.hypot(
        pos.x - touchStartPosition.x,
        pos.y - touchStartPosition.y,
      );
      if (distance > 5) {
        return;
      }
    }

    if (currentPathType === "reference") {
      handleReferencePoint(pos.x, pos.y);
    } else {
      handleMeasurementPoint(pos.x, pos.y);
    }
  }

  function handleReferencePoint(x: number, y: number) {
    if (referencePoints.length >= 2) return;
    if (!referenceLength) {
      alert("First, you must supply a reference length.");
      return;
    }

    referencePoints.push({ x, y });

    const circle = new Konva.Circle({
      x,
      y,
      radius: 5,
      fill: "red",
    });
    layer.add(circle);

    if (referencePoints.length === 2) {
      const [a, b] = referencePoints;
      const line = new Konva.Line({
        points: [a.x, a.y, b.x, b.y],
        stroke: "red",
        strokeWidth: 2,
      });
      layer.add(line);

      //scale.factor = scale.referenceLength! / Math.hypot(b.x - a.x, b.y - a.y);
      currentPathType = "measurement";

      layer.batchDraw();
    }
  }

  function handleMeasurementPoint(x: number, y: number) {
    if (!scaleFactor) return;

    measurementPoints.push({ x, y });

    const circle = new Konva.Circle({
      x,
      y,
      radius: 5,
      fill: "blue",
    });
    layer.add(circle);

    if (measurementPoints.length > 1) {
      const prev = measurementPoints.at(-2)!;
      const line = new Konva.Line({
        points: [prev.x, prev.y, x, y],
        stroke: "blue",
        strokeWidth: 2,
      });
      layer.add(line);
      layer.batchDraw();
    }
  }

  function calculateTotalDistance(points: Point[]) {
    return points.slice(1).reduce((total, p, i) => {
      const prev = points[i];
      return total + Math.hypot(p.x - prev.x, p.y - prev.y);
    }, 0);
  }

  async function loadImageFile(file: File) {
    return new Promise<HTMLImageElement>((resolve, reject) => {
      const url = URL.createObjectURL(file);
      const img = new Image();
      img.src = url;
      img.onload = () => {
        URL.revokeObjectURL(url);
        resolve(img);
      };
      img.onerror = reject;
    });
  }

  function applyImageToCanvas(img: HTMLImageElement) {
    const canvasWidth = canvasContainer.clientWidth;
    const scaleFactor = canvasWidth / img.width;

    if (backgroundImage) {
      backgroundImage.destroy();
    }

    backgroundImage = new Konva.Image({
      image: img,
      width: img.width * scaleFactor,
      height: img.height * scaleFactor,
      preventDefault: false,
    });

    layer.add(backgroundImage);
    stage.width(canvasWidth);
    stage.height(img.height * scaleFactor);
    layer.batchDraw();
  }

  onMount(initializeCanvas);
  onDestroy(() => stage?.destroy());
</script>

<!-- Updated template block -->
<div class="flex flex-col sm:flex-row sm:justify-between gap-4 items-center">
  <input
    bind:this={fileInput}
    type="file"
    class="file-input file-input-bordered file-input-primary w-full sm:w-auto"
    accept="image/*"
    onchange={handleFileSelect}
    aria-label="Choose image file"
  />

  <div class="flex gap-2 w-full sm:w-auto">
    <div
      class="btn btn-outline btn-primary flex-1 sm:flex-none pointer-events-none"
    >
      {currentPathType[0].toUpperCase() + currentPathType.slice(1)} Mode
    </div>

    <button class="btn btn-secondary flex-1 sm:flex-none" onclick={clearCanvas}>
      Reset
    </button>
  </div>
</div>

<div class="card bg-base-200 shadow mt-4">
  <div class="card-body p-4 sm:p-6">
    <div class="stats bg-base-100 shadow-sm w-full flex flex-col sm:flex-row">
      <div class="stat w-full">
        <div class="stat-title text-base-content/70">Reference length</div>
        <div class="flex flex-wrap items-center gap-2">
          <input
            type="number"
            min="0"
            step="0.125"
            bind:value={referenceLength}
            placeholder="Enter length"
            class="input input-bordered w-full sm:w-32"
          />
          <div class="join bg-base-200 rounded-sm w-full sm:w-auto">
            {#each unitKeys as unit}
              <button
                class="join-item btn btn-sm flex-1 sm:min-w-12 {currentUnit ===
                unit
                  ? 'btn-primary'
                  : 'btn-ghost'}"
                onclick={() => (currentUnit = unit as Unit)}
                aria-label={UNIT_LABELS[unit as Unit]}
              >
                {unit.toUpperCase()}
              </button>
            {/each}
          </div>
        </div>
      </div>

      <div class="stat w-full">
        <div class="stat-title text-base-content/70">Measured length</div>
        {#if currentMeasurementValue}
          <div class="stat-value text-primary break-words">
            {currentMeasurementValue}
            <span class="text-lg ml-1">{UNIT_LABELS[currentUnit]}</span>
          </div>
        {:else}
          <div class="stat-desc text-base">
            <em>
              {referenceLength
                ? referencePoints.length < 2
                  ? "Add reference points"
                  : "Add measurement points"
                : "Set the reference length"}
            </em>
          </div>
        {/if}
      </div>
    </div>
  </div>
</div>

<div
  class="w-full my-4 border border-gray-300 touch-manipulation"
  bind:this={canvasContainer}
>
  <canvas id="canvas"></canvas>
</div>
