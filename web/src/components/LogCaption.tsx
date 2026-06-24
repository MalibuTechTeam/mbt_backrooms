import { useSelfUnmount } from '../utils/useSelfUnmount'
import './LogCaption.css'

const HOLD_MS = 6000 // single source of truth — the CSS fade reads it via --logcap-ms

interface Props {
  text: string
  kind?: string // 'tape' | 'log'
  reduceMotion?: boolean
}

/**
 * Found-footage caption shown when a tape/log is collected — a low-center
 * tracking subtitle that flickers in, holds, then fades. The lore IS the reward
 * (no HUD counter). Self-unmounts after the hold. CEF-cheap (opacity/transform).
 */
export default function LogCaption({ text, kind, reduceMotion }: Props) {
  if (!useSelfUnmount(HOLD_MS)) return null
  return (
    <div
      className={reduceMotion ? 'logcap logcap--rm' : 'logcap'}
      style={{ ['--logcap-ms' as string]: `${HOLD_MS}ms` }}
    >
      <div className="logcap-tag">{kind === 'tape' ? '◉ REC' : '▤ LOG'}</div>
      <div className="logcap-text">{text}</div>
    </div>
  )
}
