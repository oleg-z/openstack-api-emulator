class VCenterDriver::Config
  attr_accessor :apiUser
  attr_accessor :apiPassword

  attr_accessor :apiHost
  attr_accessor :apiPubkeyHash
  attr_accessor :apiUrl

  attr_accessor :cluster
  attr_accessor :datacenter
  attr_accessor :datastore
  attr_accessor :datastore_cluster
  attr_accessor :resource_pool
  attr_accessor :base_folder

  attr_accessor :vm_flavors

  def self.instance
    @instance ||= new
  end

  def initialize(options = {})
    ENV["PERL_LWP_SSL_VERIFY_HOSTNAME"] = "0"

    @username = options[:username]
    @password = options[:password]

    # update vcenter config
    @apiHost       = Rails.configuration.vcenter["host"]
    @apiPubkeyHash = Rails.configuration.vcenter["pubkey_hash"]

    @apiUrl        = "https://#{@apiHost}/sdk/vimService.wsdl"

    @cluster           = Rails.configuration.vcenter["cluster"]
    @datacenter        = Rails.configuration.vcenter["datacenter"]
    @datastore         = Rails.configuration.vcenter["datastore"]
    @datastore_cluster = Rails.configuration.vcenter["datastore_cluster"]
    @resource_pool     = Rails.configuration.vcenter["resource_pool"]
    @base_folder       = Rails.configuration.vcenter["base_folder"]

    @vm_flavors        = Rails.configuration.vcenter["vm_flavors"]
  end

  def connection_hash
     return {
      :provider                     => "vsphere",
      :vsphere_username             => @username,
      :vsphere_password             => @password,
      :vsphere_server               => @apiHost,
      :vsphere_ssl                  => true,
      :vsphere_expected_pubkey_hash => @apiPubkeyHash,
      :vsphere_rev                  => 5.1
    }
  end
end
