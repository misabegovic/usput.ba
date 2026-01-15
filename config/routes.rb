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
    resources :locations do
      resources :photo_suggestions, only: [:new, :create]
    end
    resources :experiences
    resources :reviews, only: [ :index, :show, :destroy ]
    resources :audio_tours
    resources :plans
    resources :proposals, only: [ :index, :show ] do
      member do
        post :add_review
      end
    end
    resources :photo_suggestions, only: [:index, :show]

    # Admin features for admin users within curator dashboard
    namespace :admin do
      resources :photo_suggestions, only: [:index, :show] do
        member do
          post :approve
          post :reject
        end
      end
      resources :users, only: [:index, :show, :edit, :update] do
        member do
          post :unblock
        end
      end
      resources :curator_applications, only: [:index, :show] do
        member do
          post :approve
          post :reject
        end
      end
      resources :content_changes, only: [:index, :show] do
        member do
          post :approve
          post :reject
        end
      end
    end

    root "dashboard#index"
  end


  # Platform API
  namespace :api do
    namespace :platform do
      # Chat/DSL execution
      post "chat", to: "chat#create"
      post "execute", to: "chat#execute"
      get "parse", to: "chat#parse"

      # Status and health
      get "status", to: "status#index"
      get "health", to: "status#health"
      get "statistics", to: "status#statistics"
      get "infrastructure", to: "status#infrastructure"
      get "logs", to: "status#logs"

      # Prompts
      get "prompts", to: "status#prompts"
      get "prompts/:id", to: "status#show_prompt"
    end
  end

  # Defines the root path route ("/")
  root "new_design#home"
end
