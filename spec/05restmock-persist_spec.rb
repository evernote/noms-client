#!/usr/bin/env rspec

require 'noms/cmdb'
require 'spec_helper'
require 'fileutils'


describe NOMS::CMDB::RestMock do

    before(:all) do
        FileUtils.mkdir 'test' unless Dir.exists? 'test'
        $datafile = 'test/data.json'
        NOMS::CMDB.mock! $datafile
        File.unlink($datafile) if File.exist? $datafile
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

        after(:all) do
            unless $opt['debug'] > 0
                File.unlink $datafile
                FileUtils.rmdir 'test'
            end
        end

        context :PUT do

            it 'creates a new entry' do
                @cmdb.do_request :PUT => '/environments/production', :body => {
                    'name' => 'production', 'environment_name' => 'production' }
                expect(File.exist? $datafile).to be true
            end

        end

        context :GET do

            it 'finds an existing entry' do
                result = @cmdb.do_request :GET => '/environments/production'
                expect(result).to be_a Hash
                expect(result).to include 'name' => 'production'
            end

            it 'raises an exception for missing entries' do
                expect { @cmdb.do_request :GET => '/environments/1' }.to raise_error
                expect { @cmdb.do_request :GET => '/chorizo' }.to raise_error
                expect { @cmdb.do_request :GET => '/environments/2' }.to raise_error
            end

        end

        context :DELETE do

            it 'deletes an existing entry' do
                result = @cmdb.do_request :DELETE => '/environments/production'
                expect(result).to be true
                expect(@cmdb.all_data[$server][$cmdbapi + '/environments']).to have(0).items
            end

        end

    end

end
