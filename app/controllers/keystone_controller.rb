class KeystoneController < ActionController::Base
  after_filter do
    puts response.body if Rails.env.to_s == "development"
  end

  def tenants
    binding.pry
    render json: JSON.parse('{
    "tenants": [
        {
            "id": "Resources",
            "name": "Resources",
            "description": "A description ...",
            "enabled": true
        },
        {
            "id": "Resources",
            "name": "Resources",
            "description": "A description ...",
            "enabled": true
        }
    ],
    "tenants_links": []
}')
  end

  def tokens
    if params[:auth][:passwordCredentials]
      @username = params[:auth][:passwordCredentials][:username]
      @password = params[:auth][:passwordCredentials][:password]
      @tenant_name = params[:auth]["tenantName"] || 'default'

      @session = KeystoneSession.new
      @session.start(username: @username, password: @password)
    end

    if params[:auth][:token]
      @session = KeystoneSession.get(params[:auth][:token][:id])
    end

    return render json: "Failed to authenticate to vsphere using provided credentials", status: 403 unless @session
  end

  def information

  end

  def not_implemented
    Rails.logger.info(params)
    render nothing: true
  end
end
