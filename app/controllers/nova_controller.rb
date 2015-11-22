class NovaController < ActionController::Base
  after_filter do
    puts response.body
  end

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

    flavor        = params["server"]["flavorRef"]
    template      = params["server"]["imageRef"]
    vm_name       = params["server"]["name"]
    network       = params["server"]["networks"].shift["uuid"]
    resource_pool = params["tenant_id"]

    connection = VSphereDriver.new(username: @username, password: @password)
    connection.authenticate
    template_vm = VSphereDriver::OpenstackImage.new(connection: connection, id: template)
    @vm = template_vm.clone(
      name:          vm_name,
      size:          flavor,
      network:       network,
      resource_pool: resource_pool
    )

    render :servers_new, status: 202
  end

  #"source_image1": "2ec68a16-8ad0-4b35-aa52-8af998a7fc3a",

  def servers_get
    @vm = VSphereDriver::OpenstackVM.new(id: params[:server_id], connection: vsphere_connection)

    @cloning_in_progress = @vm.cloning_in_progress?
    return render nothing: true, status: 404 unless @cloning_in_progress || @vm.exist?
  end

  def servers_action
    @template_name = params["createImage"]["name"]
    @vm = VSphereDriver::OpenstackVM.new(id: params[:server_id], connection: vsphere_connection)
    @vm.poweroff
    @template = @vm.create_template(@template_name)

    response.headers["Location"] = "http://localhost:3000/nova/v2/images/#{@template.vm_id}"
    render nothing: true, status: 202
  end

  def servers_delete
    @vm = VSphereDriver::OpenstackVM.new(id: params[:server_id], connection: vsphere_connection)
    return render nothing: true, status: 204 unless @vm.exist?

    @vm.poweroff
    @vm.destroy
    render nothing: true, status: 204
  end

  def images_action
    binding.pry
  end

  def images_get
    @template = VSphereDriver::OpenstackImage.new(id: params[:image_id], connection: vsphere_connection)
    render nothing: true, status: 404 if @template.state == :DELETED
  end

  def images_delete
    @template = VSphereDriver::OpenstackImage.new(id: params[:image_id], connection: vsphere_connection)
    render nothing: true, status: 202 unless @template.exist?

    @template.destroy
    render nothing: true, status: 202
  end

  def vsphere_connection
    @username, @password = request.headers["HTTP_X_AUTH_TOKEN"].split("::")
    @vsphere ||= VSphereDriver.new(username: @username, password: @password)
    @vsphere.authenticate
    @vsphere
  end
end
