# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
# 
#  http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

require 'spec_helper'

describe MaestroDev::SSHWorker do

  describe '/ssh/execute' do
    before(:each) do
      @ssh_worker = MaestroDev::SSHWorker.new
      @hostname = 'aws-vm.com' #'ec2-204-236-201-166.compute-1.amazonaws.com'
      @key_file = File.join(File.dirname(__FILE__), 'config','lucee-demo-keypair.pem')
      @user = 'root'
      @ssh_worker.stubs(:write_output) #.with { |v| print "#{v}\n"; 1 }
#      @ssh_worker.stubs(:set_error).with { |v| print "#{v}\n @ #{caller}"; 1 }
    end
  
    it 'should detect if key-file is not found' do
      
      workitem = {'fields' => {'host' => @hostname, 'user' => 'dingdong', 'key_path' => '/not_real/', 'commands' => ["ls /", "pwd"]}}
      @ssh_worker.expects(:workitem).at_least(2).returns(workitem)
      @ssh_worker.execute
      workitem['fields']['__error__'].should include('Invalid key, not found')
    end
  
    it "should connect to a remote server and execute a given set of commands" do
        session = mock()
  
        @ssh_worker.stubs(:start => session)
        @ssh_worker.expects(:perform_command => false).times(2)
        workitem = {'fields' => {'host' => @hostname, 'user' => @user, 'key_path' => @key_file, 'commands' => ["export BLAH=blah; ls /", "pwd"]}}
        @ssh_worker.expects(:workitem).at_least(2).returns(workitem)
        @ssh_worker.execute
        workitem['fields']['__error__'].should be_nil
        workitem['fields']['output'].should_not be_nil
    end
  
    it "should raise an error when it fails to connect to the server" do
  
        @ssh_worker.expects(:start).raises(TimeoutError, 'Operation timed out - connect(2)')

        workitem = {'fields' => {'host' => @hostname, 'user' => 'dingdong', 'commands' => ["ls /", "pwd"]}}
        @ssh_worker.expects(:workitem).at_least(2).returns(workitem)
        @ssh_worker.execute
        workitem['fields']['__error__'].should include('Timeout')
    end
  
    it "should raise an error when it fails to connect to the server with port" do
  
        @ssh_worker.expects(:start).raises(Errno::ECONNREFUSED, 'Error in SSH connection: Connection refused - Failed To Connect To localhost After 5 Trys')

        workitem = {'fields' => {'host' => 'localhost', 'user' => 'bob', 'port' => 22222, 'commands' => ["ls /", "pwd"]}}
        @ssh_worker.expects(:workitem).at_least(2).returns(workitem)
        @ssh_worker.execute
        workitem['fields']['__error__'].should include('Error in SSH connection: Connection refused - Failed To Connect To localhost After 5 Trys')
    end
  
    it "should raise an error when it fails to connect to the server with wrong username" do
  
        @ssh_worker.expects(:start).raises(Exception, 'Error in SSH connection: kelly')
    
        workitem = {'fields' => {'host' => 'localhost', 'user' => 'kelly', 'password' => 'notright', 'commands' => ["ls /", "pwd"]}}
        @ssh_worker.expects(:workitem).at_least(2).returns(workitem)
        @ssh_worker.execute
        workitem['fields']['__error__'].should include('Error in SSH connection: kelly')
    end
  
#    it "should raise an error when one of the commands fail" do
#      #handle_response(command, stdout_data, stderr_data, combined_data, exit_code, exit_signal)
#        expect{@ssh_worker.handle_response("somecommand", 'output data', ":error data", "output data error data", 1, 0)}.to raise_error(RuntimeError)
#    end
  end
end
