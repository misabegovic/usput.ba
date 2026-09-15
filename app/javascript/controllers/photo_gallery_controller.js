import { Controller } from "@hotwired/stimulus"

// Literal, not interpolated: Tailwind only generates class names it can read.
const LIKED_HEART = [ "text-red-500", "hover:bg-white/10" ]
const UNLIKED_HEART = [ "text-white/80", "hover:bg-white/10", "hover:text-red-500" ]

// Connects to data-controller="photo-gallery"
// Photo gallery with horizontal slider and lightbox mode
export default class extends Controller {
  static targets = [
    "slide", "counter", "dot", "thumbnail", "slider", "lightbox", "lightboxImage",
    "lightboxCounter", "lightboxThumbnail",
    "captionAuthor", "captionPlace", "captionPlaceName", "captionNote", "captionUploaded", "captionLike",
    "captionLikeCount", "captionDownload", "captionShare", "captionVisibility", "captionVisibilityButton",
    "captionDelete", "captionNoteForm", "captionNoteField", "captionStatus"
  ]
  static values = {
    index: { type: Number, default: 0 },
    lightboxOpen: { type: Boolean, default: false },
    // The whole collection: counting tiles would call three of forty "everything".
    total: { type: Number, default: 0 },
    // A moment's own address renders the band with the viewer already open on it.
    openOnConnect: { type: Boolean, default: false },
    // Where the url goes once that viewer is shut: arriving straight at a moment
    // leaves no surface url behind it to restore.
    returnUrl: { type: String, default: "" }
  }

  // Unpaged galleries have no total, where tiles and collection are the same.
  get collectionSize() {
    return this.totalValue > 0 ? this.totalValue : this.thumbnailTargets.length
  }

  connect() {
    // Enable keyboard navigation
    this.boundKeyHandler = this.handleKeyDown.bind(this)
    document.addEventListener("keydown", this.boundKeyHandler)

    // The caption reads the rewritten tile, so it re-reads once the stream lands.
    this.boundWriteBack = this.rereadTile.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundWriteBack)
    this.element.addEventListener("turbo:submit-end", this.boundWriteBack)

    // Turbo snapshots the body as it is; an open viewer would cache unscrollable.
    // The url goes back first: leaving with the moment's address still in the bar
    // overwrites this surface's history entry, and coming back lands on the
    // moment rather than the moments you were looking at.
    this.boundBeforeCache = () => { this.restoreUrl(); this.leavingPage = true; this.closeLightbox() }

    // Before a visit rather than only before the cache: a link pressed inside the
    // viewer starts navigating while the moment's address is still in the bar,
    // and a replaceState landing after that would rewrite the url Turbo just set.
    this.boundBeforeVisit = () => { this.restoreUrl(); this.leavingPage = true }
    document.addEventListener("turbo:before-visit", this.boundBeforeVisit)
    document.addEventListener("turbo:before-cache", this.boundBeforeCache)

    // Enable swipe on mobile
    this.setupSwipe()

