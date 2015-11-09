require_relative "vcenter/fog.rb"

class VCenterDriver
  require_relative "vcenter/vcenter_config.rb"

  attr_reader :vm_id
  attr_reader :vm_name
  attr_reader :vm_ip

  def self.list_flavors
    return Config.new.vm_flavors.keys.sort
  end

  def self.networks
    return [] unless enabled?
    networks = self.new.vcenter.networks.collect { |n| n.name }
    Cache.set("#{self.inspect}::networks", networks, :expiry => 5.minutes)
  rescue
    []
  end

  def initialize(options = {})
    @username    = options[:username]
    @password    = options[:password]
    @config      = options[:config]
    @vm_id       = options[:vm_id] || options[:template_id]

    unless @config
      @config = Config.new(username: @username, password: @password)
    end

    @logger = Rails.logger
  end

  def vcenter
    @vcenter ||= Fog::Compute.new(@config.connection_hash)
  end

  def authenticate
    vcenter.reload
  rescue
    return false
  end

  def exist?
    vm_obj != nil
  end

  def method_missing(m, *args, &block)
    if exist? && vm_obj.respond_to?(m)
      return vm_obj.send(m)
    end
    fail "Method #{m} doesn't exist"
  end

  def find_vm_by_path(vm_path)
    vm = vcenter.servers.find_vm_by_path(vm_path)
    raise ::InvalidInputError, "VM '#{vm_path}' doesn't exist" if vm == nil
    vm
  end

  def get_template
    self.class.new(template_id: template_id, config: @config)
  end

  def build_clone_spec(vm_spec, vm_template_path)
    #vm_template = find_template(vm_template_path)

    datacenter  = @config.datacenter
    dest_folder = @config.base_folder.to_s
    begin
      @logger.info("Creating vm folder /#{dest_folder}")
      vcenter.create_folder(datacenter, "/", dest_folder)
    rescue RbVmomi::VIM::DuplicateName
    end

    template_vm = vm_template_path.include?("/") ? find_vm_by_path(vm_template_path) : vcenter.servers.get(vm_template_path)

    clone_spec = {
      "template_path" => template_vm.id,
      "datacenter"    => datacenter,
      "dest_folder"   => dest_folder,
      "numCPUs"       => vm_spec['cpu'].to_i,
      "memoryMB"      => vm_spec['memory'].to_i * 1024,
      "power_on"      => false
    }

    unless @config.resource_pool.to_s.empty? or @config.cluster.to_s.empty?
      clone_spec["resource_pool"] = [@config.cluster, @config.resource_pool]
    end

    clone_spec
  end

  ##############
  # Manages VM #
  ##############
  def create(options = {})

    vm_name      = options[:name]
    vm_template  = options[:template]
    vm_flavor    = options[:size]
    vm_network   = options[:network]

    vm_spec      = @config.vm_flavors[vm_flavor]

    clone_spec = build_clone_spec(vm_spec, "openstack_templates/#{vm_template}")
    clone_spec["name"] = vm_name

    @logger.info "Create VM #{vm_name} using #{vm_template} template"

    vm_info = vcenter.vm_clone(clone_spec)["new_vm"]
    vm = self.class.new(vm_id: vm_info["id"], config: @config)
    @logger.info("VM #{vm_name} created")

    sleep 5

    vm.disk_size(vm_spec["disk"].to_i)
    vm.network(vm_network) if vm_network

    vm
  end

  def clone_to_template(template_name)
    templates_folder = "openstack_templates"
    begin
      @logger.info("Creating vm folder /#{templates_folder}")
      vcenter.create_folder(datacenter, "/", templates_folder)
    rescue RbVmomi::VIM::DuplicateName
    end

    clone_spec = build_clone_spec({'memory' => 1, 'cpu' => 1}, vm_obj.id)
    clone_spec["name"] = template_name
    clone_spec["dest_folder"] = templates_folder

    @logger.info "Creating template #{template_name}"
    vm_info = vcenter.vm_clone(clone_spec)["new_vm"]
    vm = self.class.new(vm_id: vm_info["id"], config: @config)

    @logger.info("Template #{template_name} is created")
    vm
  end

  def get(vm_id)
    self.class.new(vm_id: vm_id, config: @config)
  end

  def network(network_name)
    #@logger.info "Adding network adapter"
    #vm_obj.add_network_card

    @logger.info "Setting VM network to #{network_name}"
    vm_obj.set_network(network_name: network_name, adapter_index: 0)
  end

  def disk_size(value)
    @logger.info "Set hard drive size to #{value}Gb"
    vm_obj.set_disk_size(size: value)
  end

  # Power on created vm
  def poweron
    unless exist?
      @logger.info "VM #{@vm_id} doesn't exist"
      return self
    end

    @logger.info "Starting VM: #{name}"
    vm_obj.start if vm_obj && vm_obj.power_state == "poweredOff"

    self
  end

  # Wait for VM obtains IP address
  def wait_ip(timeout = 600)
    @logger.info "Wait for VM IP address for #{timeout} seconds"

    @vm_ip = vm_obj.wait_for(timeout, 10) {
      ready? && (ip_address = public_ip_address)
      ip_address
    }

    @vm_ip = vm_obj.public_ip_address
    raise InfrastructureError, "Failed to obtain IP address within #{timeout} seconds" unless @vm_ip
    @logger.info "VM IP address: #{@vm_ip}"
    self
  end

  def state
    return "STOPPED" if vm_obj.power_state == "poweredOff"
    return "ACTIVE" if vm_obj.power_state == "poweredOn"
  end

  def reset
    @logger.info "Reset {@vm_id} VM"
    unless exist?
      @logger.info "VM #{@vm_id} doesn't exist"
      return self
    end

    vm_obj.reboot(force: true)
    self
  end

  def poweroff
    @logger.info "Power off VM"
    unless exist?
      @logger.info "VM doesn't exist"
      return self
    end
    return self if vm_obj.power_state == "poweredOff"

    vm_obj.stop(:force => true)
    vm_obj.wait_for(60, 5) {
      power_state == "poweredOff"
    }
    @logger.info "VM is powered off"
    self
  end

  # Destroy virtual machine
  def destroy
    unless exist?
      @logger.info "VM doesn't exist"
      return self
    end

    @logger.info "Destroy VM"
    vm_obj.destroy
    @logger.info "VM is destroyed"

    self
  rescue => e
    raise Exception.new("Failed to destroy instance: #{e.to_s}", exception: e)
  end

  def mark_as_template
    vm_obj.mark_as_template
    @template_id = vm_obj.id
    @obj = nil
    @vm_id = nil
  end

  def vm_obj
    @obj ||= vcenter.servers.get(@vm_id) if @vm_id
  end
end
