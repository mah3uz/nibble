Rails.application.routes.draw do
  if Rails.env.development?
    # Redirect to localhost from 127.0.0.1 to use same IP address with Vite server
    constraints(host: "127.0.0.1") do
      get "(*path)", to: redirect { |params, req| "#{req.protocol}localhost:#{req.port}/#{params[:path]}" }
    end
  end

  # Rails' own endpoint takes uploads from anyone, so it's closed; the Control Plane's checks who is uploading.
  post "rails/active_storage/direct_uploads", to: ->(_env) { [ 404, { "content-type" => "text/plain" }, [ "Not Found" ] ] }

  scope path: "admin" do
    resource :session do
      collection do
        get :challenge
        post :challenge, action: :verify_challenge
        post "passkey/options", action: :passkey_options
        post "passkey", action: :passkey
        post :elevate
      end
    end
    resources :passwords, param: :token
  end

  namespace :api do
    namespace :v1 do
      get "collections/:collection_handle/entries", to: "entries#index"
      get "entries/:id", to: "entries#show"
      get "taxonomies/:taxonomy_handle/terms", to: "terms#index"
      get "terms/:id", to: "terms#show"
      get "globals/:id", to: "globals#show"
      get "navigation/:id", to: "navigation#show"
      get "assets/:id", to: "assets#show"
      get "routes", to: "routes#show"
      get "schema", to: "schema#show"
      get "health", to: "health#show"
    end
  end

  namespace :admin do
    root "dashboard#show"
    post "direct_uploads", to: "direct_uploads#create", as: :direct_uploads
    patch "preferences", to: "preferences#update", as: :preferences
    scope "account", as: :account do
      post "two_factor", to: "two_factor#create", as: :two_factor
      post "two_factor/confirm", to: "two_factor#confirm", as: :confirm_two_factor
      post "two_factor/recovery_codes", to: "two_factor#recovery_codes", as: :two_factor_recovery_codes
      post "two_factor/recovery_codes/ack", to: "two_factor#acknowledge_recovery_codes", as: :ack_two_factor_recovery_codes
      delete "two_factor", to: "two_factor#destroy"
      resources :passkeys, only: %i[create update destroy] do
        post :options, on: :collection
      end
    end
    post "actions", to: "actions#run", as: :actions
    resources :roles, except: %i[show]
    resources :api_tokens, only: %i[index create destroy], path: "api-tokens"
    resources :users, except: %i[show new] do
      member do
        post :send_reset
        delete "sessions/:session_id", action: :revoke_session, as: :session
      end
    end
    resources :webhooks, except: %i[show] do
      member do
        post :test
        post :enable
        post :roll_secret
        post "deliveries/:delivery_id/resend", action: :resend, as: :resend_delivery
      end
    end
    get "forms", to: "forms#index", as: :forms
    get "forms/:handle", to: "forms#show", as: :form
    get "forms/:handle/submissions/:id", to: "form_submissions#show", as: :form_submission
    delete "forms/:handle/submissions/:id", to: "form_submissions#destroy"
    post "forms/:handle/submissions/:id/deliveries/:key/retry", to: "form_submissions#retry", as: :retry_form_submission_delivery,
      constraints: { key: %r{[^/]+} }
    get "forms/:handle/submissions/:submission_id/files/:id", to: "form_files#show", as: :form_submission_file

    scope "collections/:handle", as: :collection do
      root to: "collections#show"
      resources :entries, only: %i[new create edit update], path: "entries" do
        member do
          post :publish
          post :unpublish
          post :submit
          post :approve
          post :reject
          post :trash
          post :revert
          delete :draft, action: :discard_draft
        end
        collection { post :reorder }
        member { match :preview, via: %i[get post], to: "previews#show" }
        resources :revisions, only: :index do
          member { post :restore }
        end
        resources :comments, only: %i[index create destroy]
      end
    end

    resource :account, only: %i[edit update]
    resources :notifications, only: %i[index update destroy]
    put "notifications", to: "notifications#update", as: :read_notifications
    delete "notifications", to: "notifications#destroy", as: :clear_notifications
    get "search", to: "search#index", as: :search
    get "link_suggestions", to: "link_suggestions#index", as: :link_suggestions
    resources :blueprints, only: %i[index show], param: :handle, constraints: { handle: /[^\/]+/ }
    resources :globals, only: %i[index edit update], param: :handle
    post "globals/:handle", to: "globals#update"
    resources :navigation, only: %i[index edit update], param: :handle, controller: "navigation"
    resources :trash, only: :index do
      member do
        post :restore
        delete :purge
      end
    end
    resources :media, only: %i[index show create update destroy] do
      collection do
        post :bulk
        post :folders, action: :create_folder
        patch :folders, action: :rename_folder
        delete :folders, action: :destroy_folder
      end
      member do
        post :duplicate
        post :reupload
        post :replace
      end
    end
    get "updates", to: "updates#show", as: :admin_updates
    patch "updates", to: "updates#update"
    resources :redirects, only: %i[index create update destroy]
    resources :not_found_paths, only: %i[index destroy], path: "404s"
    resource :utilities, only: :show, controller: "utilities" do
      post :clear_cache
      post :purge_cache
      post :rebuild_search
      get :cache
      get :search
      get :schema
      get :backups
      get :audit
      get :jobs
      get :health
      get :content
      get "content/export", action: :export_content, as: :export_content
      post "content/import", action: :import_content, as: :import_content
      post "jobs/:id/retry", action: :retry_job, as: :retry_job
      delete "jobs/:id", action: :discard_job, as: :discard_job
    end

    scope "taxonomies/:handle", as: :taxonomy do
      root to: "taxonomies#show"
      resources :terms, only: %i[new create edit update] do
        member { post :trash }
      end
    end
    scope "nibble", module: "nibble_api", as: "nibble" do
      get "relationships/:type", to: "relationships#index", as: :relationships
      post "markdown/preview", to: "markdown#preview", as: :markdown_preview
      if Rails.env.local?
        get "playground", to: "playground#show", as: :playground
        post "playground/validate", to: "playground#validate", as: :playground_validate
      end
    end
  end

  post "forms/:handle", to: "forms#create", format: false, constraints: { handle: /[a-z0-9_-]+/ }, as: :form_submissions
  get "media/:uuid/:filename", to: "asset_files#show", format: false, constraints: { filename: /[^\/]+/ }, as: :asset_file
  get "media/:uuid/:preset/:filename", to: "asset_files#show", format: false, constraints: { filename: /[^\/]+/ }, as: :asset_transform
  get "robots.txt", to: "sitemaps#robots", format: false
  get "sitemap.xml", to: "sitemaps#index", format: false
  get "sitemap-:handle.xml", to: "sitemaps#show", format: false, constraints: { handle: /[a-z0-9_-]+/ }
  get "feed.xml", to: "feeds#index", format: false
  get "feed-:handle.xml", to: "feeds#show", format: false, constraints: { handle: /[a-z0-9_-]+/ }
end
