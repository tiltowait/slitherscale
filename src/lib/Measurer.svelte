<script lang="ts">
  import { onMount } from 'svelte'
  import { 
    Canvas, 
    Circle, 
    Line, 
    Group, 
    Image,
    type FabricObject
  } from 'fabric'

  type PathType = 'reference' | 'measurement'

  let fileInput: HTMLInputElement
  let canvas: Canvas
  let currentPathType: PathType = 'reference'
  let canvasContainer: HTMLDivElement
  let referencePointCount = 0
  let referenceLengthInches: number | null = null
  let referenceDistance: number | null = null
  let scaleFactor: number | null = null
  let currentMeasurement: string | null = null
  let totalDistance = 0

  onMount(() => {
    canvas = new Canvas('canvas', {
      width: canvasContainer.clientWidth,
      height: 600,
      selection: false
    })

    window.addEventListener('resize', () => {
      canvas.setWidth(canvasContainer.clientWidth)
      canvas.requestRenderAll()
    })

    canvas.on('mouse:down', handleCanvasClick)

    return () => {
      canvas.dispose()
    }
  })

  function handleFileSelect(event: Event) {
    const target = event.target as HTMLInputElement
    const file = target.files?.[0]

    if (file && file.type.startsWith('image/')) {
      const reader = new FileReader()
      reader.onload = (e) => {
        const result = e.target?.result
        if (typeof result === 'string') {
          Image.fromURL(result).then((img) => {
            canvas.clear()
            const scale = canvas.width! / img.width!
            img.scale(scale)
            img.set({
              originX: 'left',
              originY: 'top'
            })

            canvas.backgroundImage = img
            canvas.setHeight(img.height! * scale)
            canvas.requestRenderAll()
          })
        }
      }
      reader.readAsDataURL(file)
    } else {
      if (fileInput) fileInput.value = ''
      alert('Please select a valid image file')
    }
  }

  let currentGroup: Group | null = null
  let pathPoints: { x: number; y: number }[] = []

  function createCircle(left: number, top: number, color: string) {
    return new Circle({
      left,
      top,
      radius: 5,
      fill: color,
      originX: 'center',
      originY: 'center',
      selectable: false,
      evented: false
    })
  }

  function createLine(points: number[], color: string) {
    return new Line(points, {
      stroke: color,
      strokeWidth: 2,
      selectable: false,
      evented: false
    })
  }

  function calculateDistance(point1: { x: number; y: number }, point2: { x: number; y: number }): number {
    return Math.sqrt(
      Math.pow(point2.x - point1.x, 2) +
      Math.pow(point2.y - point1.y, 2)
    )
  }

  function calculateTotalMeasurement(): string | null {
    if (!scaleFactor || pathPoints.length < 2) return null

    const distance = pathPoints.reduce((total, point, index) => {
      if (index === 0) return 0
      return total + calculateDistance(pathPoints[index - 1], point)
    }, 0)

    return (distance * scaleFactor).toFixed(2)
  }

  function handleCanvasClick(event: { e: MouseEvent }) {
    if (!fileInput.value) {
      return
    }
    const pointer = canvas.getPointer(event.e)
    const point = { x: pointer.x, y: pointer.y }

    if (currentPathType === 'reference') {
      if (referencePointCount >= 2) {
        return
      }

      if (pathPoints.length === 0) {
        // Start new reference path
        pathPoints = [point]
        const circle = createCircle(point.x, point.y, 'red')
        canvas.add(circle)
        currentGroup = new Group([circle], {
          selectable: false,
          evented: false
        })
        canvas.add(currentGroup)
        referencePointCount++
      } else if (pathPoints.length === 1) {
        // Complete reference path
        pathPoints.push(point)
        const circle = createCircle(point.x, point.y, 'red')
        const line = createLine([
          pathPoints[0].x,
          pathPoints[0].y,
          point.x,
          point.y
        ], 'red')

        canvas.add(circle)
        canvas.add(line)

        if (currentGroup) {
          const objects = currentGroup.getObjects()
          currentGroup.remove(...objects)
          currentGroup.add(circle, line, ...objects)
          canvas.requestRenderAll()
        }

        // Calculate reference distance
        referenceDistance = calculateDistance(pathPoints[0], pathPoints[1])

        // Update scale factor if reference length is set
        if (referenceLengthInches) {
          scaleFactor = referenceLengthInches / referenceDistance
        }

        referencePointCount++
        currentGroup = null
        pathPoints = []
      }
    } else {
      // Measurement path
      if (pathPoints.length === 0) {
        // Start new measurement path
        pathPoints = [point]
        const circle = createCircle(point.x, point.y, 'blue')
        canvas.add(circle)
        currentGroup = new Group([circle], {
          selectable: false,
          evented: false
        })
        canvas.add(currentGroup)
        totalDistance = 0
        currentMeasurement = null
      } else {
        // Add point to current path
        pathPoints.push(point)
        const circle = createCircle(point.x, point.y, 'blue')
        const line = createLine([
          pathPoints[pathPoints.length - 2].x,
          pathPoints[pathPoints.length - 2].y,
          point.x,
          point.y
        ], 'blue')

        canvas.add(circle)
        canvas.add(line)

        // Calculate and display measurement if we have a scale factor
        if (scaleFactor) {
          currentMeasurement = calculateTotalMeasurement()
        }

        if (currentGroup) {
          const objects = currentGroup.getObjects()
          currentGroup.remove(...objects)
          currentGroup.add(circle, line, ...objects)
          canvas.requestRenderAll()
        }
      }
    }
  }

  function clearPaths() {
    const bgImage = canvas.backgroundImage
    canvas.clear()
    if (bgImage) {
      canvas.backgroundImage = bgImage
      canvas.requestRenderAll()
    }
    currentGroup = null
    pathPoints = []
    referencePointCount = 0
    referenceLengthInches = null
    referenceDistance = null
    scaleFactor = null
    currentMeasurement = null
    totalDistance = 0
    currentPathType = 'reference'
  }

  function switchPathType() {
    currentPathType = currentPathType === 'reference' ? 'measurement' : 'reference'
    if (currentGroup) {
      pathPoints = []
      currentGroup = null
      currentMeasurement = null
      totalDistance = 0
    }
  }

  $: if (referenceLengthInches && referenceDistance) {
    scaleFactor = referenceLengthInches / referenceDistance
    if (currentPathType !== 'measurement') {
      switchPathType()
    }

    if (pathPoints.length > 1) {
      currentMeasurement = calculateTotalMeasurement()
    }
  }
