<script lang="ts">
  import { onMount } from 'svelte'
  import { Canvas, Circle, Line, FabricImage, type FabricObject, type TEvent } from 'fabric'

  type PathType = 'reference' | 'measurement'
  type Unit = 'in' | 'cm' | 'mm' | 'fur'

  const VALID_TYPES = ['image/jpeg', 'image/png', 'image/webp']
  const MAX_SIZE_MB = 25
  const UNIT_LABELS = {
    'in': 'inches',
    'cm': 'centimeters',
    'mm': 'millimeters',
    'fur': 'furlongs'
  }

  let fileInput: HTMLInputElement
  let canvasContainer: HTMLDivElement
  let canvas: Canvas

  let currentPathType: PathType = 'reference'
  let currentUnit: Unit = 'in'
  let referencePoints: { x: number; y: number }[] = []
  let measurementPoints: { x: number; y: number }[] = []

  const scale = {
    factor: null as number | null,
    referenceLength: null as number | null
  }
  const currentMeasurement = {
    value: null as string | null
  }

  async function handleFileSelect(event: Event) {
    const file = (event.target as HTMLInputElement)?.files?.[0]
    if (!file || !VALID_TYPES.includes(file.type) || file.size > MAX_SIZE_MB * 1024**2) {
      fileInput.value = ''
      alert(file ? `File too large (max ${MAX_SIZE_MB}MB)` : 'Invalid file type')
      return
    }

    try {
      const img = await loadImageFile(file)
      applyImageToCanvas(new FabricImage(img, { originX: 'left', originY: 'top' }))
    } catch {
      fileInput.value = ''
      alert('Failed to load image')
    }
  }

  function applyImageToCanvas(img: FabricImage) {
    const canvasWidth = canvasContainer.clientWidth || 800 // Fallback width
    const scaleFactor = canvasWidth / img.width!

    img.set({
      scaleX: scaleFactor,
      scaleY: scaleFactor,
      originX: 'left',
      originY: 'top'
    })
    canvas.setDimensions({
      width: canvasWidth,
      height: img.height! * scaleFactor
    })

    canvas.backgroundImage = img
    canvas.renderAll()
  }

  function initializeCanvas() {
    canvas = new Canvas('canvas', {
      width: canvasContainer.clientWidth,
      height: 600,
      selection: false
    })

    canvas.on('mouse:down', ({ e }: TEvent) => {
      if (!fileInput.value) return
      const { x, y } = canvas.getScenePoint(e)

      if (currentPathType === 'reference') {
        handleReferencePoint(x, y)
      } else {
        handleMeasurementPoint(x, y)
      }
    })

    window.addEventListener('resize', () => 
      canvas.setDimensions({ width: canvasContainer.clientWidth })
    )

    return () => canvas.dispose()
  }

  function handleReferencePoint(x: number, y: number) {
    if (referencePoints.length >= 2) return
    if (!scale.referenceLength) {
      alert("First, you must supply a reference length.")
      return
    }

    referencePoints.push({ x, y })
    addCanvasObject(new Circle({
      left: x,
      top: y,
      radius: 5,
      fill: 'red',
      originX: 'center',
      originY: 'center',
    }))

    if (referencePoints.length === 2) {
      const [a, b] = referencePoints
      addCanvasObject(new Line([a.x, a.y, b.x, b.y], {
        stroke: 'red',
        strokeWidth: 2,
        selectable: false,
        evented: false,
      }))
      scale.factor = scale.referenceLength! / Math.hypot(b.x - a.x, b.y - a.y)
      currentPathType = 'measurement'
    }
  }

  function handleMeasurementPoint(x: number, y: number) {
    if (!scale.factor) return

    measurementPoints.push({ x, y })
    addCanvasObject(new Circle({
      left: x,
      top: y,
      radius: 5,
      fill: 'blue',
      originX: 'center',
      originY: 'center',
    }))

    if (measurementPoints.length > 1) {
      const prev = measurementPoints.at(-2)!
      addCanvasObject(new Line([prev.x, prev.y, x, y], {
        stroke: 'blue',
        strokeWidth: 2,
        selectable: false,
        evented: false,
      }))
      currentMeasurement.value = scale.factor
        ? (measurementPoints.slice(1).reduce((total, p, i) => 
            total + Math.hypot(p.x - measurementPoints[i].x, p.y - measurementPoints[i].y), 0
          ) * scale.factor).toFixed(2)
        : null
    }
  }

  function addCanvasObject(obj: FabricObject) {
    canvas.add(obj)
    canvas.requestRenderAll()
    return obj
  }

  function clearCanvas() {
    const bgImage = canvas.backgroundImage
    canvas.clear()

    if (bgImage) {
      canvas.backgroundImage = bgImage
      canvas.requestRenderAll()
    }

    referencePoints = []
    measurementPoints = []
    currentPathType = 'reference'
    scale.factor = null
    scale.referenceLength = null
    currentMeasurement.value = null
  }

  async function loadImageFile(file: File) {
    return new Promise<HTMLImageElement>((resolve, reject) => {
      const url = URL.createObjectURL(file)
      const img = new Image()
      img.src = url
      img.onload = () => {
        URL.revokeObjectURL(url)
        resolve(img)
      }
      img.onerror = reject
    })
  }
  
  onMount(initializeCanvas)

