Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Static pages
  get "imprint", to: "pages#imprint", as: :imprint
  get "privacy", to: "pages#privacy", as: :privacy
  get "terms", to: "pages#terms", as: :terms

  # New design pages (visual development)
  get "new/home", to: "new_design#home", as: :new_home
  get "explore", to: "new_design#explore", as: :explore

  # Authentication routes
  get "register", to: "users#new", as: :register
  post "register", to: "users#create"
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # User avatar
  patch "profile/avatar", to: "users#update_avatar", as: :update_avatar
  delete "profile/avatar", to: "users#remove_avatar", as: :remove_avatar

  # Travel profile page (accessible to everyone, syncs for logged-in users)
  get "profile", to: "travel_profiles#page", as: :profile_page
  get "profile/plans", to: "travel_profiles#my_plans", as: :profile_plans
  resource :travel_profile, only: [ :show, :update ], controller: "travel_profiles" do
    post :sync, on: :member
    post :validate_visit, on: :member
  end

  # User plans (for logged-in users)
  namespace :user do
    resources :plans, controller: "/user_plans" do
      collection do
        post :sync
        post :share
      end
      member do
        post :toggle_visibility
      end
    end
  end

  # Curator applications (for users to apply)
  get "become-curator", to: "curator_applications#info", as: :become_curator
  resources :curator_applications, only: [ :new, :create, :show ]

  # Locations (index removed - use /explore instead)
  resources :locations, only: [ :show ] do
    resources :reviews, only: [ :index, :create ]
    member do
      get :audio_tour
    end
  end

  # Experiences (index removed - use /explore instead)
  resources :experiences, only: [ :show ] do
    resources :reviews, only: [ :index, :create ]
  end

  # Plan wizard (must be before resources :plans to avoid matching plans#show)
  get "plans/wizard", to: "plans#wizard", as: :plan_wizard
  get "plans/wizard/:city_slug", to: "plans#wizard", as: :plan_wizard_city
  post "plans/find_city", to: "plans#find_city"
  get "plans/search_cities", to: "plans#search_cities"
  post "plans/generate", to: "plans#generate"
  get "plans/view", to: "plans#view", as: :plan_view
  get "plans/recommendations", to: "plans#recommendations"

  # Plans (index redirects to explore)
  get "plans", to: redirect("/explore"), as: :plans
  resources :plans, only: [ :show ], constraints: { id: /(?!(wizard|find_city|search_cities|generate|view|recommendations)\b)[^\/]+/ } do
    resources :reviews, only: [ :index, :create ]
  end

  # Curator dashboard - for curators and admins
  namespace :curator do
    resources :locations
    resources :experiences
    resources :reviews, only: [ :index, :show, :destroy ]
    resources :audio_tours
    resources :plans
    root "dashboard#index"
  end

  # Admin dashboard - authenticated via ENV credentials
  namespace :admin do
    get "login", to: "sessions#new", as: :login
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout

    resources :users, only: [ :index, :show, :edit, :update, :destroy ]
    resources :curator_applications, only: [ :index, :show ] do
      member do
        post :approve
        post :reject
      end
    end
    resources :ai_generations, only: [ :index ] do
      member do
        post :retry
      end
    end

    # Autonomni AI Content Generator
    get "ai", to: "ai#index", as: :ai
    post "ai/generate", to: "ai#generate", as: :generate_admin_ai
    post "ai/stop", to: "ai#stop", as: :stop_admin_ai
    post "ai/reset", to: "ai#reset", as: :reset_admin_ai
    get "ai/status", to: "ai#status", as: :status_admin_ai
    get "ai/report", to: "ai#report", as: :report_admin_ai
    post "ai/fix_cities", to: "ai#fix_cities", as: :fix_cities_admin_ai
    get "ai/fix_cities_status", to: "ai#fix_cities_status", as: :fix_cities_status_admin_ai
    post "ai/force_reset_city_fix", to: "ai#force_reset_city_fix", as: :force_reset_city_fix_admin_ai

    # Audio Tours Generator (odvojeno od glavnog AI generatora)
    get "ai/audio_tours", to: "ai/audio_tours#index", as: :ai_audio_tours
    post "ai/audio_tours/generate", to: "ai/audio_tours#generate", as: :generate_admin_ai_audio_tours
    get "ai/audio_tours/estimate", to: "ai/audio_tours#estimate", as: :estimate_admin_ai_audio_tours

    delete "clear_database", to: "dashboard#clear_database"
    root "dashboard#index"
  end

  # Defines the root path route ("/")
  root "new_design#home"
end
