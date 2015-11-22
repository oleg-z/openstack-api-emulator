require_relative "extensions/fog.rb"

class VSphereDriver
  require_relative "vsphere_driver/config.rb"
  require_relative "vsphere_driver/openstack_vm"
  require_relative "vsphere_driver/openstack_image"

  attr_reader :config
  attr_reader :connection

  def initialize(options = {})
    @config   = Config.new(username: options[:username], password: options[:password])
    @logger   = Rails.logger
  end

  def authenticate
    @connection = Fog::Compute.new(@config.connection_hash)
    @connection.reload
  rescue Fog::Vsphere::Errors::SecurityError => e
    @logger.error(e)
    return false
  end
end
