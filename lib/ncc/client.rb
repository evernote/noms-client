#!ruby
# /* Copyright 2014 Evernote Corporation. All rights reserved.
#    Copyright 2013 Proofpoint, Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# */


require 'noms/httpclient'

class NCC

end

class NCC::Client < NOMS::HttpClient

    def config_key
        'ncc'
    end

    # ncc-api (probably due to nginx) returns bad content-types
    def ignore_content_type
        true
    end

    def list(cloud=nil)
        if cloud.nil?
            clouds = do_request "clouds"
            clouds.map do |c|
                list c
            end.flatten
        else
            do_request :GET => "clouds/#{cloud}/instances"
        end
    end

    def instance(cloud, id)
        do_request :GET => "clouds/#{cloud}/instances/#{id}"
    end

    def clouds
        cloudnames = do_request :GET => "clouds"
        cloudnames.map do |cloudname|
            if cloudname.respond_to? :keys
                cloudname
            else
                do_request :GET => "clouds/#{cloudname}"
            end
        end
    end

    def create(cloud, attrs)
        do_request :POST => "clouds/#{cloud}/instances",
            :body => attrs
    end

    def delete(cloud, attrs)
        if attrs.has_key? :id
            do_request :DELETE => "clouds/#{cloud}/instances/#{attrs[:id]}"
        elsif attrs.has_key? :name
            # For now I have to do this--not optimal, should be in NCC-API
            instobj = find_by_name(cloud, attrs[:name])
            if instobj
                do_request :DELETE => "clouds/#{cloud}/instances/#{instobj['id']}"
            else
                raise "No instance found in cloud #{cloud} with name #{attrs[:name]}"
            end
        else
            raise "Need to delete instance by name or id"
        end
    end

    def find_by_name(cloud, name)
        instobj = (list cloud).find { |i| i['name'] == name }
    end

    def create(cloud, attrs)
        do_request :POST => "clouds/#{cloud}/instances",
            :body => attrs
    end

    def instance(cloud, id)
        do_request :GET => "clouds/#{cloud}/instances/#{id}"
    end

end
