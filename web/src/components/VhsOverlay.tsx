import './VhsOverlay.css'

interface Props {
  intensity: number // 0..1, scales overall opacity
  grain: boolean
  reduceMotion?: boolean
}

/**
 * Liminal VHS / no-clip overlay: a degraded-tape look — scanlines + yellow vignette
 * + optional grain, plus a subtle static chroma bleed and an INTERMITTENT tracking
 * band (film-faithful "recovered tape", no camcorder HUD/REC/timestamp). Pure CSS
 * (no per-frame canvas, no blend-mode compositing) to stay cheap in CEF. Intensity
 * scales opacity via --vhs-intensity; reduceMotion stops the moving layers.
 */
export default function VhsOverlay({ intensity, grain, reduceMotion }: Props) {
  return (
    <div
      className={reduceMotion ? 'vhs vhs--rm' : 'vhs'}
      style={{ ['--vhs-intensity' as string]: String(intensity) }}
    >
      <div className="vhs-chroma" />
      <div className="vhs-scanlines" />
      {grain && <div className="vhs-grain" />}
      <div className="vhs-tracking" />
      <div className="vhs-vignette" />
    </div>
  )
}
