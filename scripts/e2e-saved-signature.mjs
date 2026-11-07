#!/usr/bin/env node
// End-to-end check of saved signature images on sign.dataroom.fast (docuseal-ir1).
//  1. creates a throwaway template with one signature field and two submissions (send_email: false),
//  2. in one headless Chrome profile, draws a signature on submission A and completes it,
//  3. opens submission B and asserts the saved signature is offered, picks it, completes it,
//  4. archives both submissions and the template.
// Usage: node scripts/e2e-saved-signature.mjs [--shots DIR] [--keep]
// Needs ~/keys/dataroom/SIGN_ADMIN.md and Playwright (NODE_PATH=~/wk/casemirror/node_modules).
import { readFileSync, mkdirSync, mkdtempSync } from 'node:fs'
import { tmpdir, homedir } from 'node:os'
import { join } from 'node:path'
import { randomUUID } from 'node:crypto'
import { createRequire } from 'node:module'

const require = createRequire(join(homedir(), 'wk/casemirror/node_modules/'))
const { chromium } = require('playwright')

const BASE = 'https://sign.dataroom.fast'
const UA = 'dataroom-e2e-saved-signature'
const args = process.argv.slice(2)
const shots = args.includes('--shots') ? args[args.indexOf('--shots') + 1] : mkdtempSync(join(tmpdir(), 'savedsig-'))
mkdirSync(shots, { recursive: true })
const token = readFileSync(join(homedir(), 'keys/dataroom/SIGN_ADMIN.md'), 'utf8').match(/[A-Za-z0-9]{30,}/)[0]
const repo = new URL('..', import.meta.url).pathname

async function api (method, path, body) {
  const res = await fetch(`${BASE}/api${path}`, {
    method,
    headers: { 'X-Auth-Token': token, 'Content-Type': 'application/json', 'User-Agent': UA },
    body: body ? JSON.stringify(body) : undefined
  })
  if (!res.ok) throw new Error(`${method} ${path}: ${res.status} ${await res.text()}`)
  const text = await res.text()
  return text ? JSON.parse(text) : null
}

const stamp = new Date().toISOString()
const pdf = readFileSync(join(repo, 'spec/fixtures/sample-document.pdf')).toString('base64')
const template = await api('POST', '/templates/pdf', {
  name: `E2E saved-signature test ${stamp} (docuseal-ir1)`,
  documents: [{ name: 'e2e-saved-signature', file: pdf }]
})
const attachmentUuid = template.schema[0].attachment_uuid
const role = randomUUID()
await api('PUT', `/templates/${template.id}`, {
  submitters: [{ name: 'Signer', uuid: role }],
  fields: [{
    uuid: randomUUID(), submitter_uuid: role, name: 'Signature', type: 'signature', required: true,
    areas: [{ x: 0.1, y: 0.7, w: 0.3, h: 0.06, page: 0, attachment_uuid: attachmentUuid }]
  }]
})
const subs = []
for (const label of ['A', 'B']) {
  const s = await api('POST', '/submissions', {
    template_id: template.id, send_email: false,
    submitters: [{ role: 'Signer', email: `micah+signtest-${label.toLowerCase()}@superradiant.ai`, name: `Saved Sig ${label}` }]
  })
  subs.push(s[0])
}
console.log(`template ${template.id}; submissions ${subs.map(s => s.submission_id).join(', ')}`)

// The form can open minimized behind an expand button; open it so the steps are visible.
async function openForm (page, shot) {
  await page.waitForLoadState('networkidle')
  await page.screenshot({ path: join(shots, shot) })
  const expand = page.locator('#expand_form_button')
  if (await expand.isVisible()) await expand.click()
}

const profile = mkdtempSync(join(tmpdir(), 'savedsig-profile-'))
const ctx = await chromium.launchPersistentContext(profile, { headless: true, viewport: { width: 1200, height: 1000 } })
let ok = false
try {
  const page = await ctx.newPage()

  // A: draw and complete
  await page.goto(`${BASE}/s/${subs[0].slug}`)
  await openForm(page, '0-a-loaded.png')
  const canvas = page.locator('canvas.draw-canvas').first()
  await canvas.waitFor({ timeout: 20000 })
  await page.screenshot({ path: join(shots, '1-a-empty.png') })
  const box = await canvas.boundingBox()
  await page.mouse.move(box.x + 40, box.y + box.height / 2)
  await page.mouse.down()
  for (let i = 1; i <= 20; i++) await page.mouse.move(box.x + 40 + i * 12, box.y + box.height / 2 + (i % 2 ? -25 : 25), { steps: 2 })
  await page.mouse.up()
  await page.locator('#submit_form_button').click()
  await page.waitForFunction(() => !document.querySelector('canvas.draw-canvas'), null, { timeout: 30000 })
  await page.waitForTimeout(1500)
  await page.screenshot({ path: join(shots, '2-a-done.png') })
  const stored = await page.evaluate(() => Object.keys(localStorage).filter(k => k.startsWith('docuseal.saved-images')).map(k => [k, JSON.parse(localStorage.getItem(k)).length]))
  console.log('localStorage after A:', JSON.stringify(stored))
  if (!stored.some(([, n]) => n > 0)) throw new Error('no saved image in localStorage after signing A')

  // B: saved signature offered, pick it, complete
  await page.goto(`${BASE}/s/${subs[1].slug}`)
  await openForm(page, '2b-b-loaded.png')
  const picker = page.locator('[data-testid="saved-signatures"]').first()
  await picker.waitFor({ timeout: 20000 })
  // B uses another email, so DocuSeal's own same-signer prefill cannot fill the field.
  if (await page.locator('canvas.draw-canvas').first().isHidden()) throw new Error('B field already filled before picking')
  const options = await page.locator('[data-testid="saved-signature-option"]').count()
  console.log(`B offers ${options} saved signature(s)`)
  await page.screenshot({ path: join(shots, '3-b-picker.png') })
  await page.locator('[data-testid="saved-signature-option"]').first().click()
  await page.waitForTimeout(1000)
  await page.screenshot({ path: join(shots, '4-b-picked.png') })
  await page.locator('#submit_form_button').click()
  await page.waitForFunction(() => !document.querySelector('[data-testid="saved-signatures"]'), null, { timeout: 30000 })
  await page.waitForTimeout(1500)
  await page.screenshot({ path: join(shots, '5-b-done.png') })

  for (const s of subs) {
    const sub = await api('GET', `/submissions/${s.submission_id}`)
    const values = sub.submitters[0].values || []
    console.log(`submission ${s.submission_id}: ${sub.status}; signature value present: ${values.some(v => v.value)}`)
    if (sub.status !== 'completed') throw new Error(`submission ${s.submission_id} not completed`)
  }
  ok = true
} finally {
  await ctx.close()
  if (!args.includes('--keep')) {
    for (const s of subs) await api('DELETE', `/submissions/${s.submission_id}`)
    await api('DELETE', `/templates/${template.id}`)
    console.log('archived throwaway submissions and template')
  }
  console.log(`screenshots: ${shots}`)
  console.log(ok ? 'PASS' : 'FAIL')
  process.exitCode = ok ? 0 : 1
}
