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
      DEFAULT_TIMEOUT = 60
      DEFAULT_PORT = 22

      private

      def validate_parameters
        @host = get_field('host', '')
        @port = get_int_field('port', DEFAULT_PORT)
        @user = get_field('user', '')
        @key_path = get_field('key_path', '')
        @key_path = File.expand_path(@key_path) unless @key_path.empty?
        @key_type = get_field('key_type', DEFAULT_KEY_TYPE)
        @password = get_field('password')
        @retries = get_int_field('retries', DEFAULT_RETRIES)
        @wait = get_int_field('wait', DEFAULT_WAIT)
        @timeout = get_int_field('timeout', DEFAULT_TIMEOUT)
        @update_host_key = get_boolean_field('update_host_key')

        errors = []
        errors << 'Invalid empty host' if @host.empty?
        errors << 'Invalid empty user' if @user.empty?
        unless @key_path.empty?
          errors << "Invalid key, not found: #{@key_path}" unless File.exists?(@key_path)
          errors << "Invalid key, it is a directory: #{@key_path}" if File.directory?(@key_path)
        end

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

        options = {
          :host_key => @key_type,
          :password => @password,
          :port => @port == 0 ? DEFAULT_PORT : @port,
          :timeout => @timeout,
        }
        options[:keys] = [@key_path] unless @key_path.empty?

        session = start(@host, @user, options, @retries, @wait)
        yield(session)
      rescue PluginError
        # Re-raise
        raise
      rescue Exception => e
        raise PluginError, "Error in SSH connection: #{e.class} #{e}\n" + e.backtrace.join("\n")
      ensure
        close
      end

      def start(server, user, options, retries, wait)
        trys = 0

        while trys <= retries
          trys += 1
          start = Time.now

          begin
            write_output("\nConnect attempt #{trys}/#{retries}")
            options = {
              :compression => 'zlib',
              :auth_methods => ["publickey", "hostbased", "password"]
            }.merge(options)

            begin
              @session = Net::SSH.start(server, user, options)
            rescue Net::SSH::HostKeyMismatch => e
              if @update_host_key
                write_output("\nUpdating changed host-key")
                e.remember_host!

                # Easy retry... if it still fails, it'll drop thru to default exception handler
                @session = Net::SSH.start(server, user, options)
              else
                # If update_host_key not set, let this error propagate
                raise PluginError, "Host key mismatch - this happens when the host being connected to " +
                  "is not the same as was connected to previously.  In some cases this is expected, " +
                  "in other cases it can be cause for concern.\nIf acceptable, set the 'update_host_key' " +
                  "property to true, and Maestro will attempt to update the local copy of the " +
                  "host-key when/if it changes."
              end
            end

            write_output("\nConnected (#{Time.now - start}s)", :buffer => true)
            trys = retries + 1
          rescue Errno::ECONNREFUSED => e
            write_output("\nConnection Refused (#{Time.now - start}s). Sleeping for #{wait}s")
            sleep wait
            raise PluginError, "Failed To Connect To #{server} After #{trys} Trys (ECONNREFUSED)" if trys >= retries
          rescue Timeout::Error => e
            write_output("\nConnection timed out (#{Time.now - start}s). Sleeping for #{wait}s")
            sleep wait
            raise PluginError, "Failed To Connect To #{server} After #{trys} Trys (Timeout::Error)" if trys >= retries
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
