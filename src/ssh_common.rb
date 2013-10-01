# Copyright 2011© MaestroDev.  All rights reserved.
require 'rubygems'
require 'andand'
require 'maestro_plugin'
require 'net/ssh'

module MaestroDev
  module Plugin

    class SSHCommon < Maestro::MaestroWorker
      DEFAULT_KEY_TYPE = 'ssh-rsa'
      DEFAULT_RETRIES = 10
      DEFAULT_WAIT = 10
      DEFAULT_PORT = 22

      private

      def validate_parameters
        @host = get_field('host', '')
        @port = get_int_field('port', DEFAULT_PORT)
        @user = get_field('user', '')
        @key_path = get_field('key_path', '')
        @key_type = get_field('key_type', DEFAULT_KEY_TYPE)
        @password = get_field('password')
        @retries = get_int_field('retries', DEFAULT_RETRIES)
        @wait = get_int_field('wait', DEFAULT_WAIT)
        @update_host_key = get_boolean_field('update_host_key')

        errors = []
        errors << 'Invalid host' if @host.empty?
        errors << 'Invalid user' if @user.empty?
        errors << 'Invalid key, not found' if !@key_path.empty? and !File.exists?(@key_path)

        errors
      end

      # Call me with a block, and I'll connect to the server, run your block, and close the connection before leaving
      # Will call 'validate_parameters' which should be overridden if req'd as such
      # def validate_parameters
      #   super
      #
      #   ... my validation here
      # end
      def do_ssh
        validate_parameters

        auth_types = []
        auth_types << 'PASSWORD' if @password && !@password.empty?
        auth_types << "KEY (#{@key_type})"

        connection = @host
        connection += " port #{@port}" if @port != 0

        write_output("\nConnecting to #{connection} as #{@user} using auth [#{auth_types.join(', ')}]")

        session = start(@host,
          @user,
          @key_path, 
          @key_type, 
          @password,
          (@port == 0 ? DEFAULT_PORT : @port),
          @retries,
          @wait)
        yield(session)
      rescue PluginError
        # Re-raise
        raise
      rescue Exception => e
        raise PluginError, "Error in SSH connection: #{e.class} #{e}\n" + e.backtrace.join("\n")
      ensure
        close
      end

      def start(server, user, key_path, key_type, password, port, retries, wait)
        trys = 0

        while trys <= retries 
          trys += 1

          begin
            write_output("\nConnect attempt #{trys}/#{retries}")
            params = {:host_key => key_type,
                      :password => password,
                      :compression => 'zlib',
                      :port => port,
                      :auth_methods => ["publickey", "hostbased", "password"]}

            if !key_path.empty?
              params[:keys] = [ key_path ]
            end

            begin
              @session = Net::SSH.start(server, user, params)
            rescue Net::SSH::HostKeyMismatch => e
              if @update_host_key
                write_output("\nUpdating changed host-key")
                e.remember_host!

                # Easy retry... if it still fails, it'll drop thru to default exception handler
                @session = Net::SSH.start(server, user, params)
              else
                # If update_host_key not set, let this error propagate
                raise PluginError, "Host key mismatch - this happens when the host being connected to " +
                  "is not the same as was connected to previously.  In some cases this is expected, " +
                  "in other cases it can be cause for concern.\nIf acceptable, set the 'update_host_key' " +
                  "property to true, and Maestro will attempt to update the local copy of the " +
                  "host-key when/if it changes."
              end
            end

            write_output("\nConnected", :buffer => true)
            trys = retries + 1
          rescue Errno::ECONNREFUSED => e
            write_output("\nConnection Refused")
            sleep wait
            raise PluginError, "Failed To Connect To #{server} After #{trys} Trys (ECONNREFUSED)" if trys >= retries
          rescue Net::SSH::AuthenticationFailed => e
            raise PluginError, "Authentication Failed - please check username, password, and any public-keys. #{e.class} #{e}"
          end
        end
        @session
      end

      def close()
        @session.andand.close if !@session.andand.closed?
      end
    end
  end
end
