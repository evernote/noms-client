#!/usr/bin/env rspec

require 'noms/cmdb'
require 'spec_helper'

describe NOMS::CMDB::RestMock do

    before(:all) do
        init_test
        NOMS::CMDB.mock! nil
    end

    context 'initializing' do

        describe '#new' do

            it 'creates a new instance' do

                cmdb = NOMS::CMDB.new $opt
                expect(cmdb).to be_an_instance_of NOMS::CMDB

            end

        end

    end

    describe '#do_query' do

        before(:each) do
            @cmdb = NOMS::CMDB.new $opt
        end

        context :POST do

            it 'creates a new entry' do
                result = @cmdb.do_request :POST => '/environments', :body => {
                    'id' => 'production', 'name' => 'production',
                    'environment_name' => 'production' }
                expect(result).to have_key 'name'
                expect(result['name']).to be == 'production'
                expect(@cmdb.all_data).to have_key $server
                expect(@cmdb.all_data[$server]).to have_key "#{$cmdbapi}/environments"
                expect(@cmdb.all_data[$server]["#{$cmdbapi}/environments"]).to be_an Array
                expect(@cmdb.all_data[$server]["#{$cmdbapi}/environments"]).to include { |x| x['name'] == 'production' }
            end

            it 'creates several new entries' do
                @cmdb.do_request :POST => '/environments', :body => {
                    'id' => 'production', 'name' => 'production',
                    'environment_name' => 'production' }
                10.times do |i|
                    env = "environment-#{i}"
                    @cmdb.do_request :POST => '/environments', :body => {
                        'id' => env, 'name' => env, 'environment_name' => 'production'
                    }
                end
                envs = @cmdb.all_data[$server]["#{$cmdbapi}/environments"]
                expect(envs).to have(11).items
            end

            it 'synthesizes an id' do
                result = @cmdb.do_request :POST => '/environments', :body => { 'name' => 'production' }
                expect(result).to have_key 'id'
                expect(@cmdb.all_data[$server][$cmdbapi + '/environments']).to include { |o| o['id'] = result['id'] }
            end

        end

        context :PUT do

            it 'creates a new entry' do
                @cmdb.do_request :PUT => '/environments/1', :body => {
                    'name' => 'production', 'environment_name' => 'production' }
                expect(@cmdb.all_data[$server][$cmdbapi + '/environments']).to include { |o| o['name'] == 'production' }
            end

            it 'creates several new entries' do
                @cmdb.do_request :PUT => '/environments/1', :body => {
                    'name' => 'production', 'environment_name' => 'production' }
                10.times do |i|
                    @cmdb.do_request :PUT => "/environments/#{100 + i}", :body => {
                        'name' => "environment-#{i}", 'environment_name' => 'production' }
                end
                expect(@cmdb.all_data[$server][$cmdbapi + '/environments']).to have(11).items
                expect(@cmdb.all_data[$server][$cmdbapi + '/environments']).to include { |o| o['name'] == 'production' }
            end

            it 'infers the id' do
                result = @cmdb.do_request :PUT => '/environments/1', :body => { 'name' => 'production' }
                expect(result).to have_key 'id'
                expect(@cmdb.all_data[$server][$cmdbapi + '/environments'][0]).to have_key 'id'
                expect(@cmdb.all_data[$server][$cmdbapi + '/environments'][0]['id']).to eq '1'
            end

            it 'replaces an existing object' do
                @cmdb.do_request :PUT => '/environments/1', :body => {
                    'name' => 'production', 'environment_name' => 'production' }
                @cmdb.do_request :PUT => '/environments/1', :body => {
                    'name' => 'testing', 'note' => 'testing environment' }
                data = @cmdb.all_data[$server][$cmdbapi + '/environments']
                expect(data[0]).to have_key 'name'
                expect(data[0]).to have_key 'id'
                expect(data[0]).to have_key 'note'
                expect(data[0]).not_to have_key 'environment_name'
                expect(data[0]['name']).to eq 'testing'
            end

            it 'updates an existing object' do
                def @cmdb.allow_partial_updates
                    true
                end
                @cmdb.do_request :PUT => '/environments/1', :body => {
                    'name' => 'production', 'environment_name' => 'production' }
                @cmdb.do_request :PUT => '/environments/1', :body => {
                    'name' => 'testing', 'note' => 'testing environment' }
                object = @cmdb.all_data[$server][$cmdbapi + '/environments'][0]
                expect(object['id']).to eq '1'
                expect(object['name']).to eq 'testing'
                expect(object['note']).to eq 'testing environment'
                expect(object['environment_name']).to eq 'production'
            end

        end

        context :GET do

            it 'finds an existing entry' do
                @cmdb.do_request :POST => '/environments', :body => {
                    'id' => 'production', 'name' => 'production',
                    'environment_name' => 'production' }
                result = @cmdb.do_request :GET => '/environments/production'
                expect(result).to be_a Hash
                expect(result).to include 'name' => 'production'
            end

            it 'retrieves all entries' do
                @cmdb.do_request :POST => '/environments', :body => {
                    'name' => 'production', 'environment_name' => 'production'
                }
                10.times do |i|
                    @cmdb.do_request :POST => '/environments', :body => {
                        'name' => "environment-#{i}", 'environment_name' => 'production'
                    }
                end
                result = @cmdb.do_request :GET => '/environments'
                expect(result).to be_an Array
                expect(result).to have(11).items
                expect(result).to include { |o| o['name'] == 'production' }
            end

            it 'raises an exception for missing entries' do
                expect { @cmdb.do_request :GET => '/environments/1' }.to raise_error
                @cmdb.do_request :PUT => '/environments/1', :body => { 'name' => 'production' }
                expect { @cmdb.do_request :GET => '/chorizo' }.to raise_error
                expect { @cmdb.do_request :GET => '/environments/2' }.to raise_error
            end

        end

        context :DELETE do

            it 'deletes an existing entry' do
                @cmdb.do_request :PUT => '/environments/1', :body => { 'name' => 'production' }
                result = @cmdb.do_request :DELETE => '/environments/1'
                expect(result).to be true
                expect(@cmdb.all_data[$server][$cmdbapi + '/environments']).to have(0).items
            end

            it 'deletes an existing entry among many' do
                @cmdb.do_request :PUT => '/environments/1', :body => { 'name' => 'production' }
                10.times do |i|
                    @cmdb.do_request :PUT => "/environments/#{100 + i}", :body => {
                        'name' => "environment-#{i}", 'environment_name' => 'production' }
                end
                @cmdb.do_request :DELETE => '/environments/103'
                data = @cmdb.all_data[$server][$cmdbapi + '/environments']
                expect(data).to have(10).items
                expect(data).not_to include { |o| o['name'] == 'environment-3' }
            end

            it 'deletes a whole collection' do
                @cmdb.do_request :PUT => '/environments/1', :body => {'name' => 'production' }
                @cmdb.do_request :DELETE => '/environments'
                expect(@cmdb.all_data[$server]).not_to have_key '/environments'
            end

            it 'raises an exception for nonexistent entries' do
                expect { @cmdb.do_request :DELETE => '/environments/2' }.to raise_error
                @cmdb.do_request :PUT => '/environments/1', :body => { 'name' => 'production' }
                expect { @cmdb.do_request :DELETE => '/environments/2' }.to raise_error
                expect { @cmdb.do_request :DELETE => '/chorizo' }.to raise_error
            end

        end

    end

    describe "#get_or_assign_system_name" do

        before(:each) do
            @cmdb = NOMS::CMDB.new $opt
        end

        it 'creates an entry with a new system name' do
            response = @cmdb.get_or_assign_system_name('MCN0021')
            expect(response).to have_key 'fqdn'
            expect(response['fqdn']).to include 'm-0'
            expect(response['serial']).to eq 'MCN0021'
        end

    end

end
