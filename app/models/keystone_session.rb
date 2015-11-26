class KeystoneSession
  attr_reader :session_id
  attr_reader :username
  attr_reader :password
  attr_reader :expires_at
  attr_reader :issued_at

  def initialize(options = {})
    @session_id = options[:session_id]
    @username   = options[:username]
    @password   = options[:password]
  end

  def start(options)
    @username = options[:username]
    @password = options[:password]

    @token = VSphereDriver.new(username: @username, password: @password).authenticate
    return nil unless @token

    @session_id = SecureRandom.uuid
    @expires_at = Time.now.getutc+ 86400
    @issued_at  = Time.now.getutc
    Rails.cache.write("keystone:#{@session_id}", "#{username}::#{password}")
    @session_id
  end

  def verify
    @token = VSphereDriver.new(username: @username, password: @password).authenticate
  end

  def self.get(session_id)
    username, password = Rails.cache.read("keystone:#{session_id}").to_s.split("::")
    return nil unless username && password
    @session = KeystoneSession.new(session_id: session_id, username: username, password: password)
    return @session if @session.verify
  end
end
