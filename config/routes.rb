Rails.application.routes.draw do

  resources :keystone do
    collection do
      get 'v2.0/' => 'keystone#information'
      post 'v2.0/tokens' => 'keystone#tokens'
    end
  end

  resources :nova do
    collection do
      get    'v2/:tenant_id/extensions'      => 'nova#extensions'
      get    'v2/:tenant_id/flavors/:flavor' => 'nova#flavors', :constraints => { :flavor => /[a-z0-9.]+/ }

      post   'v2/:tenant_id/servers'        => 'nova#servers_new'
      get    'v2/:tenant_id/servers/:server_id' => 'nova#servers_get'
      delete 'v2/:tenant_id/servers/:server_id' => 'nova#servers_delete'

      post   'v2/:tenant_id/servers/:server_id/action' => 'nova#servers_action'

      get    'v2/:tenant_id/os-keypairs'               => 'nova#os_keypairs'
      post   'v2/:tenant_id/os-keypairs'               => 'nova#post_os_keypairs'
      delete 'v2/:tenant_id/os-keypairs/:keypair_name' => 'nova#delete_os_keypairs'

      get    'v2/:tenant_id/images/:image_id'        => 'nova#images_get'
      delete 'v2/:tenant_id/images/:image_id'        => 'nova#images_delete'

      post   'v2/:tenant_id/images/:image_id/action' => 'nova#images_action'
    end
  end

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
