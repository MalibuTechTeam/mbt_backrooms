import { useEffect } from 'react'
import { fetchNui } from '../utils/fetchNui'
import './Archive.css'

interface Tape {
  id: string
  type?: string // 'tape' | 'log'
  text: string
}
interface Note {
  category: string
  text: string
}
interface Props {
  tapes: Tape[]
  notes?: Note[]
  confidence?: Record<string, number>
  research?: boolean
}

const CAT_LABEL: Record<string, string> = {
  exits: 'Exit Phenomena',
  entity: 'Entity Behavior',
  geometry: 'Level Geometry',
  personnel: 'Lost Personnel',
  contamination: 'Surface Contamination',
}
const CAT_ORDER = ['exits', 'entity', 'geometry', 'personnel', 'contamination']

// Few thresholds, not an XP bar (Codex): Unknown -> Pattern Noted -> Corroborated.
function tier(n: number): string {
  if (n >= 3) return 'Corroborated'
  if (n >= 1) return 'Pattern Noted'
  return 'Unknown'
}

/**
 * Interactive archive panel — the recover-loop payoff. A found-footage CRT list of
 * the tapes/logs carried out of the Backrooms, plus (Research Mode) the diegetic
 * "field notes" unlocked by per-category confidence. Opened with NUI focus by the
 * terminal module; ESC or the close button tells Lua to release focus.
 */
export default function Archive({ tapes, notes = [], confidence = {}, research }: Props) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') fetchNui('archiveClose')
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  const cats = CAT_ORDER.filter((c) => (confidence[c] ?? 0) > 0)

  return (
    <div className="arc">
      <div className="arc-panel">
        <div className="arc-head">
          <span className="arc-title">◉ ASYNC RESEARCH ARCHIVE</span>
          <button className="arc-close" onClick={() => fetchNui('archiveClose')}>✕ ESC</button>
        </div>

        <div className="arc-body">
          <div className="arc-col">
            <div className="arc-section">Recordings</div>
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
          </div>

          {research && (
            <div className="arc-col arc-col--notes">
              <div className="arc-section">Field Notes</div>
              {cats.length > 0 && (
                <div className="arc-conf">
                  {cats.map((c) => (
                    <div key={c} className="arc-conf-row">
                      <span className="arc-conf-cat">{CAT_LABEL[c] ?? c}</span>
                      <span className="arc-conf-tier">{tier(confidence[c] ?? 0)}</span>
                    </div>
                  ))}
                </div>
              )}
              {notes.length === 0 ? (
                <div className="arc-empty arc-empty--sm">Patterns emerge as you recover more evidence.</div>
              ) : (
                <ul className="arc-notes">
                  {notes.map((n, i) => (
                    <li key={i} className="arc-note">
                      <span className="arc-note-cat">{(CAT_LABEL[n.category] ?? n.category).toUpperCase()}</span>
                      <span className="arc-note-text">{n.text}</span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          )}
        </div>

        <div className="arc-foot">
          {tapes.length} recovered
          {research && cats.length > 0 ? ` · ${cats.length} categor${cats.length === 1 ? 'y' : 'ies'} active` : ''}
        </div>
      </div>
    </div>
  )
}
