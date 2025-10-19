Rails.application.routes.draw do
  get "/healthz", to: proc { [ 200, { "Content-Type"=>"application/json" }, [ { ok: true }.to_json ] ] }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  post "/worlds", to: "worlds#create"
  get "/worlds/resume", to: "worlds#resume"
  get "/worlds/:id/state", to: "worlds#state"
  post "/worlds/:id/act", to: "worlds#act"
  post "/worlds/:id/point_click", to: "worlds#point_click"
  get  "/worlds/:id/scene", to: "worlds#scene"
  # Serve game assets from public/assets via AssetsController
  get "/assets/:name", to: "assets#show", as: :asset
  post "/worlds/:id/npc/:npc_id/speak", to: "worlds#speak"
  get  "/worlds/resume",      to: "worlds#resume"       # keeps existing query version
  get  "/resume/:code",       to: "worlds#resume_link", as: :resume_link
end
