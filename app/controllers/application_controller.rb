class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def documentation
    public_key_path = File.join(Rails.root, "config", "ssh-keys", "#{Rails.configuration.api["private_key"]}.pub")
    @public_key = File.read(public_key_path)
  end
end
