Rails.application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".
  get "/api/start_data_loading"
  get "/api/start_ping"
  get "/api/start_sync"
end
