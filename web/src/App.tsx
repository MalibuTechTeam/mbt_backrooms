import { useEffect, useState } from 'react'
import { useNuiEvent } from './utils/useNuiEvent'
import { debugData } from './utils/debugData'
import VhsOverlay from './components/VhsOverlay'
import EntryGlitch from './components/EntryGlitch'
import SanityVignette from './components/SanityVignette'
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

// Browser dev preview: atmosphere on + a low-sanity vignette.
debugData<AtmoState>([
  { action: 'atmosphere:state', data: { active: true, intensity: 0.8, vhs: true, grain: true, hum: 0.4, drone: 0.25 } },
])
debugData<{ dread: number }>([{ action: 'sanity:set', data: { dread: 0.7 } }])

export default function App() {
  const [atmo, setAtmo] = useState<AtmoState>({ active: false })
  const [glitchKey, setGlitchKey] = useState(0)
  const [glitchIntensity, setGlitchIntensity] = useState(1)
  const [dread, setDread] = useState(0)

  useNuiEvent<AtmoState>('atmosphere:state', (d) => setAtmo(d ?? { active: false }))

  useNuiEvent<EntryData>('atmosphere:entry', (d) => {
    setGlitchIntensity(d?.intensity ?? 1)
    setGlitchKey((k) => k + 1) // remount EntryGlitch -> replays
    if (d && typeof d.sting === 'number') atmosphereAudio.playEntry(d.sting)
  })

  useNuiEvent<{ dread?: number }>('sanity:set', (d) => setDread(d?.dread ?? 0))

  useNuiEvent('atmosphere:stopAll', () => {
    setAtmo({ active: false })
    setDread(0)
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
      {dread > 0 && <SanityVignette dread={dread} />}
      {glitchKey > 0 && <EntryGlitch key={glitchKey} intensity={glitchIntensity} />}
    </>
  )
}
