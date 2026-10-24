// Umami custom events for the signing form (sign.dataroom.fast, dataroom bd-jo10).
//
// Loaded by app/views/shared/_umami.html.erb only when UMAMI_WEBSITE_ID is set,
// before the Umami tracker (both deferred, so they run in order): the
// beforeSend hook below must exist before the first page view leaves.
//
// Privacy rules, enforced here rather than trusted to callers:
//   - signer slugs and other random path segments are rewritten to ":slug" in
//     every URL and referrer, because a /s/<slug> link is the signer's
//     credential; the tracker is also told to drop query strings and hashes;
//   - event data carries ids, field types, field labels and counts, never a
//     field value, a signer name, an email address or a token.
//
// The form is a compiled Vue app with no public event API on this page, so the
// events come from observing it: the fetch() calls it makes to save steps,
// complete and download, the decline/delegate form posts, and DOM input,
// scroll and visibility events.
(function () {
  'use strict'

  // DocuSeal slugs are SecureRandom.base58 (12+ chars); tokens and uuids are
  // long runs of [A-Za-z0-9_-]. Route words never contain an uppercase letter
  // or digit in base58 form, so requiring one keeps /submissions etc. intact.
  var BASE58_SLUG = /^[1-9A-HJ-NP-Za-km-z]{12,}$/
  var LONG_TOKEN = /^[A-Za-z0-9_-]{24,}$/
  var UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

  function scrubSegment (seg) {
    if (UUID.test(seg) || LONG_TOKEN.test(seg)) return ':slug'
    if (BASE58_SLUG.test(seg) && /[A-Z0-9]/.test(seg)) return ':slug'
    return seg
  }

  function scrubPath (path) {
    return path.split('/').map(scrubSegment).join('/')
  }

  function scrubUrl (value) {
    if (!value) return value
    try {
      var u = new URL(value, window.location.href)
      return u.origin + scrubPath(u.pathname)
    } catch (e) {
      return ''
    }
  }

  window.docusealUmamiBeforeSend = function (type, payload) {
    if (!payload) return payload
    if (payload.url) payload.url = scrubUrl(payload.url)
    if (payload.referrer) payload.referrer = scrubUrl(payload.referrer)
    return payload
  }

  var ctx = {}
  try {
    var meta = document.querySelector('meta[name="umami-context"]')
    ctx = meta ? JSON.parse(meta.content) : {}
  } catch (e) {
    ctx = {}
  }

  var ids = {}
  ;['page', 'submission_id', 'template_id', 'submitter_id'].forEach(function (k) {
    if (ctx[k] !== undefined && ctx[k] !== null) ids[k] = ctx[k]
  })

  var queue = []
  var flushTimer = null

  function send (name, data) {
    try {
      window.umami.track(name, data)
    } catch (e) {
      // analytics must never break signing
    }
  }

  function track (name, data) {
    var payload = Object.assign({}, ids, data || {})
    if (window.umami && typeof window.umami.track === 'function') return send(name, payload)
    queue.push([name, payload])
    if (flushTimer) return
    var tries = 0
    flushTimer = setInterval(function () {
      tries++
      if (window.umami && typeof window.umami.track === 'function') {
        while (queue.length) send.apply(null, queue.shift())
      }
      if (!queue.length || tries > 50) {
        clearInterval(flushTimer)
        flushTimer = null
      }
    }, 200)
  }

  window.docusealUmamiTrack = track

  var isSigningPage = /^(submit_form|start_form|submit_form_draw_signature)#/.test(ctx.page || '')
  var loadedAt = Date.now()
  var state = {
    started: false,
    completed: ctx.submitter_status === 'completed',
    reported: {},
    fieldsCompleted: 0,
    milestones: {},
    maxDepth: 0,
    visibleMs: 0,
    visibleSince: document.visibilityState === 'visible' ? Date.now() : null
  }
  var fieldsIndex = {}

  function formEl () {
    return document.querySelector('submission-form')
  }

  function readFields () {
    var el = formEl()
    if (!el || !el.dataset.fields) return []
    try {
      return JSON.parse(el.dataset.fields) || []
    } catch (e) {
      return []
    }
  }

  function onReady () {
    var fields = readFields()
    fields.forEach(function (f) { if (f && f.uuid) fieldsIndex[f.uuid] = f })
    if (!isSigningPage) return
    var loaded = {
      has_form: !!formEl(),
      submitter_status: ctx.submitter_status || 'unknown'
    }
    if (fields.length) {
      loaded.field_count = fields.length
      loaded.required_count = fields.filter(function (f) { return f.required }).length
    }
    track('signing-form-loaded', loaded)
    measureDepth()
  }

  // signing-started: the first real interaction with the form
  function onFirstInteraction (e) {
    if (state.started || state.completed || !formEl()) return
    if (e.type === 'keydown' && (e.key === 'Tab' || e.key === 'Shift')) return
    state.started = true
    track('signing-started', {
      via: e.type,
      seconds_to_start: Math.round((Date.now() - loadedAt) / 1000)
    })
  }
  ;['pointerdown', 'keydown', 'input'].forEach(function (t) {
    document.addEventListener(t, onFirstInteraction, { capture: true, passive: true })
  })

  // Scroll depth over the signing document (#scrollbox or the page)
  function scroller () {
    var box = document.getElementById('scrollbox')
    if (box && box.scrollHeight > box.clientHeight + 1) return box
    return document.scrollingElement || document.documentElement
  }

  // Depth and time are measured only while the fill-and-sign form is on the
  // page; the completed/declined/expired screens fit on one screen.
  function measureDepth () {
    if (!isSigningPage || !formEl()) return
    var s = scroller()
    if (!s) return
    var frac = s.scrollHeight > s.clientHeight + 1 ? (s.scrollTop + s.clientHeight) / s.scrollHeight : 1
    var pct = Math.max(0, Math.min(100, Math.round(frac * 100)))
    if (pct > state.maxDepth) state.maxDepth = pct
    ;[25, 50, 75, 100].forEach(function (m) {
      if (pct >= m && !state.milestones[m]) {
        state.milestones[m] = true
        track('signing-scroll-depth', { depth: m })
      }
    })
  }

  var depthRaf = null
  document.addEventListener('scroll', function () {
    if (depthRaf) return
    depthRaf = requestAnimationFrame(function () {
      depthRaf = null
      measureDepth()
    })
  }, { capture: true, passive: true })

  // fetch(): step saves, completion, downloads
  function pathOf (url) {
    try {
      return new URL(url, window.location.href).pathname
    } catch (e) {
      return ''
    }
  }

  function filledValueUuids (body) {
    var out = []
    if (!(body instanceof FormData)) return out
    body.forEach(function (value, key) {
      var m = /^values\[([^\]]+)\]/.exec(key)
      if (!m) return
      var empty = value === '' || value === null || (typeof File !== 'undefined' && value instanceof File && value.size === 0)
      if (!empty && out.indexOf(m[1]) === -1) out.push(m[1])
    })
    return out
  }

  var origFetch = window.fetch
  if (typeof origFetch === 'function') {
    window.fetch = function (input, init) {
      var url = typeof input === 'string' ? input : (input && input.url) || ''
      var method = ((init && init.method) || (input && input.method) || 'GET').toUpperCase()
      var path = pathOf(url)
      var body = init && init.body
      var isStepSave = method === 'POST' && /^\/s\/[^/]+$/.test(path)
      var isDownload = /^\/(submitters|s)\/[^/]+\/(download|documents)$/.test(path)
      var completes = isStepSave && body instanceof FormData && body.get('completed') === 'true'
      var uuids = isStepSave ? filledValueUuids(body) : []

      var result = origFetch.apply(this, arguments)
      result.then(function (resp) {
        if (!resp || !resp.ok) return
        if (isStepSave) {
          uuids.forEach(function (uuid) {
            if (state.reported[uuid]) return
            state.reported[uuid] = true
            state.fieldsCompleted++
            var f = fieldsIndex[uuid] || {}
            track('field-completed', {
              field_type: f.type || 'unknown',
              field_name: (f.name || '').slice(0, 60) || '(unnamed)',
              required: !!f.required
            })
          })
          if (completes && !state.completed) {
            state.completed = true
            track('signing-completed', {
              fields_completed: state.fieldsCompleted,
              seconds_on_form: Math.round((Date.now() - loadedAt) / 1000)
            })
          }
        } else if (isDownload) {
          track('signing-document-downloaded', {
            after_signing: state.completed,
            source: path.indexOf('/submitters/') === 0 ? 'completed-form' : 'header-button'
          })
        }
      }, function () {})
      return result
    }
  }

  // Decline and delegate are plain form posts
  document.addEventListener('submit', function (e) {
    var action = (e.target && e.target.getAttribute && e.target.getAttribute('action')) || ''
    var path = pathOf(action)
    if (/\/decline$/.test(path)) {
      track('signing-declined', { seconds_on_form: Math.round((Date.now() - loadedAt) / 1000) })
    } else if (/\/delegate$/.test(path)) {
      track('signing-delegated', {})
    }
  }, true)

  // Visible time on the page, flushed when hidden or closed
  function flushTime (reason) {
    if (!isSigningPage || !formEl()) return
    if (state.visibleSince) {
      state.visibleMs += Date.now() - state.visibleSince
      state.visibleSince = null
    }
    var seconds = Math.round(state.visibleMs / 1000)
    state.visibleMs = 0
    if (seconds < 1) return
    track('time-on-signing-form', {
      seconds: seconds,
      reason: reason,
      completed: state.completed,
      started: state.started,
      max_depth: state.maxDepth
    })
  }

  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'hidden') flushTime('hidden')
    else if (!state.visibleSince) state.visibleSince = Date.now()
  })
  window.addEventListener('pagehide', function () { flushTime('close') })

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', onReady)
  else onReady()
})()
