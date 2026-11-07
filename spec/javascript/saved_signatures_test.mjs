// Run with: node --test spec/javascript/saved_signatures_test.mjs
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { test } from 'node:test'

const source = await readFile(new URL('../../app/javascript/submission_form/saved_signatures.js', import.meta.url), 'utf8')
const saved = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`)
const image = (id, savedAt = id) => ({ dataUrl: `data:image/png;base64,${Buffer.from(String(id)).toString('base64')}`, savedAt, name: 'Jane Doe' })
const storage = () => {
  const values = new Map()
  return { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) }
}

test('loads empty, corrupt and untrusted storage safely', () => {
  for (const value of [null, '', '{', '{}', '[null]', '42']) assert.deepEqual(saved.loadImages(value), [])
  assert.deepEqual(saved.loadImages(JSON.stringify([
    image(1), { ...image(2), dataUrl: 'https://example.com/signature.png' },
    { ...image(3), dataUrl: 'data:image/svg+xml;base64,PHN2Zz4=' },
    { ...image(4), savedAt: 'yesterday' }
  ])), [image(1)])
})

test('saves most recent first, deduplicates and caps at five without mutating input', () => {
  const original = [image(1)]
  let images = original
  for (let id = 2; id <= 7; id++) images = saved.saveImage(images, image(id))
  assert.deepEqual(images.map(item => item.savedAt), [7, 6, 5, 4, 3])
  assert.deepEqual(original, [image(1)])
  images = saved.saveImage(images, { ...image(4), name: 'New name', savedAt: 8 })
  assert.equal(images.length, 5)
  assert.equal(images[0].name, 'New name')
  assert.deepEqual(saved.loadImages(JSON.stringify(images)), images)
})

test('removes only the chosen image and survives reload', () => {
  assert.deepEqual(saved.removeImage([image(2), image(1)], image(2).dataUrl), [image(1)])
  const device = storage()
  saved.storeImages('signature', [image(2), image(1)], device)
  saved.storeImages('signature', saved.removeImage(saved.readImages('signature', device), image(2).dataUrl), device)
  assert.deepEqual(saved.readImages('signature', device), [image(1)])
})

test('keeps signatures and initials separate and stores no attachment identifiers', () => {
  const device = storage()
  saved.storeImages('signature', [image(1)], device)
  saved.storeImages('initials', [image(2)], device)
  assert.deepEqual(saved.readImages('signature', device), [image(1)])
  assert.deepEqual(saved.readImages('initials', device), [image(2)])
  assert.deepEqual(saved.saveImage([], { ...image(1), uuid: 'server-id' }), [image(1)])
})

test('bounds encoded storage size as well as count', () => {
  const large = id => ({ ...image(id), dataUrl: `data:image/png;base64,${String(id).repeat(400000)}` })
  const images = saved.saveImage([large(2), large(1)], large(3))
  assert.deepEqual(images.map(item => item.savedAt), [3, 2])
  assert.ok(JSON.stringify(images).length <= saved.MAX_STORAGE_CHARS)
})

test('blocked reads and quota failures do not escape into signing', () => {
  const blocked = { getItem () { throw new Error('blocked') }, setItem () { throw new Error('quota') } }
  assert.deepEqual(saved.readImages('signature', blocked), [])
  assert.equal(saved.storeImages('signature', [image(1)], blocked), false)
  assert.equal(saved.savingEnabled(blocked), true)
  assert.equal(saved.setSavingEnabled(false, blocked), false)
})

test('device opt-out persists independently of the image lists', () => {
  const device = storage()
  assert.equal(saved.savingEnabled(device), true)
  assert.equal(saved.setSavingEnabled(false, device), true)
  assert.equal(saved.savingEnabled(device), false)
  saved.storeImages('initials', [image(1)], device)
  assert.equal(saved.savingEnabled(device), false)
  saved.setSavingEnabled(true, device)
  assert.equal(saved.savingEnabled(device), true)
})
