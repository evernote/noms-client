#!/usr/bin/env rspec

require 'noms/cmdb'
require 'spec_helper'

describe NOMS::CMDB do

    before(:all) do
        init_test

        NOMS::CMDB.mock! nil
    end

    describe "#new" do

        it "creates a new CMDB client object" do

            obj = NOMS::CMDB.new($opt)
            obj.should be_a NOMS::CMDB

        end

    end

    describe "#create" do

        before(:each) { @cmdb = NOMS::CMDB.new $opt }

        it 'creates an entry' do
            obj = @cmdb.create('system', { 'fqdn' => 'test0', 'inventory_component_type' => 'system'})
            expect(obj).to have_key 'fqdn'
            expect(obj).to have_key 'inventory_component_type'
            expect(obj['fqdn']).to eq 'test0'
        end

        it 'finds the same entry' do
            @cmdb.create('system', { 'fqdn' => 'test2', 'inventory_component_type' => 'system'})
            obj = @cmdb.system('test2')
            expect(obj).to have_key 'fqdn'
            expect(obj).to include 'inventory_component_type' => 'system'
        end

        it 'creates an entry under the specified key' do
            @cmdb.create('system', { 'inventory_component_type' => 'system' }, 'test3')
            obj = @cmdb.system('test3')
            expect(obj).to include 'fqdn' => 'test3'
            expect(obj).to include 'inventory_component_type' => 'system'
        end

        it 'fails to create a keyless entry' do
            expect { @cmdb.create('system', { 'environment_name' => 'random' }) }.to raise_error(NOMS::Error)
        end

        it 'fails when different keys are specified' do
            expect { @cmdb.create('system',
                                  { 'fqdn' => 'test3', 'environment_name' => 'random' },
                                  'test4') }.to raise_error(NOMS::Error)
        end

    end

end
