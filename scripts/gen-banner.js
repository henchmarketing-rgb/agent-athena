#!/usr/bin/env node
/**
 * Generates the AGENT ATHENA pixel-art banner PNG.
 * Style: thick blocky letters with horizontal colour banding and 3D depth.
 * Run: node scripts/gen-banner.js
 * Output: assets/banner.png
 */

const { createCanvas } = require('canvas')
const fs = require('fs')
const path = require('path')

const CANVAS_W = 1200
const CANVAS_H = 300
const GRID = 10 // each "pixel" is 10x10

// Colour bands (top to bottom) - teal gradient
const BANDS = [
  '#7aedd4', // brightest
  '#5de4c7',
  '#4ad4b5',
  '#38c4a3',
  '#2aaa8e',
  '#229078',
  '#1c7a66',
  '#186858',
  '#14564a',
  '#10453c', // darkest
]

// Depth/shadow colours
const DEPTH_RIGHT = '#0e3d35'
const DEPTH_BOTTOM = '#0b312b'
const BG_COLOR = '#0d1117'
const GRID_COLOR = 'rgba(93, 228, 199, 0.03)'
const ACCENT_COLOR = '#5de4c7'
const TAGLINE_COLOR = 'rgba(93, 228, 199, 0.4)'

// Letter definitions on pixel grid
// Each letter is an array of [col, row] pairs marking filled blocks
// Letters are defined in a local grid, then positioned
function defineLetter(pattern) {
  // pattern is array of strings, each char is '#' (filled) or '.' (empty)
  const blocks = []
  for (let r = 0; r < pattern.length; r++) {
    for (let c = 0; c < pattern[r].length; c++) {
      if (pattern[r][c] === '#') {
        blocks.push([c, r])
      }
    }
  }
  return { blocks, width: pattern[0].length, height: pattern.length }
}

const LETTERS = {
  A: defineLetter([
    '.####.',
    '##..##',
    '##..##',
    '##..##',
    '######',
    '##..##',
    '##..##',
    '##..##',
    '##..##',
    '##..##',
  ]),
  G: defineLetter([
    '.####.',
    '##..##',
    '##....',
    '##....',
    '##.###',
    '##..##',
    '##..##',
    '##..##',
    '##..##',
    '.####.',
  ]),
  E: defineLetter([
    '######',
    '##....',
    '##....',
    '##....',
    '#####.',
    '##....',
    '##....',
    '##....',
    '##....',
    '######',
  ]),
  N: defineLetter([
    '##..##',
    '###.##',
    '###.##',
    '####.#',
    '##.###',
    '##.###',
    '##..##',
    '##..##',
    '##..##',
    '##..##',
  ]),
  T: defineLetter([
    '######',
    '..##..',
    '..##..',
    '..##..',
    '..##..',
    '..##..',
    '..##..',
    '..##..',
    '..##..',
    '..##..',
  ]),
  H: defineLetter([
    '##..##',
    '##..##',
    '##..##',
    '##..##',
    '######',
    '##..##',
    '##..##',
    '##..##',
    '##..##',
    '##..##',
  ]),
}

// "AGENT ATHENA" layout
const WORD1 = ['A', 'G', 'E', 'N', 'T']
const WORD2 = ['A', 'T', 'H', 'E', 'N', 'A']
const LETTER_GAP = 1  // grid units between letters
const WORD_GAP = 4    // grid units between words

const canvas = createCanvas(CANVAS_W, CANVAS_H)
const ctx = canvas.getContext('2d')

// Background
ctx.fillStyle = BG_COLOR
ctx.fillRect(0, 0, CANVAS_W, CANVAS_H)

// Subtle grid
ctx.strokeStyle = GRID_COLOR
ctx.lineWidth = 0.5
for (let x = 0; x < CANVAS_W; x += GRID * 4) {
  ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, CANVAS_H); ctx.stroke()
}
for (let y = 0; y < CANVAS_H; y += GRID * 4) {
  ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(CANVAS_W, y); ctx.stroke()
}

// Top accent line
ctx.fillStyle = ACCENT_COLOR
ctx.fillRect(0, 0, CANVAS_W, 3)

// Calculate total width to determine sizing
function calcTotalWidth(word1, word2, letterGap, wordGap) {
  let w = 0
  for (const ch of word1) w += LETTERS[ch].width + letterGap
  w -= letterGap // remove trailing gap
  w += wordGap
  for (const ch of word2) w += LETTERS[ch].width + letterGap
  w -= letterGap
  return w
}

let totalGridW = calcTotalWidth(WORD1, WORD2, LETTER_GAP, WORD_GAP)
const letterH = 10 // all letters are 10 rows

// Scale to fit nicely — letters should be big and bold
// Target: letters fill about 70% of height, left-aligned with padding
const targetH = CANVAS_H * 0.68
const scale = Math.min(targetH / (letterH * GRID), (CANVAS_W - 100) / (totalGridW * GRID))
const pixelSize = Math.floor(GRID * scale)

const startX = Math.floor(pixelSize * 3.5) // left padding
const startY = Math.floor((CANVAS_H - letterH * pixelSize) / 2) - 15

// Draw a single pixel block with banding and 3D depth
function drawBlock(x, y, row, totalRows) {
  const bandIdx = Math.floor((row / totalRows) * BANDS.length)
  const color = BANDS[Math.min(bandIdx, BANDS.length - 1)]

  const depth = Math.max(2, Math.floor(pixelSize * 0.15))

  // Bottom depth
  ctx.fillStyle = DEPTH_BOTTOM
  ctx.fillRect(x, y + pixelSize, pixelSize, depth)

  // Right depth
  ctx.fillStyle = DEPTH_RIGHT
  ctx.fillRect(x + pixelSize, y, depth, pixelSize + depth)

  // Main face
  ctx.fillStyle = color
  ctx.fillRect(x, y, pixelSize, pixelSize)

  // Subtle inner highlight (top-left pixel brighter)
  ctx.fillStyle = 'rgba(255, 255, 255, 0.08)'
  ctx.fillRect(x, y, pixelSize, Math.max(1, pixelSize * 0.15))

  // Subtle border
  ctx.strokeStyle = 'rgba(0, 0, 0, 0.15)'
  ctx.lineWidth = 0.5
  ctx.strokeRect(x + 0.5, y + 0.5, pixelSize - 1, pixelSize - 1)
}

// Draw all letters
let curX = startX

function drawWord(word) {
  for (const ch of word) {
    const letter = LETTERS[ch]
    for (const [col, row] of letter.blocks) {
      drawBlock(
        curX + col * pixelSize,
        startY + row * pixelSize,
        row,
        letter.height
      )
    }
    curX += (letter.width + LETTER_GAP) * pixelSize
  }
}

drawWord(WORD1)
curX += (WORD_GAP - LETTER_GAP) * pixelSize  // add extra word gap
drawWord(WORD2)

// Tagline - left aligned below letters
const taglineY = startY + letterH * pixelSize + Math.floor(pixelSize * 2.5)
ctx.fillStyle = TAGLINE_COLOR
ctx.font = `${Math.floor(pixelSize * 1.1)}px "Courier New", monospace`
ctx.letterSpacing = '3px'
ctx.fillText('GODDESS OF WISDOM & CRAFT', startX, taglineY)

// Output
const outPath = path.join(__dirname, '..', 'assets', 'banner.png')
const buffer = canvas.toBuffer('image/png')
fs.writeFileSync(outPath, buffer)
console.log(`Banner written to ${outPath} (${buffer.length} bytes)`)
console.log(`Dimensions: ${CANVAS_W}x${CANVAS_H}`)
