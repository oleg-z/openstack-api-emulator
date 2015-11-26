class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def documentation
    public_key_path = File.join(Rails.root, "config", "ssh-keys", "#{Rails.configuration.api["private_key"]}.pub")
    @public_key = File.read(public_key_path)
  end

  private

  def authenticate
    return if @session
    session_id = request.headers["HTTP_X_AUTH_TOKEN"]
    @session = KeystoneSession.get(session_id)

    return render json: "Failed to authenticate using provided session id", status: 403 unless @session
  end

  def vsphere_connection
    return @vsphere if @vsphere
    @vsphere ||= VSphereDriver.new(username: @session.username, password: @session.password)
    @vsphere.authenticate
    @vsphere
  end
end
