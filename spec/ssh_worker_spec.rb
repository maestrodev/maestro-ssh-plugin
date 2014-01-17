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

  let(:hostname) { 'aws-vm.com' }
  let(:key_file) { File.join(File.dirname(__FILE__), 'config','lucee-demo-keypair.pem') }
  let(:user) { 'root' }
  let(:fields) {{'host' => hostname, 'user' => user, 'key_path' => key_file, 'commands' => ["export BLAH=blah; ls /", "pwd"]}}
  let(:workitem) {{'fields' => fields}}

  describe '/ssh/execute' do

    context "when key file does not exist" do
      let(:key_path) { '~/not_real/' }
      let(:fields) { super().merge({'key_path' => key_path}) }
      before { subject.perform(:execute, {'fields' => fields}) }
      its(:error) { should eq("Config Errors: Invalid key, not found: #{File.expand_path(key_path)}") }
    end

    context "when connecting to a remote server and executing a given set of commands" do
      before do
        subject.stubs(:start)
        subject.stubs(:perform_command)
        subject.perform(:execute, workitem)
      end
      its(:error) { should be_nil }
      its(:output) { should_not be_nil }
    end

    context "when it fails to connect to the server" do
      before do
        subject.expects(:start).raises(TimeoutError, 'Operation timed out - connect(2)')
        subject.perform(:execute, workitem)
      end
      its(:error) { should include('Timeout') }
    end

    context "when it fails to connect to the server with port" do
      let(:fields) { super().merge({'port' => 22222}) }
      before do
        subject.expects(:start).raises(Errno::ECONNREFUSED, 'Error in SSH connection: Connection refused - Failed To Connect To localhost After 5 Trys')
        subject.perform(:execute, workitem)
      end
      its(:error) { should include('Error in SSH connection: Connection refused - Failed To Connect To localhost After 5 Trys') }
    end

    context "when it fails to connect to the server with wrong username" do
      let(:fields) { super().merge({'user' => 'kelly'}) }
      before do
        subject.expects(:start).raises(Exception, 'Error in SSH connection: kelly')
        subject.perform(:execute, workitem)
      end
      its(:error) { should include('Error in SSH connection: kelly') }
    end

    context "when a command fails" do
      before do
        subject.stubs(:start)
        subject.stubs(:perform_command).raises(MaestroDev::Plugin::SSHWorker::SSHCommandError, "ehh?")
        subject.perform(:execute, workitem)
      end

      context "and ignore is false" do
        its(:error) { should include('ehh?') }
        its(:output) { should include("\nOf 2 commands: 1 executed, 1 failed. (ignore_errors = false)") }
      end

      context "and ignore is true" do
        let(:fields) { super().merge({'ignore_errors' => true}) }
        its(:error) { should be_nil }
        its(:output) { should include("\nOf 2 commands: 2 executed, 2 failed. (ignore_errors = true)") }
      end
    end
  end
end
