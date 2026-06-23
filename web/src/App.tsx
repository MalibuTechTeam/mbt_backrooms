import { useEffect, useState } from 'react'
import { useNuiEvent } from './utils/useNuiEvent'
import { debugData } from './utils/debugData'
import VhsOverlay from './components/VhsOverlay'
import EntryGlitch from './components/EntryGlitch'
import SanityVignette from './components/SanityVignette'
import InteractPrompt from './components/InteractPrompt'
import { atmosphereAudio } from './audio/atmosphereAudio'

// Persistent atmosphere state pushed by the Lua atmosphere controller.
interface AtmoState {
  active: boolean
  intensity?: number // NUI visual intensity 0..1
  vhs?: boolean
  grain?: boolean
  reduceMotion?: boolean
  hum?: number | false // final volume, or false to disable
  drone?: number | false
}
// One-shot entry transition.
interface EntryData {
  intensity?: number
  sting?: number | false
}
interface PromptData {
  visible: boolean
  key: string
  label: string
  type: string
  reduceMotion?: boolean
}

// Browser dev preview: atmosphere on + a low-sanity vignette.
debugData<AtmoState>([
  { action: 'atmosphere:state', data: { active: true, intensity: 0.8, vhs: true, grain: true, hum: 0.4, drone: 0.25 } },
])
debugData<{ dread: number }>([{ action: 'sanity:set', data: { dread: 0.7 } }])
debugData<PromptData>([{ action: 'prompt:set', data: { visible: true, key: 'E', label: 'through', type: 'enter' } }])

export default function App() {
  const [atmo, setAtmo] = useState<AtmoState>({ active: false })
  const [glitchKey, setGlitchKey] = useState(0)
  const [glitchIntensity, setGlitchIntensity] = useState(1)
  const [dread, setDread] = useState(0)
  const [prompt, setPrompt] = useState<PromptData | null>(null)
  const [promptKey, setPromptKey] = useState(0)

  useNuiEvent<AtmoState>('atmosphere:state', (d) => setAtmo(d ?? { active: false }))

  useNuiEvent<PromptData>('prompt:set', (d) => {
    if (d && d.visible) {
      setPrompt(d)
      setPromptKey((k) => k + 1) // remount -> replay the resolve animation
    } else {
      setPrompt(null)
    }
  })

  useNuiEvent<EntryData>('atmosphere:entry', (d) => {
    setGlitchIntensity(d?.intensity ?? 1)
    setGlitchKey((k) => k + 1) // remount EntryGlitch -> replays
    if (d && typeof d.sting === 'number') atmosphereAudio.playEntry(d.sting)
  })

  useNuiEvent<{ dread?: number }>('sanity:set', (d) => setDread(d?.dread ?? 0))

  useNuiEvent<{ file?: string; volume?: number }>('entity:sound', (d) =>
    atmosphereAudio.playOneShot(d?.file || 'entry', d?.volume ?? 0.7),
  )

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
      {atmo.active && atmo.vhs && <VhsOverlay intensity={atmo.intensity ?? 1} grain={!!atmo.grain} reduceMotion={!!atmo.reduceMotion} />}
      {dread > 0 && <SanityVignette dread={dread} />}
      {prompt && <InteractPrompt key={promptKey} keyGlyph={prompt.key} label={prompt.label} type={prompt.type} reduceMotion={prompt.reduceMotion} dread={dread} />}
      {glitchKey > 0 && <EntryGlitch key={glitchKey} intensity={glitchIntensity} />}
    </>
  )
}
