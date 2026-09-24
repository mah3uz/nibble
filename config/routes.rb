# Your routes. Nibble's are drawn around these: its fixed routes first, its catch-all last.
Rails.application.routes.draw do
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
