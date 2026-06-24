import { useEffect, useState } from 'react'
import { useNuiEvent } from './utils/useNuiEvent'
import { debugData } from './utils/debugData'
import GloomOverlay from './components/GloomOverlay'
import VhsOverlay from './components/VhsOverlay'
import EntryGlitch from './components/EntryGlitch'
import SanityVignette from './components/SanityVignette'
import StrainVignette from './components/StrainVignette'
import BlinkOverlay from './components/BlinkOverlay'
import ExitWarp from './components/ExitWarp'
import LogCaption from './components/LogCaption'
import InteractPrompt from './components/InteractPrompt'
import { atmosphereAudio } from './audio/atmosphereAudio'

// Persistent atmosphere state pushed by the Lua atmosphere controller.
interface AtmoState {
  active: boolean
  intensity?: number // NUI visual intensity 0..1
  vhs?: boolean
  grain?: boolean
  reduceMotion?: boolean
  gloom?: number // 0..1 screen darkness
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
  const [strain, setStrain] = useState(0)
  const [exitTell, setExitTell] = useState(0)
  const [exitPull, setExitPull] = useState(0)
  const [blinkKey, setBlinkKey] = useState(0)
  const [blinkMs, setBlinkMs] = useState(220)
  const [log, setLog] = useState<{ text: string; kind?: string } | null>(null)
  const [logKey, setLogKey] = useState(0)
  const [prompt, setPrompt] = useState<PromptData | null>(null)

  useNuiEvent<AtmoState>('atmosphere:state', (d) => setAtmo(d ?? { active: false }))

  useNuiEvent<PromptData>('prompt:set', (d) => {
    setPrompt(d && d.visible ? d : null)
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

  // Don't-Blink: focus-drain tunnel vision + the forced blink black-out.
  useNuiEvent<{ level?: number }>('entity:strain', (d) => setStrain(d?.level ?? 0))
  useNuiEvent<{ durationMs?: number }>('entity:blink', (d) => {
    setBlinkMs(d?.durationMs ?? 220)
    setBlinkKey((k) => k + 1)
  })

  // Curated exits: ambient proximity tell + soft pull-in warp.
  useNuiEvent<{ tell?: number; pull?: number }>('exit:warp', (d) => {
    setExitTell(d?.tell ?? 0)
    setExitPull(d?.pull ?? 0)
  })

  // Found tapes/logs: flash the recovered lore as a found-footage caption.
  useNuiEvent<{ text?: string; kind?: string }>('log:show', (d) => {
    if (!d?.text) return
    setLog({ text: d.text, kind: d.kind })
    setLogKey((k) => k + 1)
  })

  useNuiEvent('atmosphere:stopAll', () => {
    setAtmo({ active: false })
    setDread(0)
    setStrain(0)
    setExitTell(0)
    setExitPull(0)
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
      {atmo.active && (atmo.gloom ?? 0) > 0 && <GloomOverlay level={atmo.gloom!} />}
      {atmo.active && atmo.vhs && <VhsOverlay intensity={atmo.intensity ?? 1} grain={!!atmo.grain} reduceMotion={!!atmo.reduceMotion} />}
      {dread > 0 && <SanityVignette dread={dread} />}
      {strain > 0 && <StrainVignette level={strain} />}
      {(exitTell > 0 || exitPull > 0) && <ExitWarp tell={exitTell} pull={exitPull} />}
      <InteractPrompt visible={!!prompt} keyGlyph={prompt?.key ?? 'E'} label={prompt?.label ?? ''} type={prompt?.type ?? 'enter'} reduceMotion={prompt?.reduceMotion} dread={dread} />
      {glitchKey > 0 && <EntryGlitch key={glitchKey} intensity={glitchIntensity} />}
      {blinkKey > 0 && <BlinkOverlay key={blinkKey} durationMs={blinkMs} reduceMotion={atmo.reduceMotion} />}
      {logKey > 0 && log && <LogCaption key={logKey} text={log.text} kind={log.kind} reduceMotion={atmo.reduceMotion} />}
    </>
  )
}
