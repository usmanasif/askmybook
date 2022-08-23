Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # get "/questions/load_book", to: 'questions#load_book'
      post "/questions", to: 'questions#handle_question'
    end
  end
  # ...
end
