module Fog
  module Compute
    class Vsphere < Fog::Service
      class Real
        def session_cookie
          @connection.cookie
        end

        def current_session
          @connection.serviceContent.sessionManager.currentSession
        end

        def authenticate
          if @vsphere_username == :session_cookie
            @connection = RbVmomi::VIM.new :host => @vsphere_server,
                                            :port => @vsphere_port,
                                            :path => @vsphere_path,
                                            :ns   => @vsphere_ns,
                                            :rev  => @vsphere_rev,
                                            :ssl  => @vsphere_ssl,
                                            :insecure => true,
                                            :debug => @vsphere_debug,
                                            :cookie => @vsphere_password
          else
            @connection.serviceContent.sessionManager.Login :userName => @vsphere_username,
                                                            :password => @vsphere_password
          end

          current_session
        rescue RbVmomi::VIM::InvalidLogin => e
          raise Fog::Vsphere::Errors::ServiceError, e.message
        end
      end
    end
  end
end
