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

class NOMS::Nagui < NOMS::HttpClient

  @@validtypes =['hosts','services','hostgroups','servicegroups','contacts','commands',
    'downtimes','timeperiods','status','contactgroups']

  def dbg(msg)
      if @opt.has_key? 'debug' and @opt['debug'] > 2
          puts "DBG(#{self.class}): #{msg}"
      end
  end

  # def initialize(opt)
  #     @opt = opt
  #     self.dbg "Initialized with options: #{opt.inspect}"
  # end

  def config_key
    'nagui'
  end

  def make_plural(str)
    "#{str}s"
  end

  def default_query_key(type)
    case type
    when 'host'
      'name'
    when 'service'
      'description'
    when 'hostgroup'
      'name'
    end
  end

  def make_lql(type,queries)
    if !queries.kind_of?(Array)
      queries=[queries]
    end
    lql='GET ' 
    lql << make_plural(type) 
    queries.each do |q|
      query = /(\w+)([!~>=<]+)(.*)/.match(q)
      if query == nil
        lql << "|Filter: #{default_query_key(type)} ~~ #{q}"
      else
        lql << "|Filter: #{query[1]} #{query[2]} #{query[3]}"
      end
    end
    lql
  end

  def query(type,queries)
    unless @@validtypes.include? make_plural(type)
      puts "#{type} is not a valid type"
      Process.exit(1)
    end
    query_string = make_lql(type,queries)
    results = do_request(:GET => '/nagui/nagios_live.cgi', :query => URI.encode("query=#{query_string}"))
  end

  def host(hostname)
    results = do_request(:GET => '/nagui/nagios_live.cgi', :query => URI.encode("query=GET hosts|Filter: name ~~ #{hostname}"))
    if results.kind_of?(Array) && results.length > 0
      results[0]
    else
      nil
    end
  end

  def nagcheck(host,service)
    nagcheck=do_request(:GET => "/nagcheck/command/#{host}/#{service}")
  end

  def check_host_online(host)
    @opt['host_up_command'] = 'check-host-alive' unless @opt.has_key?('host_up_command')
    nagcheck=do_request(:GET => "/nagcheck/command/#{host}/#{@opt['host_up_command']}")
    if nagcheck['state'] == 0
      true
    else
      false
    end
  end

end