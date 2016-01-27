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
require 'uri'

class NOMS

end

class NOMS::CMDB < NOMS::HttpClient

    def self.mockery
        NOMS::CMDB::Mock
    end

  def config_key
    'cmdb'
  end

  def query(type, *condlist)
    do_request(:GET => "#{type}", :query => URI.encode(condlist.join('&')))
  end

  def help(type)
      do_request(:GET => type, :query => 'help')
  end

  def key_field_of(type)
      case type
      when 'system'
          'fqdn'
      else
          'id'
      end
  end

  def system(hostname)
    do_request(:GET => "system/#{hostname}")
  end

  def system_audit(hostname)
    do_request(:GET => "inv_audit", :query => "entity_key=#{hostname}")
  end

  def get_or_assign_system_name(serial)
      do_request(:GET => "pcmsystemname/#{serial}")
  end

  def create(type, obj, key=nil)
      keyfield = key_field_of(type)
      objkey = obj[keyfield]

      if key.nil? and objkey.nil?
          raise NOMS::Error, "Must specify a key value or imply it in the object's #{key_field_of(type)} value"
      end
      if (obj.has_key?(keyfield) and (! key.nil?) and obj[keyfield] != key)
          raise NOMS::Error, "You specified different keys for a new #{type} object: #{objkey} in the object vs. #{key}"
      end
      newobj = { keyfield => (objkey || key) }.merge obj
      do_request(:POST => type, :body => newobj)
  end

  def update(type, obj, key=nil)
      key ||= obj[key_field_of(type)]
      do_request(:PUT => "#{type}/#{key}", :body => obj)
  end

  def tc_post(obj)
      do_request(:POST => "fact", :body => obj)
  end
  def environments
    do_request :GET => 'environments'
  end

  def environment(env)
    do_request :GET => "environments/#{env}"
  end

  def create_environment(env, attrs)
      do_request :POST => "environments", :body => attrs.merge({ :name => env })
      environment env
  end

  def delete_environment(env)
      do_request :DELETE => "environments/#{env}"
  end

  def services(env)
    do_request :GET => "environments/#{env}/services"
  end

  def service(env, service)
    do_request :GET => "environments/#{env}/services/#{service}"
  end

  def update_service(env, service, attrs)
      do_request :PUT => "environments/#{env}/services/#{service}",
          :body => attrs
  end

  # CMDB API bug means use this endpoint to create
  # TODO needs update as this bug is no longer present
  def create_service(env, service, attrs)
      attrs[:name] = service
      attrs[:environment_name] = env
      do_request :POST => "service_instance", :body => attrs
      do_request :PUT => "environments/#{env}/services/#{service}",
          :body => attrs
  end

  def delete_service(env, service)
      do_request :DELETE => "environments/#{env}/services/#{service}"
  end

end

class NOMS::CMDB::Mock < NOMS::HttpClient::RestMock

    @@machine_id = 0

    def allow_put_to_create
        false
    end

    def id_field(path)
        case path
        when %r{system$}
            'fqdn'
        else
            'id'
        end
    end

    def handle_mock(method, uri, opt)
        if m = Regexp.new('/pcmsystemname/([^/]+)').match(uri.path)
            serial = m[1]
            @@machine_id += 1
            name = "m-%03d.mock" % @@machine_id
            do_request :POST => "system",
                       :body => {
                           'serial' => serial,
                           'fqdn' => name
                       }
        else
            false
        end
    end

end
