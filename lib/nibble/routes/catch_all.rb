Rails.application.routes.draw do
  root "site#show"
  get "*path", to: "site#show", format: false, constraints: ->(request) { !request.path.start_with?("/rails/") }
end
