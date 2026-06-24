import { useEffect } from 'react'
import { fetchNui } from '../utils/fetchNui'
import './Archive.css'

interface Tape {
  id: string
  type?: string // 'tape' | 'log'
  text: string
}

/**
 * Interactive archive panel (the recover-loop payoff): a found-footage CRT list
 * of the tapes/logs the player has carried out of the Backrooms. Opened with NUI
 * focus by the terminal module; ESC or the close button tells Lua to release focus.
 */
export default function Archive({ tapes }: { tapes: Tape[] }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') fetchNui('archiveClose')
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  return (
    <div className="arc">
      <div className="arc-panel">
        <div className="arc-head">
          <span className="arc-title">◉ ARCHIVE — recovered footage</span>
          <button className="arc-close" onClick={() => fetchNui('archiveClose')}>✕ ESC</button>
        </div>
        {tapes.length === 0 ? (
          <div className="arc-empty">No recordings recovered yet.<br />Carry tapes out of the Backrooms.</div>
        ) : (
          <ul className="arc-list">
            {tapes.map((t) => (
              <li key={t.id} className="arc-item">
                <span className={`arc-tag ${t.type === 'tape' ? 'arc-tag--tape' : 'arc-tag--log'}`}>
                  {t.type === 'tape' ? 'REC' : 'LOG'}
                </span>
                <span className="arc-text">{t.text}</span>
              </li>
            ))}
          </ul>
        )}
        <div className="arc-foot">{tapes.length} recovered</div>
      </div>
    </div>
  )
}
