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

class PCM

end

class PCM::Client < NOMS::HttpClient

    def config_key
        'pcm-api'
    end

    # pcm-api-v2 (probably due to nginx) returns bad content-types
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

    def clouds
        cloudnames = do_request :GET => "clouds"
        cloudnames.map do |cloudname|
            do_request :GET => "clouds/#{cloudname}"
        end
    end

    def instance(cloud, id)
        do_request :GET => "clouds/#{cloud}/instances/#{id}"
    end

end
