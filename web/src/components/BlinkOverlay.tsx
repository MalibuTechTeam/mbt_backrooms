import { useSelfUnmount } from '../utils/useSelfUnmount'
import './BlinkOverlay.css'

interface Props {
  durationMs: number
  reduceMotion?: boolean
}

/**
 * A forced "blink": eyelids snap shut then open. The black-out hides the
 * entity's lunge so it just "appears closer" when vision returns. Self-unmounts
 * after durationMs. Cheap in CEF — opacity only, no filters/blend.
 */
export default function BlinkOverlay({ durationMs, reduceMotion }: Props) {
  if (!useSelfUnmount(durationMs)) return null
  return (
    <div
      className={reduceMotion ? 'blink blink--rm' : 'blink'}
      style={{ ['--blink-ms' as string]: `${durationMs}ms` }}
    />
  )
}
