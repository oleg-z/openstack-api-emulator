Rails.application.configure do
  config.log_level  = :info
  config.eager_load = false

  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  config.assets.compress = true # Do not compress assets
  config.assets.debug = false   # Expands the lines which load the assets

  config.assets.compile = false
end
