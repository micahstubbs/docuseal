<template>
  <div class="mb-3">
    <div
      v-if="images.length"
      :id="`${fieldId}-saved-signatures`"
      data-testid="saved-signatures"
      class="mb-2"
    >
      <p class="text-sm text-base-content/60 mb-2">
        {{ t('saved_on_this_device') }}
      </p>
      <div class="flex flex-wrap gap-2">
        <div
          v-for="(image, index) in images"
          :key="image.dataUrl"
          class="border border-base-300 rounded p-1"
        >
          <button
            :id="`${fieldId}-saved-signature-${index}`"
            type="button"
            data-testid="saved-signature-option"
            :aria-label="`${t('use_saved_image')}: ${image.name || t(kind)} ${index + 1}`"
            :disabled="isLoading"
            class="block rounded border border-base-300 bg-white p-1"
            @click="select(image)"
          >
            <img
              :src="image.dataUrl"
              :alt="image.name || t(kind)"
              class="w-24 h-12 object-contain"
            >
          </button>
          <button
            :id="`${fieldId}-saved-signature-remove-${index}`"
            type="button"
            data-testid="saved-signature-remove"
            :aria-label="`${t('remove_saved_image')}: ${image.name || t(kind)} ${index + 1}`"
            :disabled="isLoading"
            class="btn btn-ghost btn-xs w-full mt-1"
            @click="remove(image)"
          >
            {{ t('remove_saved_image') }}
          </button>
        </div>
      </div>
    </div>
    <label
      :for="`${fieldId}-saved-signature-optout`"
      class="flex items-center gap-2 text-sm cursor-pointer"
    >
      <input
        :id="`${fieldId}-saved-signature-optout`"
        v-model="enabled"
        type="checkbox"
        data-testid="saved-signature-optout"
        class="checkbox checkbox-xs"
        @change="setSavingEnabled(enabled)"
      >
      {{ t('save_on_this_device') }}
    </label>
    <p
      v-if="error"
      role="status"
      class="text-sm text-base-content/60 mt-1"
    >
      {{ error }}
    </p>
  </div>
</template>

<script>
import { readImages, saveImage, removeImage, storeImages, savingEnabled, setSavingEnabled } from './saved_signatures'

export default {
  name: 'SavedSignatures',
  inject: ['t'],
  props: {
    kind: { type: String, required: true },
    fieldId: { type: String, required: true },
    signerName: { type: String, default: '' },
    selectFile: { type: Function, required: true }
  },
  data () {
    return { images: readImages(this.kind), enabled: savingEnabled(), error: '', isLoading: false }
  },
  methods: {
    setSavingEnabled,
    async select (image) {
      this.isLoading = true
      this.error = ''

      try {
        const bytes = Uint8Array.from(atob(image.dataUrl.split(',')[1]), char => char.charCodeAt(0))
        await this.selectFile(new File([bytes], `${this.kind}.png`, { type: 'image/png' }))
      } catch {
        this.error = this.t('saved_image_could_not_be_used')
      } finally {
        this.isLoading = false
      }
    },
    remove (image) {
      const images = removeImage(readImages(this.kind), image.dataUrl)

      if (storeImages(this.kind, images)) {
        this.images = images
        this.error = ''
      } else {
        this.error = this.t('saved_image_could_not_be_removed')
      }
    },
    async remember (file) {
      if (!this.enabled || !savingEnabled()) return

      try {
        // Keep photos bounded too: two one-million-character lists fit localStorage.
        // Only raster PNG data is retained, never remote URLs or uploaded SVG markup.
        const bitmap = await createImageBitmap(file)
        const canvas = document.createElement('canvas')
        const scale = Math.min(1, 512 / bitmap.width, 256 / bitmap.height)
        canvas.width = Math.max(1, Math.round(bitmap.width * scale))
        canvas.height = Math.max(1, Math.round(bitmap.height * scale))
        canvas.getContext('2d').drawImage(bitmap, 0, 0, canvas.width, canvas.height)
        bitmap.close()

        if (!this.enabled || !savingEnabled()) return

        const image = { dataUrl: canvas.toDataURL('image/png'), savedAt: Date.now(), name: this.signerName }
        const images = saveImage(readImages(this.kind), image)

        if (!storeImages(this.kind, images)) throw new Error('Storage unavailable')

        this.images = images
        this.error = ''
      } catch {
        this.error = this.t('image_could_not_be_saved_on_this_device')
      }
    }
  }
}
</script>