    if (this.openOnConnectValue) {
      // Seeded before opening: showMomentInUrl only records a return url when it
      // finds none, and the one in the bar is the moment's own.
      if (this.returnUrlValue) this.urlBeforeViewer = this.returnUrlValue
      this.openLightbox()
    }
  }

  disconnect() {
    this.restoreUrl()
    this.leavingPage = true
    document.removeEventListener("turbo:before-visit", this.boundBeforeVisit)
    document.removeEventListener("keydown", this.boundKeyHandler)
    document.removeEventListener("turbo:before-cache", this.boundBeforeCache)
    document.removeEventListener("turbo:before-stream-render", this.boundWriteBack)
    this.element.removeEventListener("turbo:submit-end", this.boundWriteBack)
    this.closeLightbox()
  }

  // Wrapped, not timed: a stream renders async, so anything scheduled reads stale.
  rereadTile(event) {
    const render = event?.detail?.render
    if (!render) return this.refillFromTile()

    event.detail.render = async (streamElement) => {
      await render(streamElement)
      this.refillFromTile()
    }
  }

  refillFromTile() {
    this.fillCaption(this.thumbnailTargets[this.indexValue])
    this.clearStatusLater()
  }

  // The status is a thing said, not a thing stored, so it leaves on its own.
  clearStatusLater() {
    if (!this.hasCaptionStatusTarget) return

    // Unconditional: the message arrives after this, so checking here finds none.
    clearTimeout(this.statusTimer)
    this.statusTimer = setTimeout(() => {
      if (!this.hasCaptionStatusTarget) return
      this.captionStatusTarget.textContent = ""
      this.captionStatusTarget.classList.add("hidden")
    }, 4000)
  }

  // Stepping off the last loaded tile fetches rather than wrapping to the first.
  next() {
    const total = this.hasSlideTarget ? this.slideTargets.length : this.thumbnailTargets.length
    if (this.indexValue === total - 1 && this.requestMore()) return

    const newIndex = (this.indexValue + 1) % total
    this.goToIndex(newIndex)
  }

  // Announcing keeps the two controllers ignorant of each other.
  requestMore() {
    const event = this.dispatch("edgeReached", {
      cancelable: true,
      detail: { advance: () => this.advanceAfterLoad() }
    })
    return event.defaultPrevented
  }

  // Called by the loader once new tiles are in the DOM.
  advanceAfterLoad() {
    const total = this.hasSlideTarget ? this.slideTargets.length : this.thumbnailTargets.length
    if (this.indexValue < total - 1) this.goToIndex(this.indexValue + 1)
  }

  // Wrapping back only makes sense once the last loaded tile is the last one.
  previous() {
    const total = this.hasSlideTarget ? this.slideTargets.length : this.thumbnailTargets.length
    if (this.indexValue === 0 && this.collectionSize > total) return

    const newIndex = (this.indexValue - 1 + total) % total
    this.goToIndex(newIndex)
  }

  // Go to specific slide (from thumbnail or dot click)
  goTo(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    this.goToIndex(index)
  }

  // Go to specific index
  goToIndex(index) {
    const total = this.hasSlideTarget ? this.slideTargets.length : this.thumbnailTargets.length
    if (index < 0 || index >= total) return

    // Update slides if present
    if (this.hasSlideTarget) {
      this.slideTargets.forEach((slide, i) => {
        if (i === index) {
          slide.classList.remove("opacity-0", "pointer-events-none")
          slide.classList.add("opacity-100")
        } else {
          slide.classList.remove("opacity-100")
          slide.classList.add("opacity-0", "pointer-events-none")
        }
      })
    }

    // Update counter
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = index + 1
    }

    // Update dots
    this.dotTargets.forEach((dot, i) => {
      if (i === index) {
        dot.classList.remove("bg-white/50", "hover:bg-white/80", "w-2")
        dot.classList.add("bg-white", "w-4")
      } else {
        dot.classList.remove("bg-white", "w-4")
        dot.classList.add("bg-white/50", "hover:bg-white/80", "w-2")
      }
    })

    // Update thumbnails
    this.thumbnailTargets.forEach((thumb, i) => {
      if (i === index) {
        thumb.classList.remove("ring-transparent", "hover:ring-gray-300", "dark:hover:ring-gray-600")
        thumb.classList.add("ring-emerald-500")
      } else {
        thumb.classList.remove("ring-emerald-500")
        thumb.classList.add("ring-transparent", "hover:ring-gray-300", "dark:hover:ring-gray-600")
      }
    })

    // Update lightbox if open
    if (this.lightboxOpenValue && this.hasLightboxImageTarget) {
      const thumb = this.thumbnailTargets[index]
      if (thumb) {
        const img = thumb.querySelector("img")
        if (img) {
          this.lightboxImageTarget.src = this.sourceFor(thumb, img)
          this.lightboxImageTarget.alt = img.alt
        }
      }
      if (this.hasLightboxCounterTarget) {
        this.lightboxCounterTarget.textContent = `${index + 1} / ${this.collectionSize}`
      }

      // Update lightbox thumbnails
      this.lightboxThumbnailTargets.forEach((lbThumb, i) => {
        if (i === index) {
          lbThumb.classList.remove("ring-transparent", "opacity-60")
          lbThumb.classList.add("ring-emerald-500", "opacity-100")
        } else {
          lbThumb.classList.remove("ring-emerald-500", "opacity-100")
          lbThumb.classList.add("ring-transparent", "opacity-60")
        }
      })

      this.fillCaption(this.thumbnailTargets[index])
    }

    this.indexValue = index
    if (this.lightboxOpenValue) this.showMomentInUrl()
  }

  // Reads the tile, so swiping issues no request.
  fillCaption(thumb) {
    if (!thumb || !this.hasCaptionAuthorTarget) return

    const moment = thumb.dataset
    this.captionAuthorTarget.textContent = moment.momentAuthor || ""
    this.captionPlaceNameTarget.textContent = moment.momentPlace || ""
    this.captionPlaceTarget.href = moment.momentPlaceUrl || "#"
    this.captionNoteTarget.textContent = moment.momentNote || ""
    this.captionNoteTarget.hidden = !moment.momentNote
    this.captionUploadedTarget.textContent = moment.momentUploaded || ""
    this.captionUploadedTarget.hidden = !moment.momentUploaded
    this.captionDownloadTarget.href = moment.momentDownloadUrl || "#"
    this.fillShare(moment)

    this.fillLike(moment)
    this.fillOwnerControls(moment)
  }

  // A private or unapproved moment carries no url, because a stranger following
  // one would find nothing.
  fillShare(moment) {
    if (!this.hasCaptionShareTarget) return

    const url = moment.momentShareUrl
    this.shareUrl = url || null
    this.captionShareTarget.classList.toggle("hidden", !url)
    this.captionShareTarget.classList.toggle("flex", Boolean(url))
  }

  // Share sheet where the browser has one, clipboard where it does not. Both
  // say so in the caption's own status line rather than an alert.
  async shareMoment() {
    if (!this.shareUrl) return

    try {
      if (navigator.share) {
        await navigator.share({ url: this.shareUrl })
        return
      }

      await navigator.clipboard.writeText(this.shareUrl)
      this.sayStatus(this.captionShareTarget.dataset.copiedLabel)
    } catch (error) {
      // A dismissed share sheet rejects, and that is not a failure to report.
      if (error?.name !== "AbortError") this.sayStatus(this.captionShareTarget.dataset.failedLabel)
    }
  }

  sayStatus(message) {
    if (!this.hasCaptionStatusTarget || !message) return

    this.captionStatusTarget.textContent = message
    this.captionStatusTarget.classList.remove("hidden")
    this.clearStatusLater()
  }

  // A tile that is not yours carries none of these urls.
  fillOwnerControls(moment) {
    const owned = moment.momentOwned === "true"

    if (this.hasCaptionNoteFormTarget) {
      this.captionNoteFormTarget.classList.toggle("hidden", !owned)
      this.captionNoteTarget.hidden = owned || !moment.momentNote
      if (owned) {
        this.captionNoteFormTarget.action = moment.momentNoteUrl
        this.captionNoteFieldTarget.value = moment.momentNote || ""
      }
    }

    if (this.hasCaptionVisibilityTarget) {
      this.captionVisibilityTarget.classList.toggle("hidden", !owned)
      if (owned) {
        this.captionVisibilityTarget.action = moment.momentVisibilityUrl
        this.captionVisibilityButtonTarget.textContent = moment.momentVisibilityLabel || ""
      }
    }

    if (this.hasCaptionDeleteTarget) {
      this.captionDeleteTarget.classList.toggle("hidden", !owned)
      if (owned) this.captionDeleteTarget.action = moment.momentDeleteUrl
    }
  }

  // No audience means no like url, and no heart.
  fillLike(moment) {
    if (!this.hasCaptionLikeTarget) return

    const like = this.captionLikeTarget
    const likeable = Boolean(moment.momentLikeUrl)
    like.hidden = !likeable
    this.captionLikeCountTarget.hidden = !likeable
    if (!likeable) {
      // Cleared, not just hidden: a stale href would react on the moment before.
      like.removeAttribute("href")
      like.dataset.liked = "false"
      this.captionLikeCountTarget.textContent = ""
      return
    }

    const liked = moment.momentLiked === "true"
    const count = Number(moment.momentLikesCount || 0)

    like.href = moment.momentLikeUrl
    // A guest's heart is an ordinary link into sign-in, not a react.
    if (moment.momentLikeGuest === "true") delete like.dataset.turboMethod
    else like.dataset.turboMethod = liked ? "delete" : "post"
    like.dataset.liked = liked
    like.setAttribute("aria-pressed", liked)
    like.querySelector("svg").setAttribute("fill", liked ? "currentColor" : "none")
    like.classList.remove(...(liked ? UNLIKED_HEART : LIKED_HEART))
    like.classList.add(...(liked ? LIKED_HEART : UNLIKED_HEART))

    this.captionLikeCountTarget.textContent = count > 0 ? count : ""
  }


  // Open lightbox mode
  openLightbox(event) {
    if (event) {
      // Appended cards carry no index, and the opener may be the tile's edit button.
      const index = event.currentTarget.dataset.index
        ? parseInt(event.currentTarget.dataset.index, 10)
        : this.thumbnailTargets.indexOf(this.thumbnailFor(event.currentTarget))
      if (!isNaN(index) && index >= 0) {
        this.indexValue = index
      }
    }

    if (!this.hasLightboxTarget) return

    this.lightboxOpenValue = true
    this.showLightbox()
    document.body.classList.add("overflow-hidden")

    // Set initial image
    const total = this.thumbnailTargets.length
    const thumb = this.thumbnailTargets[this.indexValue]
    if (thumb && this.hasLightboxImageTarget) {
      const img = thumb.querySelector("img")
      if (img) {
        this.lightboxImageTarget.src = this.sourceFor(thumb, img)
        this.lightboxImageTarget.alt = img.alt
      }
    }
    if (this.hasLightboxCounterTarget) {
      this.lightboxCounterTarget.textContent = `${this.indexValue + 1} / ${this.collectionSize}`
    }

    this.fillCaption(thumb)
    this.showMomentInUrl()
  }

  // Whichever control was clicked, the thumbnail is its frame's.
  thumbnailFor(opener) {
    if (this.thumbnailTargets.includes(opener)) return opener

    const tile = opener.closest("turbo-frame")
    return tile?.querySelector("[data-photo-gallery-target='thumbnail']") ?? opener
  }

  // Thumbnails may carry a larger source for the lightbox; galleries that
  // don't keep showing the thumbnail, as before.
  sourceFor(thumb, img) {
    return thumb.dataset.photoGalleryFullUrl || img.src
  }

  // The deleted moment is the one on screen, so the viewer has nothing left to
  // show. A failed delete leaves it open: the moment is still there.
  closeOnDelete(event) {
    if (event.detail?.success === false) return

    this.closeLightbox()
  }

  // Close lightbox mode
  closeLightbox() {
    if (!this.hasLightboxTarget) return

    this.lightboxOpenValue = false
    this.hideLightbox()
    this.clearThumbnailRings()
    document.body.classList.remove("overflow-hidden")
    this.restoreUrl()
  }

  // Replaced, not pushed: a pushed entry sends the back button through Turbo's
  // restoration, which re-renders the surface from a snapshot taken before any
  // load-more and loses the moments the traveller scrolled to. The address is
  // what a link needs; a history entry is not.
  showMomentInUrl() {
    if (this.leavingPage) return

    const url = this.thumbnailTargets[this.indexValue]?.dataset?.momentPageUrl
    if (!url) return this.restoreUrl()

    if (this.urlBeforeViewer === undefined) this.urlBeforeViewer = window.location.href
    window.history.replaceState(window.history.state, "", url)
  }

  restoreUrl() {
    if (this.leavingPage || this.urlBeforeViewer === undefined) return

    window.history.replaceState(window.history.state, "", this.urlBeforeViewer)
    this.urlBeforeViewer = undefined
  }

  // Galleries that render inside a card use a <dialog> so the top layer lifts
  // them out of it; the older ones are plain divs toggled by class.
  showLightbox() {
    const el = this.lightboxTarget
    if (typeof el.showModal === "function") {
      if (!el.open) el.showModal()
    } else {
      el.classList.remove("hidden")
    }
  }

  hideLightbox() {
    const el = this.lightboxTarget
    if (typeof el.close === "function") {
      if (el.open) el.close()
    } else {
      el.classList.add("hidden")
    }
  }

  // Esc and the backdrop close a dialog without going through closeLightbox.
  onLightboxClosed() {
    this.lightboxOpenValue = false
    this.clearThumbnailRings()
    document.body.classList.remove("overflow-hidden")
  }

  // The ring means "this is the one you are looking at". Once the viewer is
  // shut it means nothing, and a stray green circle reads as a state badge.
  clearThumbnailRings() {
    this.thumbnailTargets.forEach((thumb) => {
      thumb.classList.remove("ring-emerald-500")
      thumb.classList.add("ring-transparent", "hover:ring-gray-300", "dark:hover:ring-gray-600")
    })
  }

  // Close lightbox on background click
  closeLightboxOnBackground(event) {
    if (event.target === event.currentTarget) {
      this.closeLightbox()
    }
  }

  // Gated on this viewer being open: explore mounts two galleries.
  handleKeyDown(event) {
    if (!this.lightboxOpenValue) return

    if (event.key === "ArrowRight") {
      this.next()
    } else if (event.key === "ArrowLeft") {
      this.previous()
    } else if (event.key === "Escape" && this.lightboxOpenValue) {
      this.closeLightbox()
    }
  }

  // Touch swipe support
  setupSwipe() {
    let startX = 0
    let startY = 0

    this.element.addEventListener("touchstart", (e) => {
      startX = e.touches[0].clientX
      startY = e.touches[0].clientY
    }, { passive: true })

    this.element.addEventListener("touchend", (e) => {
      // The listener covers the whole section, not just the open viewer.
      if (!this.lightboxOpenValue) return

      const endX = e.changedTouches[0].clientX
      const endY = e.changedTouches[0].clientY
      const diffX = startX - endX
      const diffY = startY - endY

      // Only trigger swipe if horizontal movement is greater than vertical
      if (Math.abs(diffX) > Math.abs(diffY) && Math.abs(diffX) > 50) {
        if (diffX > 0) {
          this.next()
        } else {
          this.previous()
        }
      }
    }, { passive: true })
  }
}
