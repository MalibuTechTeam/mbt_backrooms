import { useEffect, useState } from 'react'

/**
 * Show until `ms` elapses, then return false so the component can `return null`.
 * Re-arms on a fresh mount (parent remounts these via a changing `key`) or when
 * `ms` changes. Shared by the one-shot overlays (blink, log caption).
 */
export function useSelfUnmount(ms: number): boolean {
  const [show, setShow] = useState(true)
  useEffect(() => {
    const t = setTimeout(() => setShow(false), ms)
    return () => clearTimeout(t)
  }, [ms])
  return show
}
