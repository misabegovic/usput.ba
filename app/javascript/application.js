// Configure your import map in config/importmap.rb
import "@hotwired/turbo-rails"
import "controllers"
import { planSyncService } from "services/plan_sync_service"

// Auto-sync plans when logged in user loads the page
// This ensures localStorage is updated with server data (including UUIDs) after registration/login
document.addEventListener("turbo:load", async () => {
  if (planSyncService.isLoggedIn()) {
    // Only sync if there are local plans that might need UUID updates
    const localPlans = planSyncService.getLocalPlans()
    const needsSync = localPlans.some(plan => !plan.uuid || !plan.synced)
    if (needsSync) {
      try {
        await planSyncService.syncPlans()
      } catch (e) {
        console.error("[Usput] Plan sync error:", e)
      }
    }
  }
})

// Configure Turbo to use CSP nonce for dynamically inserted scripts
// This ensures scripts from Turbo navigations get the current page's nonce
document.addEventListener("turbo:before-render", (event) => {
  const cspMetaTag = document.querySelector('meta[name="csp-nonce"]')
  if (cspMetaTag) {
    const nonce = cspMetaTag.content
    event.detail.newBody.querySelectorAll("script:not([data-turbo-eval='false'])").forEach((script) => {
      // Update nonce to match current page's CSP
      script.nonce = nonce
    })
  }
})
