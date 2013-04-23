# Copyright 2011© MaestroDev.  All rights reserved.
require 'rubygems'
require 'andand'
require 'maestro_plugin'
require 'net/ssh'

module MaestroDev
  class SSHError < RuntimeError; end

  class SSHCommon < Maestro::MaestroWorker
    DEFAULT_KEY_TYPE = 'ssh-rsa'
    DEFAULT_RETRIES = 10
    DEFAULT_WAIT = 10
    DEFAULT_PORT = 22
    
    private
    
    def validate_parameters
      @host = get_field('host', '')
      @port = get_field('port', 0)
      @user = get_field('user', '')
      @key_path = get_field('key_path', '')
      @key_type = get_field('key_type', DEFAULT_KEY_TYPE)
      @password = get_field('password')
      @retries = get_field('retries', DEFAULT_RETRIES)
      @wait = get_field('wait', DEFAULT_WAIT)

      raise 'Invalid host' if @host.empty?
      raise 'Invalid user' if @user.empty?
      raise 'Invalid key, not found' if !@key_path.empty? and !File.exists?(@key_path)
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
      
      write_output "\nConnecting to #{connection} as #{@user} using auth [#{auth_types.join(', ')}]"
      
      start(@host,
        @user,
        @key_path, 
        @key_type, 
        @password,
        (@port == 0 ? DEFAULT_PORT : @port),
        @retries,
        @wait)

      set_field('output', '')
      yield(@session)
    rescue Exception => e
      set_error("Error in SSH connection: #{e.class} #{e}")
    ensure
      close
    end


    def start(server, user, key_path, key_type, password, port, retries, wait)
      trys = 1

      while trys <= retries 
        begin
          write_output "\nConnect attempt ##{trys}"
          params = {:host_key => key_type,
                    :password => password,
                    :compression => 'zlib',
                    :port => port,
                    :auth_methods => ["publickey", "hostbased", "password"]}

          if !key_path.empty?
            params[:keys] = [ key_path ]
          end

          @session = Net::SSH.start(server, user, params)

          write_output "\nConnected"
          trys = retries + 1
        rescue Errno::ECONNREFUSED => e
          write_output "\nConnection Refused On Try #{trys}"
          sleep wait
          trys += 1
          raise Errno::ECONNREFUSED.new("Failed To Connect To #{server} After #{trys} Trys") if trys >= retries 
        end
      end
      @session
    end

    def close()
      @session.andand.close if !@session.andand.closed?
    end
  end
end
