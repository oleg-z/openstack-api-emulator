class NovaController < ActionController::Base
  def extensions
  end

  def flavors
    @flavor_id = params[:flavor]

    unless Rails.configuration.vsphere["vm_flavors"][@flavor_id.to_s]
      return render :json => { error: 'Flavor not found' }, :status => 404
    end
  end

  def os_keypairs
  end

  def post_os_keypairs
    @keypair_name = params[:keypair][:name]

    private_key_path = File.join(Rails.root, "config", "ssh-keys", Rails.configuration.api["private_key"])
    public_key_path = "#{private_key_path}.pub"

    @private_key = File.read(private_key_path)
    @public_key = File.read(public_key_path)

    render :os_keypair
  end

  def delete_os_keypairs
    render nothing: true, status: 202
  end

  def servers_new
    @username, @password = request.headers["HTTP_X_AUTH_TOKEN"].split("::")

    flavor   = params["server"]["flavorRef"]
    template = params["server"]["imageRef"]
    vm_name  = params["server"]["name"]
    network  = params["server"]["networks"].shift["uuid"]

    @vm = vcenter_driver.create(
      name: vm_name,
      size: flavor,
      network: network,
      template: template
    )
    @vm.poweron
    @vm.wait_ip

    render :servers_new, status: 202
  end

  def servers_get
    @username, @password = request.headers["HTTP_X_AUTH_TOKEN"].split("::")
    v = VCenterDriver.new(username: @username, password: @password)
    @vm = v.get(params[:server_id])

    render nothing: true, status: 404 unless @vm.exist?
  end

  def servers_action
    @template_name = params["createImage"]["name"]
    @server = vcenter_driver.get(params[:server_id])
    @server.poweroff
    @template = @server.clone_to_template(@template_name)

    response.headers["Location"] = "http://localhost:3000/nova/v2/images/#{@template.id}"
    render nothing: true, status: 202
  end

  def servers_delete
    @vm = vcenter_driver.get(params[:server_id])
    @vm.poweroff
    @vm.destroy
    render nothing: true, status: 204
  end

  def images_action
    binding.pry
  end

  def images_get
    @template = vcenter_driver.get(params[:image_id])
  end

  def images_delete
    binding.pry
  end

  def vcenter_driver
    @username, @password = request.headers["HTTP_X_AUTH_TOKEN"].split("::")
    @vcenter ||= VCenterDriver.new(username: @username, password: @password)
  end
end
