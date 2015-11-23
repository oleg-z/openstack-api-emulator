Apipie.configure do |config|
  config.app_name                = "OpenstackApi"
  config.api_base_url            = "/"
  config.doc_base_url            = "/api"
  # where is your API defined?
  config.api_controllers_matcher = "#{Rails.root}/app/controllers/**/*.rb"
end
