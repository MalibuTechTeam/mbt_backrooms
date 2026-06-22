import './SanityVignette.css'

/**
 * Sanity vignette: darkness closes in from the edges as `dread` (0..1) rises.
 * A slow pulse kicks in when sanity is critical. Pure CSS gradient (cheap).
 */
export default function SanityVignette({ dread }: { dread: number }) {
  const crit = dread >= 0.6
  return (
    <div
      className={`sanity-vignette${crit ? ' crit' : ''}`}
      style={{ ['--d' as string]: String(dread) }}
    />
  )
}
