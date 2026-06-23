import { useEffect, useState } from 'react'
import './InteractPrompt.css'

interface Props {
  keyGlyph: string
  label: string
  type: string // 'enter' | 'leave'
  reduceMotion?: boolean
  dread?: number // 0..1 sanity-loss; high = unstable presentation
}

// Single-beat corruption: replace one inner char with '_' or drop it. ASCII-safe.
function corrupt(s: string): string {
  if (s.length < 4) return s
  const i = 1 + Math.floor(Math.random() * (s.length - 2))
  return Math.random() < 0.5 ? s.slice(0, i) + '_' + s.slice(i + 1) : s.slice(0, i) + s.slice(i + 1)
}

/**
 * Found-footage interaction prompt (VHS caption). Pure component: NO side
 * effects in render (randomness/corruption lives in an effect) so React's
 * reconciliation — including unmount when the parent hides it — is reliable.
 */
export default function InteractPrompt({ keyGlyph, label, type, reduceMotion, dread = 0 }: Props) {
  const base = `[${keyGlyph}] ${label}`
  const [display, setDisplay] = useState(base)

  useEffect(() => {
    if (reduceMotion || Math.random() >= 0.18) {
      setDisplay(base)
      return
    }
    setDisplay(`[${keyGlyph}] ${corrupt(label)}`)
    const t = setTimeout(() => setDisplay(base), 110)
    return () => clearTimeout(t)
  }, [base, keyGlyph, label, reduceMotion])

  const unstable = !reduceMotion && dread >= 0.4
  const cls = ['iprompt',
    type === 'leave' ? 'iprompt--leave' : '',
    reduceMotion ? 'iprompt--rm' : '',
    unstable ? 'iprompt--unstable' : '',
  ].filter(Boolean).join(' ')

  return (
    <div className={cls}>
      <span className="iprompt-text" data-text={display}>{display}</span>
    </div>
  )
}
