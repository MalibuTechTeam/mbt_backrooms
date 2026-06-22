import { useEffect, useState } from 'react'
import './EntryGlitch.css'

/**
 * One-shot "no-clip / reality tear" burst played on entry. Mounts, runs a ~900ms
 * CSS animation, then removes itself. Re-triggered by bumping its React `key`.
 */
export default function EntryGlitch({ intensity }: { intensity: number }) {
  const [show, setShow] = useState(true)

  useEffect(() => {
    const t = setTimeout(() => setShow(false), 900)
    return () => clearTimeout(t)
  }, [])

  if (!show) return null

  return (
    <div className="entry-glitch" style={{ ['--g' as string]: String(intensity) }}>
      <div className="entry-glitch-static" />
      <div className="entry-glitch-bars" />
    </div>
  )
}
