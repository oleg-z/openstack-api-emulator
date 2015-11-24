class VSphereDriver::OpenstackVM
  attr_reader :vm_id
  attr_reader :vm_name
  attr_reader :vm_ip

  def self.is_uuid?(id)
    !(id =~ /[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}/).nil?
  end

  def initialize(options = {})
    @connection  = options[:connection]
    @vm_id       = options[:id]
    @logger      = Rails.logger
  end

  def exist?
    !vm_obj.nil?
  end

  def cloning_in_progress?
    task_id = Rails.cache.read(@vm_id) || (return false)
    task = vsphere.find_task(task_id) || (return false)
    return true if task.info.state != "success"
    return true if vm_obj(reload: true).nil? || state == "STOPPED"

    Rails.cache.delete(@vm_id)
    return false
  end

  def state
    return "STOPPED" if vm_obj.power_state == "poweredOff"
    return "ACTIVE" if vm_obj.power_state == "poweredOn"
  end

  def poweron
    return unless exist?
    return if vm_obj.power_state == "poweredOn"

    @logger.info "Starting VM: #{name}"
    vm_obj.start if vm_obj && vm_obj.power_state == "poweredOff"
  end

  def reset
    return unless exist?

    @logger.info "Reset {@vm_id} VM"
    vm_obj.reboot(force: true)
  end

  def poweroff
    return unless exist?
    return if vm_obj.power_state == "poweredOff"

    vm_obj.stop(:force => true)
    vm_obj.wait_for(60, 5) { power_state == "poweredOff" }
    @logger.info "VM is powered off"
  end

  def destroy
    return unless exist?

    @logger.info "Destroy VM"
    vm_obj.destroy
    @logger.info "VM is destroyed"
  rescue => e
    raise Exception.new("Failed to destroy instance: #{e.to_s}", exception: e)
  end

  def clone(options = {})
    vm_name      = options[:name]
    vm_flavor    = options[:size]
    vm_network   = options[:network]
    dest_folder  = options[:dest_folder] || config.base_folder
    mark_as_template = options[:mark_as_template] || false

    vm_spec = nil
    vm_spec = config.vm_flavors[vm_flavor] if vm_flavor

    clone_spec = build_clone_spec(
      spec: vm_spec,
      network: vm_network
    )

    clone_spec["name"] = vm_name
    clone_spec["wait"] = false

    ensure_folder_exist(dest_folder)
    clone_spec["dest_folder"] = dest_folder

    if mark_as_template
      clone_spec["power_on"] = false
    else
      clone_spec["resource_pool"] = find_resource_pool(options[:resource_pool])
      clone_spec["power_on"] = true
    end

    @logger.info "Creating VM '#{vm_name}' using '#{@vm_id}' template"
    resp = vsphere.vm_clone_extended(clone_spec)
    @logger.info "Clone task is initiated'#{vm_name}' using '#{@vm_id}' template"

    Rails.cache.write(clone_spec["instanceUuid"], resp["task_ref"])

    @logger.info("'#{vm_name}' server id: #{clone_spec["instanceUuid"]}")
    if mark_as_template
      VSphereDriver::OpenstackImage.new(connection: @connection, id: clone_spec["instanceUuid"])
    else
      VSphereDriver::OpenstackVM.new(connection: @connection, id: clone_spec["instanceUuid"])
    end
  end

  def create_template(template_name, options = {})
    dest_folder  = options[:dest_folder] || config.templates_folder

    clone(
      name: template_name,
      dest_folder: dest_folder,
      mark_as_template: true
    )
  end

  private

  def vsphere
    @connection.connection
  end

  def config
    @connection.config
  end

  def vm_obj(options = {})
    @obj = nil if options[:reload]
    @obj ||= self.class.is_uuid?(@vm_id) ? vsphere.servers.get(@vm_id) : vsphere.servers.find_by_path(@vm_id)
  end

  def method_missing(m, *args, &block)
    if exist? && vm_obj.respond_to?(m)
      return vm_obj.send(m, *args)
    end
    fail "Method #{m} doesn't exist"
  end

  def ensure_folder_exist(folder)
    @logger.info("Ensure folder '#{folder}' exists")
    unless vsphere.folders.exist?(folder)
      @logger.info("Creating vm folder /#{folder}")
      vsphere.create_folder(config.datacenter, "/", folder)
    end
  end

  def find_resource_pool(resource_pool)
    return nil unless resource_pool
    @logger.debug("Detecting resource pool location")
    vsphere.list_clusters.detect do |c|
      if vsphere.list_resource_pools(datacenter: c[:datacenter], cluster: c[:name]).detect { |r| r[:name] == resource_pool }
        return [c[:name], resource_pool]
      end
    end
    return nil
  end

  def build_clone_spec(options)
    vm_spec          = options[:spec]
    network          = options[:network]

    template_path = nil
    if self.class.is_uuid?(@vm_id)
      template_path = @vm_id
    elsif template = vsphere.templates.find_by_path(@vm_id)
      template_path = template.path
    elsif server = vsphere.servers.find_by_path(@vm_id)
      template_path = server.id
    end

    clone_spec = {
      "uuid"          => SecureRandom.uuid,
      "instanceUuid"  => SecureRandom.uuid,
      "template_path" => template_path,
      "datacenter"    => config.datacenter
    }

    clone_spec["extraConfig"] = {
      "uuid" => clone_spec["uuid"],
      "instanceUuid" => clone_spec["instanceUuid"]
    }

    clone_spec["annotation"] = options["annotation"].to_s
    clone_spec["annotation"] += "\ninstance_uuid: #{clone_spec["instanceUuid"]}"
    clone_spec["annotation"].strip!

    clone_spec["numCPUs"]    = vm_spec['cpu'].to_i if defined?(vm_spec["cpu"])
    clone_spec["memory"]     = vm_spec['memory'].to_i * 1024 if defined?(vm_spec["memory"])
    clone_spec["interfaces"] = [Fog::Compute::Vsphere::Interface.new(network: "cd15-collect", summary: "cd15-collect")] if network
    clone_spec["volumes"]    = [Fog::Compute::Vsphere::Volume.new(thin: true, size_gb: vm_spec["disk"].to_i)] if defined?(vm_spec["disk"])

    clone_spec
  end

  def mark_as_template
    vm_obj.mark_as_template
    @template_id = vm_obj.id
    @obj = nil
    @vm_id = nil
  end
end
