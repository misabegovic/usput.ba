// Plan Sync Service
// Handles synchronization between localStorage and backend for user plans

const PLANS_KEY = "visitumo_plans"
const ACTIVE_PLAN_KEY = "visitumo_active_plan"

export class PlanSyncService {
  constructor() {
    this.syncEndpoint = "/user/plans/sync"
    this.plansEndpoint = "/user/plans"
  }

  // Check if user is logged in (from meta tag or session)
  isLoggedIn() {
    const meta = document.querySelector('meta[name="user-logged-in"]')
    return meta?.content === "true"
  }

  // Get CSRF token
  getCsrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  // Load plans from localStorage
  getLocalPlans() {
    try {
      const data = localStorage.getItem(PLANS_KEY)
      return data ? JSON.parse(data) : []
    } catch {
      return []
    }
  }

  // Save plans to localStorage
  saveLocalPlans(plans) {
    try {
      localStorage.setItem(PLANS_KEY, JSON.stringify(plans))
    } catch (error) {
      console.error("Failed to save plans to localStorage:", error)
    }
  }

  // Get active plan ID
  getActivePlanId() {
    return localStorage.getItem(ACTIVE_PLAN_KEY)
  }

  // Set active plan ID
  setActivePlanId(planId) {
    if (planId) {
      localStorage.setItem(ACTIVE_PLAN_KEY, planId)
    } else {
      localStorage.removeItem(ACTIVE_PLAN_KEY)
    }
  }

  // Sync plans with backend (for logged-in users)
  async syncPlans() {
    if (!this.isLoggedIn()) {
      return { success: false, reason: "not_logged_in" }
    }

    const localPlans = this.getLocalPlans()

    try {
      const response = await fetch(this.syncEndpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.getCsrfToken()
        },
        body: JSON.stringify({ plans: localPlans })
      })

      if (!response.ok) {
        throw new Error(`Sync failed: ${response.status}`)
      }

      const data = await response.json()

      if (data.success && data.plans) {
        // Update localStorage with synced plans
        this.saveLocalPlans(data.plans)

        // Update active plan if needed
        const activePlanId = this.getActivePlanId()
        if (activePlanId) {
          const stillExists = data.plans.some(p => p.id === activePlanId)
          if (!stillExists && data.plans.length > 0) {
            this.setActivePlanId(data.plans[0].id)
          }
        } else if (data.plans.length > 0) {
          this.setActivePlanId(data.plans[0].id)
        }
      }

      return { success: true, plans: data.plans }
    } catch (error) {
      console.error("Plan sync error:", error)
      return { success: false, error: error.message }
    }
  }

  // Fetch plans from backend only (for initial load after login)
  async fetchPlansFromBackend() {
    if (!this.isLoggedIn()) {
      return { success: false, reason: "not_logged_in" }
    }

    try {
      const response = await fetch(this.plansEndpoint, {
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.getCsrfToken()
        }
      })

      if (!response.ok) {
        throw new Error(`Fetch failed: ${response.status}`)
      }

      const data = await response.json()
      return { success: true, plans: data.plans || [] }
    } catch (error) {
      console.error("Fetch plans error:", error)
      return { success: false, error: error.message }
    }
  }

  // Delete plan from backend
  async deletePlan(planId) {
    if (!this.isLoggedIn()) {
      // Just delete from localStorage
      return this.deleteLocalPlan(planId)
    }

    try {
      const response = await fetch(`${this.plansEndpoint}/${planId}`, {
        method: "DELETE",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.getCsrfToken()
        }
      })

      if (response.ok || response.status === 404) {
        // Also delete from localStorage
        this.deleteLocalPlan(planId)
        return { success: true }
      }

      throw new Error(`Delete failed: ${response.status}`)
    } catch (error) {
      console.error("Delete plan error:", error)
      return { success: false, error: error.message }
    }
  }

  // Delete plan from localStorage only
  deleteLocalPlan(planId) {
    const plans = this.getLocalPlans()
    const filtered = plans.filter(p => p.id !== planId && p.uuid !== planId)
    this.saveLocalPlans(filtered)

    // Update active plan if needed
    const activePlanId = this.getActivePlanId()
    if (activePlanId === planId) {
      this.setActivePlanId(filtered.length > 0 ? filtered[0].id : null)
    }

    return { success: true }
  }

  // Get plans data for registration (to send with user creation)
  getPlansForRegistration() {
    return JSON.stringify(this.getLocalPlans())
  }
}

// Singleton instance
export const planSyncService = new PlanSyncService()
