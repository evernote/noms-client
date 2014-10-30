#!/usr/bin/env rspec

require 'noms/cmdb'
require 'spec_helper'

describe NOMS::CMDB do

    before(:all) { init_test }

    describe "#new" do

        it "creates a new CMDB client object" do

            obj = NOMS::CMDB.new($opt)
            obj.should be_a NOMS::CMDB

        end

    end

end
