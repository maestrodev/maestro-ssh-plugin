# Copyright 2011© MaestroDev.  All rights reserved.
require File.join(File.dirname(__FILE__), 'ssh_common')

module MaestroDev
  class SSHWorker < MaestroDev::SSHCommon
    def validate_parameters
      # Making sure to let the base class do its initial validation of all the things
      super

      # Now do the things that are specific to me
      @commands = get_field('commands')

      raise 'No Commands to run' if @commands.nil? || @commands.empty?
    end

    def execute
      write_output "\nSSH EXECUTE task starting"
      
      do_ssh do |session|
        @commands.each do |command|
          perform_command(session, command)
          
#          # This will cause error to be set if we get disconnected by ssh prematurely
#          raise 'SSH disconnected prematurely' if @disconnected
        end
      end

      write_output "\nSSH EXECUTE task complete"
    end

    private
    
    def handle_response(command, stdout_data, stderr_data, combined_data, exit_code, exit_signal)
      if exit_code != 0
        raise "Command (#{command}) Failed: exit_code: #{exit_code}, exit_signal: #{exit_signal}, data: #{combined_data}"
      else
        write_output("\nSuccess", :buffer => true)
      end
    end
      
    def perform_command(session, command)
      stdout_data = ""
      stderr_data = ""
      combined_data = ""
      exit_code = nil
      exit_signal = nil

      write_output("\nssh> #{command}\n", :buffer => true)

      session.open_channel do |channel|
        channel.exec(command) do |ch, success|
          channel.on_data do |ch,data|
            stdout_data+=data
            combined_data+=data
            write_output(data, :buffer => true)
          end

          channel.on_extended_data do |ch,type,data|
            # net/ssh Extended data is almost exclusively used to send stderr data (type == 1)
            stderr_data+=data
            combined_data+=data
            write_output(data, :buffer => true)
          end

          channel.on_request('exit-status') do |ch,data|
            exit_code = data.read_long
            handle_response(command, stdout_data, stderr_data, combined_data, exit_code, exit_signal)
          end

          channel.on_request('exit-signal') do |ch, data|
            exit_signal = data.read_long
          end
          
          channel.on_close do |ch|
            write_output("\nSSH Connection Closed", :buffer => true)
          end
        end
      end
      session.loop
    end
  end
end