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

<div class="controls">
  <div class="control-row">
    <input
      bind:this={fileInput}
      type="file"
      accept="image/*"
      on:change={handleFileSelect}
      aria-label="Choose image file"
    />
  </div>

  <div class="control-row">
    <button disabled>
      Mode: {currentPathType}
    </button>
    <button on:click={clearPaths}>Reset</button>
  </div>

  <div class="control-row">
    <label for="reference-length">Reference Length (inches):</label>
    <input
      id="reference-length"
      type="number"
      min="0"
      step="0.125"
      bind:value={referenceLengthInches}
      placeholder="Enter length"
    />
  </div>

  <div class="control-row">
    <strong>Total length:</strong>
    {#if currentMeasurement}
      {currentMeasurement} inches
    {:else}
      <em>
        {#if referenceLengthInches && referenceDistance}
          Add points in measurement mode
        {:else if referenceLengthInches}
          Add reference points
        {:else}
          Set the reference length
        {/if}
      </em>
    {/if}
  </div>
</div>

<div class="canvas-container" bind:this={canvasContainer}>
  <canvas id="canvas"></canvas>
</div>

<style>
  .canvas-container {
    width: 100%;
    margin: 1rem 0;
    border: 1px solid #ccc;
  }
  .controls {
    margin-bottom: 1rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  .control-row {
    display: flex;
    gap: 0.5rem;
    align-items: center;
  }
  button {
    padding-left: 1rem;
    padding-right: 1rem;
  }
</style>

