import { useState } from 'react'
import { useNuiEvent } from './utils/useNuiEvent'
import { debugData } from './utils/debugData'
import VhsOverlay from './components/VhsOverlay'

// Atmosphere state pushed from the Lua atmosphere controller (F3).
// The NUI overlay is PASSIVE — it never takes input focus.
interface AtmosphereLayers {
  vhs?: boolean
  grain?: boolean
}
interface AtmosphereState {
  active: boolean
  intensity?: number // 0..1
  layers?: AtmosphereLayers
}

// Browser dev preview: simulate the atmosphere turning on after 1s.
debugData<AtmosphereState>([
  { action: 'atmosphere:state', data: { active: true, intensity: 0.8, layers: { vhs: true, grain: true } } },
])

export default function App() {
  const [atmo, setAtmo] = useState<AtmosphereState>({ active: false })

  useNuiEvent<AtmosphereState>('atmosphere:state', (data) => setAtmo(data ?? { active: false }))
  useNuiEvent('atmosphere:stopAll', () => setAtmo({ active: false }))

  if (!atmo.active) return null

  const intensity = atmo.intensity ?? 1
  const layers = atmo.layers ?? {}

  return (
    <div className="atmosphere-root">
      {layers.vhs && <VhsOverlay intensity={intensity} grain={!!layers.grain} />}
    </div>
  )
}