</script>

<div class="flex flex-col md:flex-row md:justify-between gap-4 items-center">
  <input
    bind:this={fileInput}
    type="file"
    class="file-input file-input-bordered file-input-primary w-full max-w-xs"
    accept="image/*"
    on:change={handleFileSelect}
    aria-label="Choose image file"
  />

  <div class="flex gap-2">
    <button class="btn btn-primary" disabled>
      Mode: {currentPathType}
    </button>
    <button class="btn btn-secondary" on:click={clearPaths}>Reset</button>
  </div>
</div>

<div class="card bg-base-200 shadow mt-4">
  <div class="card-body p-6">
    <div class="stats bg-base-100 shadow-sm w-full">

      <!-- Length readout -->
      <div class="stat">
        <div class="stat-title text-base-content/70">Total Length</div>
        {#if currentMeasurement}
          <div class="stat-value text-primary">{currentMeasurement}<span class="text-lg ml-1">inches</span></div>
        {:else}
          <div class="stat-desc text-base max-w-[200px]">
            {#if referenceLengthInches && referenceDistance}
              Add points in measurement mode
            {:else if referenceLengthInches}
              Add reference points
            {:else}
              Set the reference length
            {/if}
          </div>
        {/if}
      </div>
      
      <!-- Reference length -->
      <div class="stat">
        <div class="stat-title text-base-content/70">Reference Length</div>
          <div class="stat-value p-0">
            <input
              id="reference-length"
              type="number"
              min="0"
              step="0.125"
              bind:value={referenceLengthInches}
              placeholder="Enter length"
              class="input input-bordered w-32 h-10"
            />
            <span class="text-lg ml-1">inches</span>
          </div>
      </div>

    </div>
  </div>
</div>



<div class="w-full my-4 border border-gray-300" bind:this={canvasContainer}>
  <canvas id="canvas"></canvas>
</div>
