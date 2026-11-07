// Device-only image data, deliberately independent of submitter and attachment IDs.
export const MAX_STORAGE_CHARS = 1000000
const KEY = 'docuseal.saved-images.v1.'
const PREFERENCE_KEY = 'docuseal.save-images.v1'

export function normalizeImages (items) {
  if (!Array.isArray(items)) return []

  const seen = new Set()
  const images = []
  let size = 2

  items.filter(item => item && typeof item.dataUrl === 'string' &&
    /^data:image\/png;base64,[A-Za-z0-9+/]+=*$/.test(item.dataUrl) &&
    Number.isFinite(item.savedAt) && item.savedAt >= 0)
    .sort((a, b) => b.savedAt - a.savedAt).forEach(item => {
      const image = { dataUrl: item.dataUrl, savedAt: item.savedAt, name: typeof item.name === 'string' ? item.name.slice(0, 200) : '' }
      const length = JSON.stringify(image).length + 1

      if (images.length < 5 && !seen.has(image.dataUrl) && size + length <= MAX_STORAGE_CHARS) {
        images.push(image)
        seen.add(image.dataUrl)
        size += length
      }
    })

  return images
}

export function loadImages (serialized) {
  try {
    return normalizeImages(JSON.parse(serialized))
  } catch {
    return []
  }
}

export function saveImage (images, image) {
  return normalizeImages([image, ...images.filter(item => item.dataUrl !== image.dataUrl)])
}

export function removeImage (images, dataUrl) {
  return normalizeImages(images.filter(item => item.dataUrl !== dataUrl))
}

function browserStorage () {
  try {
    return window.localStorage
  } catch {
    return null
  }
}

export function readImages (kind, storage = browserStorage()) {
  try {
    return loadImages(storage?.getItem(KEY + kind))
  } catch {
    return []
  }
}

export function storeImages (kind, images, storage = browserStorage()) {
  try {
    if (!storage) return false
    storage.setItem(KEY + kind, JSON.stringify(normalizeImages(images)))
    return true
  } catch {
    return false
  }
}

export function savingEnabled (storage = browserStorage()) {
  try {
    return storage?.getItem(PREFERENCE_KEY) !== 'false'
  } catch {
    return true
  }
}

export function setSavingEnabled (enabled, storage = browserStorage()) {
  try {
    if (!storage) return false
    storage.setItem(PREFERENCE_KEY, String(enabled))
    return true
  } catch {
    return false
  }
}
