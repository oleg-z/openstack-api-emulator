class KeystoneController < ActionController::Base
  def tenants
  end

  def tokens
    @username = params[:auth][:passwordCredentials][:username]
    @password = params[:auth][:passwordCredentials][:password]
    @tenant_name = params[:auth]["tenantName"]

    @session = KeystoneSession.new
    @session.start(username: @username, password: @password)
    return render json: "Failed to authenticate to vsphere using provided credentials", status: 403 unless @session
  end

  def information

  end
end
