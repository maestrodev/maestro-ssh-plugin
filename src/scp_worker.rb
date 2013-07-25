# Copyright 2011© MaestroDev.  All rights reserved.
require File.join(File.dirname(__FILE__), 'ssh_common')
require 'net/scp'

module MaestroDev
  module SSHPlugin
    class SCPWorker < SSHCommon
      def validate_parameters
        # Making sure to let the base class do its initial validation of all the things
        super
  
        # Now do the things that are specific to me
        @path = get_field('path', '')
        @remote_path = get_field('remote_path', '')
  
        raise 'Invalid path, not found' if @path.empty? || (@operation == :upload && !File.exists?(@path))
        raise 'Invalid remote_path' if @remote_path.empty?
      end
  
      def upload
        write_output "\nMaestroDev >> SCP UPLOAD task starting"
  
        @operation = :upload
  
        do_ssh do |session|
          begin
            write_output("\nBegin Uploading File", :buffer => true)
            session.scp.upload!(@path, @remote_path) do |ch, name, sent, total|
              write_output("\n#{name}: #{sent}/#{total}", :buffer => true)
            end
  
            write_output("\nFinished Uploading File #{@path}", :buffer => true)
            set_field('output', "Successfully Uploaded File #{@path} To #{@user}@#{@host}:#{@remote_path}")
          rescue Exception => e
            @error = "SCP Upload Failed: #{e.class} #{e}"
          end
        end
  
        write_output("\nMaestroDev >> SCP UPLOAD task complete")
        set_error(@error) if @error
      end
  
      def download
        write_output "\nMaestroDev >> SCP DOWNLOAD task starting"
  
        @operation = :download
  
        do_ssh do |session|
          begin
            write_output("Begin Downloading File", :buffer => true)
            session.scp.download!(@remote_path, @path) do |ch, name, sent, total|
              write_output("\n#{name}: #{sent}/#{total}", :buffer => true)
            end
  
            write_output("\nFinished Downloading File #{@path}", :buffer => true)
            set_field('output', "Successfully Uploaded File #{@path} To #{@user}@#{@host}:#{@remote_path}")
          rescue Exception => e
            @error = "SCP Downloadload Failed: #{e.class} #{e}"
          end
        end
  
        write_output "\nMaestroDev >> SCP  DOWNLOAD task complete"
        set_error(@error) if @error
      end
    end
  end
end
