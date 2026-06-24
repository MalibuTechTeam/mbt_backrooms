import { useEffect, useState } from 'react'
import './LogCaption.css'

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
  const [show, setShow] = useState(true)
  useEffect(() => {
    const t = setTimeout(() => setShow(false), 6000)
    return () => clearTimeout(t)
  }, [text])
  if (!show) return null
  return (
    <div className={reduceMotion ? 'logcap logcap--rm' : 'logcap'}>
      <div className="logcap-tag">{kind === 'tape' ? '◉ REC' : '▤ LOG'}</div>
      <div className="logcap-text">{text}</div>
    </div>
  )
}