</script>

<!-- Updated template block -->
<div class="flex flex-col sm:flex-row sm:justify-between gap-4 items-center">
  <input
    bind:this={fileInput}
    type="file"
    class="file-input file-input-bordered file-input-primary w-full sm:w-auto"
    accept="image/*"
    on:change={handleFileSelect}
    aria-label="Choose image file"
  />

  <div class="flex gap-2 w-full sm:w-auto">
    <div class="btn btn-outline btn-primary flex-1 sm:flex-none pointer-events-none">
      {currentPathType[0].toUpperCase() + currentPathType.slice(1)} Mode
    </div>

    <button class="btn btn-secondary flex-1 sm:flex-none" on:click={clearCanvas}>
      Reset
    </button>
  </div>
</div>

<div class="card bg-base-200 shadow mt-4">
  <div class="card-body p-4 sm:p-6">
    <div class="stats bg-base-100 shadow-sm w-full flex flex-col sm:flex-row">
      <div class="stat w-full">
        <div class="stat-title text-base-content/70">Reference Length</div>
        <div class="flex flex-wrap items-center gap-2">
          <input
            type="number"
            min="0"
            step="0.125"
            bind:value={scale.referenceLength}
            placeholder="Enter length"
            class="input input-bordered w-full sm:w-32"
          />
          <div class="join bg-base-200 rounded-sm w-full sm:w-auto">
            {#each Object.keys(UNIT_LABELS) as unit}
              <button 
                class="join-item btn btn-sm flex-1 sm:min-w-12 {currentUnit === unit ? 'btn-primary' : 'btn-ghost'}"
                on:click={() => currentUnit = unit as Unit}
                aria-label={UNIT_LABELS[unit as Unit]}
              >
                {unit.toUpperCase()}
              </button>
            {/each}
          </div>
        </div>
      </div>

      <div class="stat w-full">
        <div class="stat-title text-base-content/70">Total Length</div>
        {#if currentMeasurement.value}
          <div class="stat-value text-primary break-words">
            {currentMeasurement.value}
            <span class="text-lg ml-1">{UNIT_LABELS[currentUnit]}</span>
          </div>
        {:else}
          <div class="stat-desc text-base">
            <em>
              {scale.referenceLength 
                ? referencePoints.length < 2 ? 'Add reference points' : 'Add measurement points'
                : 'Set the reference length'}
            </em>
          </div>
        {/if}
      </div>
    </div>
  </div>
</div>

<div class="w-full my-4 border border-gray-300" bind:this={canvasContainer}>
  <canvas id="canvas"></canvas>
</div>
