import './GloomOverlay.css'

interface Props {
  level: number // 0..1 darkness (MBT.Atmosphere.Darkness.Strength)
}

/**
 * Config-driven gloom: a predictable screen dim so the level feels dark enough
 * that the torch matters. Linear in `level` (unlike the binary blackout timecycle
 * modifiers). The torch is a world light, so its lit cone still reads on top.
 */
export default function GloomOverlay({ level }: Props) {
  return <div className="gloom" style={{ ['--gloom' as string]: String(level) }} />
}
