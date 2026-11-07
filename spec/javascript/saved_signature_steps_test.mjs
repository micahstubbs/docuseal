// Component-method tests with browser I/O supplied explicitly; no Rails needed.
// Run with: node spec/javascript/saved_signature_steps_test.mjs
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import vm from 'node:vm'
import { test } from 'node:test'

const require = createRequire(import.meta.url)
const { parse } = require('@vue/compiler-sfc')
const { transformSync } = require('@babel/core')
const root = new URL('../../app/javascript/submission_form/', import.meta.url)
const dataUrl = 'data:image/png;base64,c2lnbmF0dXJl'
const file = new File([Buffer.from('signature')], 'signature.png', { type: 'image/png' })
const storageSource = readFileSync(new URL('saved_signatures.js', root), 'utf8')
const storageModule = await import(`data:text/javascript;base64,${Buffer.from(storageSource).toString('base64')}`)

function component (filename, globals = {}, imports = {}) {
  const { descriptor } = parse(readFileSync(new URL(filename, root), 'utf8'))
  const { code } = transformSync(descriptor.script.content, {
    configFile: false, babelrc: false, plugins: ['@babel/plugin-transform-modules-commonjs']
  })
  const module = { exports: {} }
  vm.runInNewContext(code, {
    module, exports: module.exports, File, Blob, FormData, Uint8Array, atob, console, setTimeout, window: {},
    require: name => imports[name] || {}, ...globals
  })
  return module.exports.default
}

function instance (definition, props = {}) {
  const subject = { $emit () {}, $refs: {}, ...props }
  for (const [name, method] of Object.entries(definition.methods)) subject[name] = method.bind(subject)
  return subject
}

function signingStep (kind, overrides = {}) {
  const calls = []
  const definition = component(`${kind}_step.vue`, {
    fetch: async (url, options) => {
      calls.push({ url, body: options.body })
      return { ok: true, status: 200, json: async () => ({ uuid: 'new-attachment', url: '/normal-attachment.png' }) }
    },
    ...overrides
  }, {
    './signature_step': kind === 'initials' ? component('signature_step.vue') : {},
    './crop_canvas': { cropCanvasAndExportToPNG: async () => file },
    './validate_signature': { isValidSignatureCanvas: () => true, isCanvasBlocked: () => false }
  })
  const remembered = []
  const events = []
  const subject = instance(definition, {
    field: { required: true }, submitter: { name: 'Jane Doe' }, submitterSlug: 'new-document', baseUrl: '',
    values: {}, pad: { toData: () => [] }, modelValue: '', computedPreviousValue: '', rememberSignature: false,
    $refs: { canvas: {}, savedSignatures: { remember: async image => remembered.push(image) } },
    $emit: (...event) => events.push(event), t: key => key
  })
  return { subject, calls, remembered, events }
}

for (const kind of ['signature', 'initials']) {
  test(`${kind}: uploaded and picked files clear old strokes and use the same canvas loader`, async () => {
    const { subject } = signingStep(kind)
    let cleared = false
    subject.savedImageFile = file
    subject.pad.clear = () => { cleared = true }
    subject.drawOnCanvas = async (image, canvas) => {
      assert.equal(image, file)
      assert.equal(canvas, subject.$refs.canvas)
    }
    await subject.drawImage({ target: { files: [file] } })
    assert.equal(cleared, true)
    assert.equal(subject.savedImageFile, null)
    assert.equal(kind === 'signature' ? subject.isTextSignature : !subject.isDrawInitials, false)
  })

  test(`${kind}: completion saves the cropped image after a normal attachment upload`, async () => {
    const { subject, calls, remembered, events } = signingStep(kind)
    await subject.submit()
    assert.equal(calls.length, 1)
    assert.equal(calls[0].url, '/api/attachments')
    assert.equal(calls[0].body.get('type'), kind)
    assert.equal(calls[0].body.get('submitter_slug'), 'new-document')
    assert.equal(await calls[0].body.get('file').text(), 'signature')
    assert.equal(remembered.length, 1)
    assert.ok(events.some(([name, value]) => name === 'update:model-value' && value === 'new-attachment'))
    assert.equal(calls[0].body.has('savedAt'), false)
    assert.equal(calls[0].body.has('save_on_device'), false)
  })

  test(`${kind}: saved selection uses drawImage and waits for image loading before completion`, async () => {
    const { subject, calls, remembered } = signingStep(kind)
    let finish
    const drawing = new Promise(resolve => { finish = resolve })
    subject.drawImage = event => {
      assert.equal(event.target.files[0], file)
      subject.pendingImage = drawing
      return drawing
    }
    const selecting = subject.selectSavedImage(file)
    const submitting = subject.submit()
    await Promise.resolve()
    assert.equal(calls.length, 0)
    finish()
    await selecting
    await submitting
    assert.equal(calls.length, 1)
    assert.equal(remembered[0], file)
  })

  test(`${kind}: failed upload never saves an image`, async () => {
    const { subject, remembered } = signingStep(kind, {
      fetch: async () => ({ ok: false, status: 403, json: async () => ({ error: 'Failed' }) }),
      alert () {}
    })
    await assert.rejects(subject.submit())
    assert.equal(remembered.length, 0)
  })
}

