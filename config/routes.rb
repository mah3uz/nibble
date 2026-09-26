# Your routes. Nibble's are drawn around these: its fixed routes first, its catch-all last.
Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # The home page's install command fetches this, so it answers before Nibble's catch-all sees it.
  get "install.sh", to: "install#show", format: false

  namespace :api do
    namespace :v1 do
      get "changelogs", to: "changelogs#index"
      # An installation has its feed address compiled in, so this one answers until none of them hold it.
      get "releases", to: "changelogs#index"
    end
  end
end
