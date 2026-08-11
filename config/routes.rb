Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Minesweeper mini-game (fictional random boards — no connection to real mine data)
  get "minesweeper", to: "minesweeper#show", as: :minesweeper

  # Public mine-proximity check (owner-authorized Phase 2, bands only —
  # see docs/mine_checker/README.md)
  get "mine-check", to: "mine_check_public#show", as: :mine_check
  post "mine-check/check", to: "mine_check_public#check", as: :mine_check_query
  get "mine-check/areas", to: "mine_check_public#areas", as: :mine_check_areas

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
  get "route", to: "map_routes#show", as: :map_route
  get "explore-bosnia", to: "explore_bosnia#show", as: :explore_bosnia
  # "all" is the unfiltered entry; several at once ride in the query string.
  get "explore-bosnia/:category", to: "explore_bosnia#experience", as: :explore_bosnia_experience
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
    collection do
      get :map_points
    end
    # Reading a place's moments needs no plan — a guest walking explore mode has
    # none. Writing one still does, and stays on the plan-nested route above.
    resources :moments, only: [ :index ]
    member do
      get :audio_tour
      get :map_panel
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
    # Walk the plan as a trip: locations stacked as steps.
    member do
      get :start
    end
    # Per-user, server-owned "I was here" progress for the walk. Create only:
    # a visit is permanent, so there is no route that takes one back.
    resources :visits, only: [ :create ], module: :plans
    # Private photos a logged-in traveller attaches to this plan's locations.
    # The photo is served by our own action rather than Active Storage's route,
    # which does not check the session — see MomentsController#photo.
    resources :moments, only: [ :index, :create, :destroy ] do
      member do
        get :photo
        patch :publish
        patch :unpublish
      end
    end
  end

  # Curator dashboard - for curators and admins
  namespace :curator do
    resources :moments, only: [ :index ] do
      member do
        get :photo
        post :approve
        post :reject
      end
    end
    resources :locations do
      resources :photo_suggestions, only: [ :new, :create ]
      collection do
        get :needs_photos
      end
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
    resources :photo_suggestions, only: [ :index, :show ]

    # Admin features for admin users within curator dashboard
    namespace :admin do
      resources :photo_suggestions, only: [ :index, :show ] do
        member do
          post :approve
          post :reject
        end
      end
      resources :users, only: [ :index, :show, :edit, :update ] do
        member do
          post :unblock
        end
      end
      resources :curator_applications, only: [ :index, :show ] do
        member do
          post :approve
          post :reject
        end
      end
      resources :content_changes, only: [ :index, :show ] do
        member do
          post :approve
          post :reject
        end
      end
    end

    root "dashboard#index"
  end

  # Defines the root path route ("/")
  root "new_design#home"
end
