require 'digest/sha2'
require 'socket'
require 'openssl'

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
  attr_accessor :templates_folder

  attr_accessor :vm_flavors

  def self.instance
    @instance ||= new
  end

  def initialize(options = {})
    ENV["PERL_LWP_SSL_VERIFY_HOSTNAME"] = "0"

    @username = options[:username]
    @password = options[:password]

    # update vcenter config
    @apiHost       = Rails.configuration.vsphere["host"]
    @apiPubkeyHash = Rails.configuration.vsphere["pubkey_hash"]

    @apiUrl        = "https://#{@apiHost}/sdk/vimService.wsdl"

    @cluster           = Rails.configuration.vsphere["cluster"]
    @datacenter        = Rails.configuration.vsphere["datacenter"]
    @datastore         = Rails.configuration.vsphere["datastore"]
    @datastore_cluster = Rails.configuration.vsphere["datastore_cluster"]
    @resource_pool     = Rails.configuration.vsphere["resource_pool"]

    @base_folder       = Rails.configuration.vsphere["base_folder"]
    @templates_folder  = Rails.configuration.vsphere["templates_folder"]

    @vm_flavors        = Rails.configuration.vsphere["vm_flavors"]
  end

  def connection_hash
     return {
      :provider                     => "vsphere",
      :vsphere_username             => @username,
      :vsphere_password             => @password,
      :vsphere_server               => @apiHost,
      :vsphere_ssl                  => true,
      :vsphere_expected_pubkey_hash => calculate_public_key,
      :vsphere_rev                  => 5.1
    }
  end

  # Calculate sha1 of vsphere certificate
  def calculate_public_key
    tcp_client = TCPSocket.new(@apiHost, 443)
    ssl_client = OpenSSL::SSL::SSLSocket.new(tcp_client)
    ssl_client.connect
    cert = OpenSSL::X509::Certificate.new(ssl_client.peer_cert)
    ssl_client.sysclose
    tcp_client.close

    Digest::SHA2.hexdigest(cert.public_key.to_s)
  end
end
