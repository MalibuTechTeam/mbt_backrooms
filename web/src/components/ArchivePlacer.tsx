import { useState } from 'react'
import { fetchNui } from '../utils/fetchNui'
import './ArchivePlacer.css'

const STEPS = [0.05, 0.1, 0.5]

/**
 * Archive terminal placement popup (admin). Nudges the live prop as a preview;
 * Save persists it (server KVP), Close reverts. Mirrors the elevator placement UX
 * but focused on a single terminal.
 */
export default function ArchivePlacer() {
  const [step, setStep] = useState(0.1)
  const [scrStep, setScrStep] = useState(0.01)
  const [previewOn, setPreviewOn] = useState(false)
  const move = (dx: number, dy: number, dz: number) =>
    fetchNui('archiveNudge', { dx: dx * step, dy: dy * step, dz: dz * step, dh: 0 })
  const rot = (dh: number) => fetchNui('archiveNudge', { dx: 0, dy: 0, dz: 0, dh })
  const cam = (p: object) => fetchNui('archiveCamNudge', p)
  const scr = (p: { dX?: number; dZ?: number; dW?: number; dH?: number }) =>
    fetchNui('archiveScreenNudge', {
      dX: (p.dX ?? 0) * scrStep,
      dZ: (p.dZ ?? 0) * scrStep,
      dW: (p.dW ?? 0) * scrStep,
      dH: (p.dH ?? 0) * scrStep,
    })

  return (
    <div className="aplc">
      <div className="aplc-panel">
        <div className="aplc-h">◉ ARCHIVE TERMINAL — placement</div>

        <button className="aplc-wide" onClick={() => fetchNui('archivePlaceHere')}>
          Place at my position
        </button>

        <div className="aplc-row">
          <span className="aplc-lbl">step</span>
          {STEPS.map((s) => (
            <button key={s} className={step === s ? 'aplc-step on' : 'aplc-step'} onClick={() => setStep(s)}>
              {s}m
            </button>
          ))}
        </div>

        <div className="aplc-grid">
          <button onClick={() => move(0, 1, 0)}>N ↑</button>
          <button onClick={() => move(0, -1, 0)}>S ↓</button>
          <button onClick={() => move(1, 0, 0)}>E →</button>
          <button onClick={() => move(-1, 0, 0)}>W ←</button>
          <button onClick={() => move(0, 0, 1)}>Up</button>
          <button onClick={() => move(0, 0, -1)}>Down</button>
          <button onClick={() => rot(-5)}>Rotate ↺</button>
          <button onClick={() => rot(5)}>Rotate ↻</button>
        </div>
        <button className="aplc-wide" onClick={() => fetchNui('archiveDropGround')}>Drop to ground</button>

        <button
          className={previewOn ? 'aplc-wide aplc-toggle on' : 'aplc-wide aplc-toggle'}
          onClick={() => {
            fetchNui('archiveCamPreview')
            setPreviewOn((v) => !v)
          }}
        >
          {previewOn ? '● camera preview: ON' : '○ camera preview: OFF'}
        </button>
        <div className="aplc-grid">
          <button onClick={() => cam({ dDist: -0.1 })}>Closer</button>
          <button onClick={() => cam({ dDist: 0.1 })}>Farther</button>
          <button onClick={() => cam({ dHeight: 0.1 })}>Cam up</button>
          <button onClick={() => cam({ dHeight: -0.1 })}>Cam down</button>
          <button onClick={() => cam({ dAim: 0.1 })}>Aim up</button>
          <button onClick={() => cam({ dAim: -0.1 })}>Aim down</button>
          <button onClick={() => cam({ dFov: -2 })}>Zoom in</button>
          <button onClick={() => cam({ dFov: 2 })}>Zoom out</button>
          <button className="aplc-wide" onClick={() => cam({ flipSide: true })}>Flip side (front/back)</button>
        </div>

        <div className="aplc-sec">screen rect (align the UI to the screen)</div>
        <div className="aplc-row">
          <span className="aplc-lbl">step</span>
          {[0.005, 0.01, 0.02, 0.05].map((s) => (
            <button key={s} className={scrStep === s ? 'aplc-step on' : 'aplc-step'} onClick={() => setScrStep(s)}>
              {s}
            </button>
          ))}
        </div>
        <div className="aplc-grid">
          <button onClick={() => scr({ dZ: 1 })}>UI up</button>
          <button onClick={() => scr({ dZ: -1 })}>UI down</button>
          <button onClick={() => scr({ dX: -1 })}>UI left</button>
          <button onClick={() => scr({ dX: 1 })}>UI right</button>
          <button onClick={() => scr({ dW: 1 })}>Wider</button>
          <button onClick={() => scr({ dW: -1 })}>Narrower</button>
          <button onClick={() => scr({ dH: 1 })}>Taller</button>
          <button onClick={() => scr({ dH: -1 })}>Shorter</button>
        </div>

        <div className="aplc-actions">
          <button className="aplc-save" onClick={() => fetchNui('archiveSave')}>Save</button>
          <button className="aplc-remove" onClick={() => fetchNui('archiveRemove')}>Remove</button>
          <button onClick={() => fetchNui('archivePlacerClose')}>Close</button>
        </div>
      </div>
    </div>
  )
}
