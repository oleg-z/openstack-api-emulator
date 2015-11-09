class KeystoneController < ActionController::Base
  def tenants

  end

  def tokens
    @username = params[:auth][:passwordCredentials][:username]
    @password = params[:auth][:passwordCredentials][:password]

    v = VCenterDriver.new(username: @username, password: @password)
    @token = v.authenticate
  end

  def information

  end
end
