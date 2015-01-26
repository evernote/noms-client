#!/usr/bin/env rspec

require 'ncc/client'
require 'noms/client/version'
require 'spec_helper'


describe NCC::Client do
    before(:all) do
        init_test
        NCC::Client.mock! nil
    end

    context "initializing" do

        it "creates an NCC::Client object" do
            ncc = NCC::Client.new $opt
            expect(ncc).to be_an_instance_of NCC::Client
        end

    end

    describe '#clouds' do

        before(:each) do
            @ncc = NCC::Client.new $opt
            # Necessary to exercise mock--should be abstracted?
            @ncc.do_request :PUT => '/clouds/os0', :body => {
                'name' => 'os0',
                'status' => 'ok',
                'provider' => 'openstack',
                'service' => 'Fog::Compute::OpenStack::Mock'
            }
        end

        it "returns a list of cloud objects" do
            result = @ncc.clouds
            expect(result.size).to eq(1)
            expect(result.first['name']).to eq('os0')
        end

        it "returns a specific cloud object" do
            result = @ncc.clouds('os0')
            expect(result).to have_key 'provider'
            expect(result['provider']).to eq 'openstack'
        end

    end

    describe '#info' do
        before(:each) do
            @ncc = NCC::Client.new $opt
            @ncc.do_request :PUT => '', :body => {
                'version' => NOMS::Client::VERSION
            }
        end

        it "returns version info" do
            info = @ncc.info
            expect(info).to have_key 'version'
            expect(info['version']).to eq NOMS::Client::VERSION
        end
    end

    describe '#console' do
        before(:each) do
            @ncc = NCC::Client.new $opt
            @ncc.do_request :PUT => 'clouds/os0/instances/1', :body => {
                'name' => 'testinst1.local',
                'id' => '1',
                'role' => [ ],
                'status' => 'active',
                'size' => 'm1.small',
                'image' => 'deb6',
                'host' => 'ostack01.local',
                'ip_address' => '127.0.0.1'
            }
            @ncc.do_request :PUT => 'clouds/os0/instances/1/console', :body => {
                'url' => 'vnc://ostack01:5959'
            }
        end

        it "returns a console URL" do
            console = @ncc.console('os0', '1')
            expect(console).to have_key 'url'
            expect(console['url']).to eq 'vnc://ostack01:5959'
        end
    end

end
