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

end
