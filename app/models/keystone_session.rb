class KeystoneSession
  attr_reader :session_id
  attr_reader :username
  attr_reader :password
  attr_reader :connection

  def initialize(options = {})
    @session_id = options[:session_id]
    @username   = options[:username]
    @password   = options[:password]
  end

  def fullName
    @token.fullName
  end

  def userName
    @token.userName
  end

  def issued_at
    @token.loginTime
  end

  def expires_at
    @token.loginTime + 86400
  end

  def start(options)
    if options[:session_cookie]
      @connection = VSphereDriver.new(session_cookie: options[:session_cookie])
      @token = @connection.authenticate
      return nil unless @token
      @session_id = @token.key
    else
      @username = options[:username]
      @password = options[:password]

      @connection = VSphereDriver.new(username: @username, password: @password)
      @token = @connection.authenticate
      return nil unless @token

      @session_id = @token.key
      @expires_at = Time.now.getutc + 86400
      @issued_at  = Time.now.getutc
      Rails.cache.write("keystone:#{@session_id}", @connection.connection.session_cookie)
    end
    @session_id
  end

  def verify
    @connection = VSphereDriver.new(username: @username, password: @password)
    @token = @connection.authenticate
  end

  def self.get(session_id)
    session_cookie = Rails.cache.read("keystone:#{session_id}")
    return nil unless session_id
    @session = KeystoneSession.new
    return @session if @session.start(session_cookie: session_cookie)
  end
end
