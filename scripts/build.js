import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from 'fs'
import { join, resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import JSZip from 'jszip'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '..')

const outArg   = process.argv.find(a => a.startsWith('--out='))
const outDir   = outArg ? resolve(outArg.slice(6)) : join(ROOT, 'dist')
mkdirSync(outDir, { recursive: true })

// Optional filters — used by the CI to build only what changed.
// --game=kh1           build only KH1 patches
// --type=Classic       build only the Classic (or Remastered / Switcher) patch
const gameFilter = new Set(
  process.argv.filter(a => a.startsWith('--game=')).flatMap(a => a.slice(7).split(','))
)
const typeFilter = new Set(
  process.argv.filter(a => a.startsWith('--type=')).flatMap(a => a.slice(7).split(','))
)

// KH1: paths use "amusic" as the mod prefix segment.
// Switcher replaces it with "amusi2" (Classic) or "amusi3" (Remastered).
// KH2: paths use "bgm" or "vagstream" as the mod prefix segment.
// Switcher replaces them with "bg2"/"bg3" and "vagstrea2"/"vagstrea3".

const GAMES = {
  kh1: {
    json: join(ROOT, 'kh1.json'),
    tracksDir: join(ROOT, 'kh1', 'tracks'),
    rawDir: join(ROOT, 'kh1', 'raw'),
    luaFile: join(ROOT, 'kh1soundtrack.lua'),
    luaScriptPath: 'special/scripts/kh1soundtrack.lua',
    ext: 'kh1pcpatch',
    switcherPath(normalizedDest, version) {
      const suffix = version === 'Classic' ? '2' : '3'
      // Segment /amusic/ appears in the middle of every KH1 path.
      return normalizedDest.replace('/amusic/', `/amusi${suffix}/`)
    },
  },
  kh2: {
    json: join(ROOT, 'kh2.json'),
    tracksDir: join(ROOT, 'kh2', 'tracks'),
    luaFile: join(ROOT, 'kh2soundtrack.lua'),
    luaScriptPath: 'special/scripts/kh2soundtrack.lua',
    ext: 'kh2pcpatch',
    switcherPath(normalizedDest, version) {
      const suffix = version === 'Classic' ? '2' : '3'
      // Paths end with /bgm or /vagstream (trailing slash stripped by normalizeDest).
      return normalizedDest
        .replace('/bgm', `/bg${suffix}`)
        .replace('/vagstream', `/vagstrea${suffix}`)
    },
  },
}

function normalizeDest(dest) {
  if (!dest || dest === '""') return null
  return dest.replace(/\\/g, '/').replace(/\/+$/, '')
}

function readTrack(tracksDir, version, file) {
  const p = join(tracksDir, version, file)
  if (!existsSync(p)) {
    console.warn(`  [WARN] Missing: ${p}`)
    return null
  }
  return readFileSync(p)
}

async function buildVersionPatch(rows, tracksDir, version) {
  const zip = new JSZip()

  for (const row of rows) {
    if (row.Changed !== 'Y') continue
    const data = readTrack(tracksDir, version, row.File)
    if (!data) continue

    for (const key of ['First Destination', 'Second Destination']) {
      const dest = normalizeDest(row[key])
      if (dest) zip.file(`${dest}/${row.File}`, data)
    }
  }

  return zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE', compressionOptions: { level: 6 } })
}

async function buildSwitcherPatch(rows, game) {
  const zip = new JSZip()

  // Bundle the Lua script so OpenKH Mods Manager installs it automatically.
  if (existsSync(game.luaFile)) {
    zip.file(game.luaScriptPath, readFileSync(game.luaFile))
  } else {
    console.warn(`  [WARN] Missing Lua script: ${game.luaFile}`)
  }

  for (const row of rows) {
    if (row.Changed !== 'Y') continue

    for (const version of ['Classic', 'Remastered']) {
      const data = readTrack(game.tracksDir, version, row.File)
      if (!data) continue

      for (const key of ['First Destination', 'Second Destination']) {
        const dest = normalizeDest(row[key])
        if (!dest) continue
        const switchedDest = game.switcherPath(dest, version)
        if (switchedDest === dest) continue
        zip.file(`${switchedDest}/${row.File}`, data)
      }
    }
  }

  // KH1-specific: bundle raw container files (.bgm / .dat) from kh1/raw/ at the
  // switched "raw" prefix paths — mirrors what build-zips.yml does for the Switcher.
  if (game.rawDir && existsSync(game.rawDir)) {
    for (const rawName of readdirSync(game.rawDir)) {
      const rawData = readFileSync(join(game.rawDir, rawName))

      for (const row of rows) {
        if (row.Changed !== 'Y') continue

        for (const key of ['First Destination', 'Second Destination']) {
          const dest = normalizeDest(row[key])
          if (!dest || !dest.endsWith(`/${rawName}`)) continue

          for (const version of ['Classic', 'Remastered']) {
            const suffix = version === 'Classic' ? '2' : '3'
            // Replace /remastered/ → /raw/ and /amusic/ → /amusi2|3/ in the dest.
            const rawDest = dest
              .replace('/remastered/', '/raw/')
              .replace('/amusic/', `/amusi${suffix}/`)
            if (rawDest === dest) continue
            zip.file(rawDest, rawData)
          }
        }
      }
    }
  }

  return zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE', compressionOptions: { level: 6 } })
}

function mb(buf) {
  return (buf.length / 1024 / 1024).toFixed(1)
}

async function main() {
  for (const [gameId, game] of Object.entries(GAMES)) {
    if (gameFilter.size > 0 && !gameFilter.has(gameId)) continue

    const rows = JSON.parse(readFileSync(game.json, 'utf8'))

    for (const version of ['Classic', 'Remastered']) {
      if (typeFilter.size > 0 && !typeFilter.has(version)) continue
      console.log(`Building ${gameId}-${version}…`)
      const buf = await buildVersionPatch(rows, game.tracksDir, version)
      const out = join(outDir, `${gameId}-${version}.${game.ext}`)
      writeFileSync(out, buf)
      console.log(`  → ${out} (${mb(buf)} MB)`)
    }

    if (typeFilter.size === 0 || typeFilter.has('Switcher')) {
      console.log(`Building ${gameId}-Switcher…`)
      const buf = await buildSwitcherPatch(rows, game)
      const out = join(outDir, `${gameId}-Switcher.${game.ext}`)
      writeFileSync(out, buf)
      console.log(`  → ${out} (${mb(buf)} MB)`)
    }
  }

  console.log('Done.')
}

main().catch(e => { console.error(e); process.exit(1) })
