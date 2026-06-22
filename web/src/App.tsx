import { useEffect, useState } from 'react'
import { useNuiEvent } from './utils/useNuiEvent'
import { debugData } from './utils/debugData'
import VhsOverlay from './components/VhsOverlay'
import EntryGlitch from './components/EntryGlitch'
import { atmosphereAudio } from './audio/atmosphereAudio'

// Persistent atmosphere state pushed by the Lua atmosphere controller.
interface AtmoState {
  active: boolean
  intensity?: number // NUI visual intensity 0..1
  vhs?: boolean
  grain?: boolean
  hum?: number | false // final volume, or false to disable
  drone?: number | false
}
// One-shot entry transition.
interface EntryData {
  intensity?: number
  sting?: number | false
}

// Browser dev preview: turn the atmosphere on, then fire an entry burst.
debugData<AtmoState>([
  { action: 'atmosphere:state', data: { active: true, intensity: 0.8, vhs: true, grain: true, hum: 0.4, drone: 0.25 } },
])

export default function App() {
  const [atmo, setAtmo] = useState<AtmoState>({ active: false })
  const [glitchKey, setGlitchKey] = useState(0)
  const [glitchIntensity, setGlitchIntensity] = useState(1)

  useNuiEvent<AtmoState>('atmosphere:state', (d) => setAtmo(d ?? { active: false }))

  useNuiEvent<EntryData>('atmosphere:entry', (d) => {
    setGlitchIntensity(d?.intensity ?? 1)
    setGlitchKey((k) => k + 1) // remount EntryGlitch -> replays
    if (d && typeof d.sting === 'number') atmosphereAudio.playEntry(d.sting)
  })

  useNuiEvent('atmosphere:stopAll', () => {
    setAtmo({ active: false })
    atmosphereAudio.stopLoops()
  })

  // Drive looping audio from the persistent state.
  useEffect(() => {
    if (atmo.active) {
      atmosphereAudio.setLoop('hum', atmo.hum)
      atmosphereAudio.setLoop('drone', atmo.drone)
    } else {
      atmosphereAudio.stopLoops()
    }
  }, [atmo])

  return (
    <>
      {atmo.active && atmo.vhs && <VhsOverlay intensity={atmo.intensity ?? 1} grain={!!atmo.grain} />}
      {glitchKey > 0 && <EntryGlitch key={glitchKey} intensity={glitchIntensity} />}
    </>
  )
}
