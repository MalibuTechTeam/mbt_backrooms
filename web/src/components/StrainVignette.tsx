import './StrainVignette.css'

interface Props {
  level: number // 0..1 eye-strain intensity (Don't-Blink focus drain)
}

/**
 * Tunnel-vision that closes inward as Don't-Blink focus drains while you stare.
 * Diegetic focus feedback — NOT a meter/bar. Pure CSS radial mask scaled by
 * --strain; distinct from the (yellow, looser) sanity vignette.
 */
export default function StrainVignette({ level }: Props) {
  return <div className="strain" style={{ ['--strain' as string]: String(level) }} />
}
