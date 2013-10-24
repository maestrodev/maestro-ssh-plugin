# Copyright 2011© MaestroDev.  All rights reserved.
require File.join(File.dirname(__FILE__), 'ssh_common')
require 'net/scp'

module MaestroDev
  module Plugin
    class SCPWorker < SSHCommon
      def validate_parameters
        # Making sure to let the base class do its initial validation of all the things
        errors = super
  
        # Now do the things that are specific to me
        @path = get_field('path', '')
        @remote_path = get_field('remote_path', '')
  
        errors << "Invalid path, not found: '#{@path}'" if @path.empty? || (@operation == :upload && !File.exists?(@path))
        errors << 'Empty remote_path' if @remote_path.empty?

        raise ConfigError, "Configuration Errors: #{errors.join(', ')}" unless errors.empty?
      end
  
      def upload
        @operation = :upload
  
        do_ssh do |session|
          write_output("\nBegin Uploading File #{@path} to #{@user}@#{@host}:#{@port}:#{@remote_path}", :buffer => true)
          session.scp.upload!(@path, @remote_path) do |ch, name, sent, total|
            write_output("\n#{name}: #{sent}/#{total}", :buffer => true)
          end
  
          write_output("\nFinished Uploading File #{@path}", :buffer => true)
          set_field('output', "Successfully Uploaded File #{@path} To #{@user}@#{@host}:#{@remote_path}")
        end
      end
  
      def download
        @operation = :download
  
        do_ssh do |session|
          write_output("Begin Downloading File #{@user}@#{@host}:#{@port}:#{@remote_path} to #{@path}", :buffer => true)
          session.scp.download!(@remote_path, @path) do |ch, name, sent, total|
            write_output("\n#{name}: #{sent}/#{total}", :buffer => true)
          end
  
          write_output("\nFinished Downloading File #{@path}", :buffer => true)
          set_field('output', "Successfully Uploaded File #{@path} To #{@user}@#{@host}:#{@remote_path}")
        end
      end
    end
  end
end
