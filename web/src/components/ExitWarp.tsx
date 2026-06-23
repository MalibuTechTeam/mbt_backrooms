import './ExitWarp.css'

interface Props {
  tell: number // 0..1 ambient proximity to an active exit ("something's near")
  pull: number // 0..1 soft pull-in progress while standing in the exit
}

/**
 * Curated-exit feedback — diegetic, no marker/text. `tell` breathes a faint edge
 * glow that intensifies as you near an active exit; `pull` builds a tightening
 * warp as the soft pull-in completes. CEF-cheap (gradients + opacity + scale).
 */
export default function ExitWarp({ tell, pull }: Props) {
  return (
    <div
      className="exitwarp"
      style={{ ['--tell' as string]: String(tell), ['--pull' as string]: String(pull) }}
    >
      <div className="exitwarp-tell" />
      <div className="exitwarp-pull" />
    </div>
  )
}
