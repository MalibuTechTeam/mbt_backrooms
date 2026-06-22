import './VhsOverlay.css'

interface Props {
  intensity: number // 0..1, scales overall opacity
  grain: boolean
}

/**
 * Liminal VHS / no-clip overlay: scanlines + chromatic-ish vignette + optional
 * grain. Pure CSS (cheap in CEF) — no per-frame canvas work. Intensity scales
 * opacity linearly via the --vhs-intensity custom property.
 */
export default function VhsOverlay({ intensity, grain }: Props) {
  return (
    <div className="vhs" style={{ ['--vhs-intensity' as string]: String(intensity) }}>
      <div className="vhs-scanlines" />
      {grain && <div className="vhs-grain" />}
      <div className="vhs-vignette" />
    </div>
  )
}