test('typed-only controls remain available after picking an image', async () => {
  const { subject } = signingStep('signature')
  subject.format = 'typed_or_upload'
  subject.isTextSignature = true
  subject.pad.clear = () => {}
  subject.drawOnCanvas = async () => {}
  await subject.selectSavedImage(file)
  assert.equal(subject.isTextSignature, true)
})

test('upload-only selection calls the dropzone and saves only when completing the field', async () => {
  const { subject, remembered, events } = signingStep('signature')
  subject.format = 'upload'
  subject.$nextTick = async () => {}
  subject.$refs.uploadDropzone = {
    uploadFiles: async files => {
      assert.equal(files[0], file)
      subject.onUploadSignature([{ uuid: 'dropzone-attachment' }], files)
      subject.modelValue = 'dropzone-attachment'
    }
  }
  await subject.selectSavedImage(file)
  assert.equal(remembered.length, 0)
  await subject.submit()
  assert.equal(remembered[0], file)
  assert.ok(events.some(([name, value]) => name === 'update:model-value' && value === 'dropzone-attachment'))
})

test('dropzone passes the converted image to signing without changing attachment payloads', async () => {
  const events = []
  let body
  const definition = component('dropzone.vue', {
    FileReader: class {
      readAsDataURL () { this.onload({ target: { result: dataUrl } }) }
    },
    Image: class {
      constructor () { this.width = 50; this.height = 20 }
      set src (value) { queueMicrotask(() => this.onload()) }
    },
    document: {
      createElement: () => ({ getContext: () => ({ drawImage () {} }), toBlob: callback => callback(file) })
    },
    fetch: async (url, options) => {
      assert.equal(url, '/api/attachments')
      body = options.body
      return { status: 200, json: async () => ({ uuid: 'uploaded' }) }
    }
  })
  const subject = instance(definition, { baseUrl: '', submitterSlug: 'new-document', $emit: (...args) => events.push(args) })
  await subject.uploadFiles([new File(['svg'], 'image.svg', { type: 'image/svg+xml' })])
  assert.equal(body.get('file').type, 'image/png')
  assert.equal(body.get('name'), 'attachments')
  assert.equal(events[0][0], 'upload')
  assert.equal(events[0][1][0].uuid, 'uploaded')
  assert.equal(events[0][2][0].type, 'image/png')
  assert.equal(subject.isLoading, false)
})

function picker (extraGlobals = {}) {
  const values = new Map()
  const storage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) }
  const api = {
    ...storageModule,
    readImages: kind => storageModule.readImages(kind, storage),
    storeImages: (kind, images) => storageModule.storeImages(kind, images, storage),
    savingEnabled: () => storageModule.savingEnabled(storage),
    setSavingEnabled: enabled => storageModule.setSavingEnabled(enabled, storage)
  }
  const definition = component('saved_signatures.vue', {
    createImageBitmap: async () => ({ width: 100, height: 40, close () {} }),
    document: { createElement: () => ({ getContext: () => ({ drawImage () {} }), toDataURL: () => dataUrl }) },
    ...extraGlobals
  }, { './saved_signatures': api })
  return { api, subject: instance(definition, { kind: 'signature', signerName: 'Jane Doe', enabled: true, t: key => key }) }
}

test('picker produces an image File from stored bytes, with no network fetch', async () => {
  const { subject } = picker()
  subject.selectFile = async selected => {
    assert.equal(selected.type, 'image/png')
    assert.equal(await selected.text(), 'signature')
  }
  await subject.select({ dataUrl })
  assert.equal(subject.error, '')
  assert.equal(subject.isLoading, false)
})

test('picker saves name and timestamp, then removes only its own image kind', async () => {
  const { subject, api } = picker()
  await subject.remember(file)
  assert.equal(subject.images.length, 1)
  assert.equal(subject.images[0].name, 'Jane Doe')
  assert.ok(subject.images[0].savedAt > 0)
  api.storeImages('initials', subject.images)
  subject.remove(subject.images[0])
  assert.equal(api.readImages('signature').length, 0)
  assert.equal(api.readImages('initials').length, 1)
})

test('checkbox and persisted opt-out both prevent saving, including during image decoding', async () => {
  let finish
  const decoding = new Promise(resolve => { finish = resolve })
  const { subject, api } = picker({ createImageBitmap: () => decoding })
  subject.enabled = false
  await subject.remember(file)
  assert.equal(api.readImages('signature').length, 0)
  subject.enabled = true
  api.setSavingEnabled(false)
  await subject.remember(file)
  assert.equal(api.readImages('signature').length, 0)
  api.setSavingEnabled(true)
  const saving = subject.remember(file)
  subject.enabled = false
  finish({ width: 100, height: 40, close () {} })
  await saving
  assert.equal(api.readImages('signature').length, 0)
})

test('storage/decode errors do not reject signing and removals report failure honestly', async () => {
  const { subject, api } = picker({ createImageBitmap: async () => { throw new Error('blocked') } })
  await subject.remember(file)
  assert.equal(subject.error, 'image_could_not_be_saved_on_this_device')
  api.storeImages = () => false
  subject.remove({ dataUrl })
  assert.equal(subject.error, 'saved_image_could_not_be_removed')
})
