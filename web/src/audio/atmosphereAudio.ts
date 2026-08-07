// Atmosphere audio manager (HTML5 Audio). Hum/drone loop continuously while
// inside a level (fade in/out); entry is a one-shot transition sting. Volumes
// are final values computed Lua-side (per-effect volume * Audio intensity).

type LoopName = 'hum' | 'drone'

const SRC: Record<string, string> = {
  hum: 'sounds/hum.ogg',
  drone: 'sounds/drone.ogg',
  entry: 'sounds/entry.ogg',
}

const clamp = (v: number) => Math.max(0, Math.min(1, v))

class AtmosphereAudio {
  private loops: Partial<Record<LoopName, HTMLAudioElement>> = {}
  private timers: Partial<Record<LoopName, number>> = {}
  private ducked: Partial<Record<LoopName, number>> = {}

  /** Start the loop at `volume`, or stop it when volume is false/undefined. */
  setLoop(name: LoopName, volume: number | false | undefined) {
    if (typeof volume === 'number') this.start(name, volume)
    else this.stop(name)
  }

  private start(name: LoopName, volume: number) {
    let a = this.loops[name]
    if (!a) {
      a = new Audio(SRC[name])
      a.loop = true
      a.volume = 0
      this.loops[name] = a
      a.play().catch(() => {})
    }
    this.fade(name, volume, 1800)
  }

  private stop(name: LoopName) {
    const a = this.loops[name]
    if (!a) return
    this.fade(name, 0, 900, () => {
      a.pause()
      a.currentTime = 0
      delete this.loops[name]
    })
  }

  stopLoops() {
    ;(['hum', 'drone'] as LoopName[]).forEach((n) => this.stop(n))
  }

  /** Dynamic Silence: fade the ambient loops to silence, remembering their volumes. */
  duck(ms = 700) {
    ;(['hum', 'drone'] as LoopName[]).forEach((n) => {
      const a = this.loops[n]
      if (a && this.ducked[n] === undefined) {
        this.ducked[n] = a.volume
        this.fade(n, 0, ms)
      }
    })
  }

  /** Restore the ambient loops to their pre-duck volumes. */
  unduck(ms = 1400) {
    ;(['hum', 'drone'] as LoopName[]).forEach((n) => {
      const v = this.ducked[n]
      if (v !== undefined) {
        delete this.ducked[n]
        this.fade(n, v, ms)
      }
    })
  }

  playEntry(volume: number) {
    this.playOneShot('entry', volume)
  }

  /** Fire-and-forget one-shot from sounds/<file>.ogg. Releases the element on end. */
  playOneShot(file: string, volume: number) {
    const a = new Audio(`sounds/${file}.ogg`)
    a.volume = clamp(volume)
    a.addEventListener('ended', () => { a.src = '' })
    a.play().catch(() => {})
  }

  private fade(name: LoopName, target: number, ms: number, done?: () => void) {
    const a = this.loops[name]
    if (!a) return
    if (this.timers[name]) clearInterval(this.timers[name])

    const steps = Math.max(1, Math.round(ms / 50))
    const start = a.volume
    const delta = (clamp(target) - start) / steps
    let i = 0

    this.timers[name] = window.setInterval(() => {
      i++
      a.volume = clamp(start + delta * i)
      if (i >= steps) {
        clearInterval(this.timers[name])
        delete this.timers[name]
        if (done) done()
      }
    }, 50)
  }
}

export const atmosphereAudio = new AtmosphereAudio()
