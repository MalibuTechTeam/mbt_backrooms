import './LevelHud.css'

interface Props {
  torchHint: boolean
  torchOn: boolean
  torchKey: string
  torchLabel: string
  showSanity: boolean
  dread: number // 0..1 (higher = worse); drives the stylized signal, never a number
  reduceMotion?: boolean
}

const SEGMENTS = 5

/**
 * Minimal in-level HUD: a torch-key hint (lit when the torch is on) and an OPT-IN
 * stylized "signal" for sanity — increasing-height bars, fewer lit + more flicker as
 * dread rises. Deliberately non-numeric to keep the diegetic, no-meter tone.
 */
export default function LevelHud({ torchHint, torchOn, torchKey, torchLabel, showSanity, dread, reduceMotion }: Props) {
  const lit = Math.max(0, Math.round((1 - dread) * SEGMENTS))
  return (
    <div className={reduceMotion ? 'lhud lhud--rm' : 'lhud'}>
      {showSanity && (
        <div className="lhud-sig" style={{ ['--dread' as string]: String(dread) }} aria-hidden>
          {Array.from({ length: SEGMENTS }).map((_, i) => (
            <span
              key={i}
              className={i < lit ? 'lhud-bar lhud-bar--on' : 'lhud-bar'}
              style={{ height: `${30 + i * 16}%` }}
            />
          ))}
        </div>
      )}
      {torchHint && (
        <div className={torchOn ? 'lhud-torch lhud-torch--on' : 'lhud-torch'}>
          <span className="lhud-key">{torchKey}</span>
          <span className="lhud-label">{torchLabel}</span>
        </div>
      )}
    </div>
  )
}
