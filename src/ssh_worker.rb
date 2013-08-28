# Copyright 2011 (c) MaestroDev.  All rights reserved.
require File.join(File.dirname(__FILE__), 'ssh_common')

module MaestroDev
  module Plugin
  
    class SSHWorker < SSHCommon
      class SSHCommandError < PluginError
      end

      def validate_parameters
        # Making sure to let the base class do its initial validation of all the things
        errors = super
  
        # Now do the things that are specific to me
        @commands = get_field('commands') || []
        @commands.delete_if {|v| v.nil? || v.empty?}
  
        @ignore_errors = get_field('ignore_errors') || false
  
        errors << 'No commands to run' if @commands.empty?
        raise ConfigError, "Config Errors: #{errors.join(', ')}"  unless errors.empty?
      end
  
      def execute
        error_count = 0
        command_count = 0
  
        do_ssh do |session|
          @commands.each do |command|
            command_count += 1
            begin
              perform_command(session, command)
            rescue SSHCommandError => e
              error_count += 1

              if @ignore_errors
                write_output(e.message, :buffer => true)
              else
                raise PluginError, e.message
              end
            end
          end
        end
      ensure
        write_output("\nOf #{@commands.size} commands: #{command_count} excecuted, #{error_count} failed. (ignore_errors = #{@ignore_errors})", :buffer => true)
      end
  
      private
  
      def handle_response(command, exit_code, exit_signal)
        # Normal shell operations do not print "Success", they print their output and just go away.
        # It is only when an error occurs that we need to see some diagnostic content.
        if exit_code != 0
          write_output("\nERR: `#{command}` failed.  exit_code: #{exit_code}, exit_signal: #{exit_signal}\n")
          false
        else
          true
        end
      end
  
      def perform_command(session, command)
        stdout_data = ""
        stderr_data = ""
        combined_data = ""
        exit_code = nil
        exit_signal = nil
        is_success = true
        write_output("\nssh> #{command}\n", :buffer => true)
  
        session.open_channel do |channel|
          channel.exec(command) do |ch, success|
            channel.on_data do |ch,data|
              # Called when outut received (i.e. stdout)
              combined_data+=data
              write_output(data, :buffer => true)
            end
  
            channel.on_extended_data do |ch,type,data|
              # net/ssh Extended data is almost exclusively used to send stderr data (type == 1)
              combined_data+=data
              write_output(data, :buffer => true)
            end
  
            channel.on_request('exit-status') do |ch,data|
              # called when process exits
              exit_code = data.read_long
              is_success = handle_response(command, exit_code, exit_signal)
            end
  
            channel.on_request('exit-signal') do |ch, data|
              # called when process signalled
              exit_signal = data.read_long
            end
  
            channel.on_close do |ch|
              # called when connection (channel) closes.  This isn't really an error condition
              # we can just used it to log the fact.
              # not calling write_output as sometimes the channel is closed before the output
              # is received, and it looks weird to see "Connection Closedhere is your output"
  #            write_output("\nSSH Connection Closed", :buffer => true)
            end
          end
        end
        session.loop
  
        # Raise the error outside of the session loop, so we get entire output before dying, otherwise it would be like
        # Maxwell Smart getting "You're kneeling on my chest" out of a dying kaos agent
        raise SSHCommandError, "`#{command}` failed (exit_code #{exit_code}, exit_signal #{exit_signal}). Session output:\n#{combined_data}" unless is_success
      end
    end
  end
end
