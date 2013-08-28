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

describe MaestroDev::Plugin::SSHWorker do

  describe '/ssh/execute' do
    before(:each) do
      Maestro::MaestroWorker.mock!
      @hostname = 'aws-vm.com' #'ec2-204-236-201-166.compute-1.amazonaws.com'
      @key_file = File.join(File.dirname(__FILE__), 'config','lucee-demo-keypair.pem')
      @user = 'root'
#      @ssh_worker.stubs(:write_output).with { |v| print "#{v}\n"; 1 }
#      @ssh_worker.stubs(:set_error).with { |v| print "#{v}\n @ #{caller}"; 1 }
    end

    it 'should detect if key-file is not found' do
      workitem = {'fields' => {'host' => @hostname, 'user' => 'dingdong', 'key_path' => '/not_real/', 'commands' => ["ls /", "pwd"]}}
      subject.perform(:execute, workitem)
      workitem['fields']['__error__'].should include('Invalid key, not found')
    end

    it "should connect to a remote server and execute a given set of commands" do
        subject.stubs(:start)
        subject.stubs(:perform_command)
        workitem = {'fields' => {'host' => @hostname, 'user' => @user, 'key_path' => @key_file, 'commands' => ["export BLAH=blah; ls /", "pwd"]}}
        subject.perform(:execute, workitem)
        workitem['fields']['__error__'].should be_nil
        workitem['__output__'].should_not be_nil
    end

    it "should raise an error when it fails to connect to the server" do
        subject.expects(:start).raises(TimeoutError, 'Operation timed out - connect(2)')

        workitem = {'fields' => {'host' => @hostname, 'user' => 'dingdong', 'commands' => ["ls /", "pwd"]}}
        subject.perform(:execute, workitem)
        workitem['fields']['__error__'].should include('Timeout')
    end

    it "should raise an error when it fails to connect to the server with port" do
        subject.expects(:start).raises(Errno::ECONNREFUSED, 'Error in SSH connection: Connection refused - Failed To Connect To localhost After 5 Trys')

        workitem = {'fields' => {'host' => 'localhost', 'user' => 'bob', 'port' => 22222, 'commands' => ["ls /", "pwd"]}}
        subject.perform(:execute, workitem)
        workitem['fields']['__error__'].should include('Error in SSH connection: Connection refused - Failed To Connect To localhost After 5 Trys')
    end

    it "should raise an error when it fails to connect to the server with wrong username" do
        subject.expects(:start).raises(Exception, 'Error in SSH connection: kelly')

        workitem = {'fields' => {'host' => 'localhost', 'user' => 'kelly', 'password' => 'notright', 'commands' => ["ls /", "pwd"]}}
        subject.perform(:execute, workitem)
        workitem['fields']['__error__'].should include('Error in SSH connection: kelly')
    end

    it "should set the error field correctly if a command fails (ignore == false)" do
      subject.stubs(:start)
      subject.stubs(:perform_command).raises(MaestroDev::Plugin::SSHWorker::SSHCommandError, "ehh?")
      workitem = {'fields' => {'host' => @hostname, 'user' => @user, 'key_path' => @key_file, 'commands' => ["export BLAH=blah; ls /", "pwd"]}}
      subject.perform(:execute, workitem)
      workitem['fields']['__error__'].should include('ehh?')
      workitem['__output__'].should include("\nOf 2 commands: 1 excecuted, 1 failed. (ignore_errors = false)")
    end

    it "should not set the error field if a command fails (ignore == true)" do
      subject.stubs(:start)
      subject.stubs(:perform_command).raises(MaestroDev::Plugin::SSHWorker::SSHCommandError, "wha?")
      workitem = {'fields' => {'host' => @hostname, 'user' => @user, 'key_path' => @key_file, 'commands' => ["export BLAH=blah; ls /", "pwd"], 'ignore_errors' => true}}
      subject.perform(:execute, workitem)
      workitem['fields']['__error__'].should be_nil
      workitem['__output__'].should include("\nOf 2 commands: 2 excecuted, 2 failed. (ignore_errors = true)")
    end
  end
end
