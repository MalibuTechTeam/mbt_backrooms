import './VhsOverlay.css'

interface Props {
  intensity: number // 0..1, scales overall opacity
  grain: boolean
  reduceMotion?: boolean
}

/**
 * Liminal VHS / no-clip overlay: scanlines + yellow vignette + optional grain.
 * Pure CSS (no per-frame canvas, no blend-mode compositing). Intensity scales
 * opacity via --vhs-intensity; reduceMotion stops the grain jitter.
 */
export default function VhsOverlay({ intensity, grain, reduceMotion }: Props) {
  return (
    <div
      className={reduceMotion ? 'vhs vhs--rm' : 'vhs'}
      style={{ ['--vhs-intensity' as string]: String(intensity) }}
    >
      <div className="vhs-scanlines" />
      {grain && <div className="vhs-grain" />}
      <div className="vhs-vignette" />
    </div>
  )
}
