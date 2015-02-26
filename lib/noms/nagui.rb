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
require 'cgi'

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
    results = do_request(:GET => '/nagui/nagios_live.cgi', :query => "query=#{CGI.escape(query_string)}")
  end
  def hostgroup(name)
    lql = "GET hostgroups|Filter: name = #{name}"
    results = do_request(:GET => '/nagui/nagios_live.cgi', :query => "query=#{CGI.escape(lql)}")
    if results.kind_of?(Array) && results.length > 0
      results[0]
    else
      nil
    end
  end
  def service(host,description)
    lql = "GET services|Filter: host_name = #{host}|Filter: description = #{description}"
    results = do_request(:GET => '/nagui/nagios_live.cgi', :query => "query=#{CGI.escape(lql)}")
    if results.kind_of?(Array) && results.length > 0
      results[0]
    else
      nil
    end
  end
  def servicegroup(name)
    lql = "query=GET hosts|Filter: name = #{name}"
    results = do_request(:GET => '/nagui/nagios_live.cgi', :query => "query=#{CGI.escape(lql)}")
    if results.kind_of?(Array) && results.length > 0
      results[0]
    else
      nil
    end
  end
  def host(hostname)
    lql = "GET hosts|Filter: name = #{hostname}"
    results = do_request(:GET => '/nagui/nagios_live.cgi', :query => "query=#{CGI.escape(lql)}")
    if results.kind_of?(Array) && results.length > 0
      results[0]
    else
      nil
    end
  end

  def calc_time(str)
    case str
    when /(\d+)m/
      #minutes
      $1.to_i * 60
    when /(\d+)h/
      #hours
      $1.to_i * 3600
    when /(\d+)d/
      #days
      $1.to_i * 86400
    else
      str.to_i
    end
  end

  def process_command(cmd)
    do_request(:POST => '/nagui/nagios_live.cgi', :body => "query=#{CGI.escape(cmd)}", :content_type => 'application/x-www-form-urlencoded')
  end

  def downtime_host(host,length,user,comment)
    starttime=Time.now.to_i
    endtime = starttime + calc_time(length)
    cmd="COMMAND [#{Time.now.to_i}] SCHEDULE_HOST_DOWNTIME;#{host};#{starttime};#{endtime};1;0;0;#{user};#{comment}"
    process_command(cmd)
  end
  def downtime_service(host,service,length,user,comment)
    starttime=Time.now.to_i
    endtime = starttime + calc_time(length)
    cmd="COMMAND [#{Time.now.to_i}] SCHEDULE_SVC_DOWNTIME;#{host};#{service};#{starttime};#{endtime};1;0;0;#{user};#{comment}"
    process_command(cmd)
  end
  def undowntime(host,service=nil)
    if service == nil
      host_record = host(host)
      host_record['downtimes'].each do |id|
        cmd = "COMMAND [#{Time.now.to_i}] DEL_HOST_DOWNTIME;#{id}"
        process_command(cmd)
      end    
    else
      service_record = service(host,service)
      service_record['downtimes'].each do |id|
        cmd = "COMMAND [#{Time.now.to_i}] DEL_SVC_DOWNTIME;#{id}"  
        process_command(cmd)
      end  
    end
  end

  def ack_host(host,user,comment)
    cmd="COMMAND [#{Time.now.to_i}] ACKNOWLEDGE_HOST_PROBLEM;#{host};0;1;1;#{user};#{comment}"
    process_command(cmd)
  end

  def ack_service(host,service,user,comment)
    cmd="COMMAND [#{Time.now.to_i}] ACKNOWLEDGE_SVC_PROBLEM;#{host};#{service};0;1;1;#{user};#{comment}"
    process_command(cmd)
  end

  def nagcheck_host(host)
    url = "/nagcheck/host/#{host}"
    dbg("nagcheck url= #{url}")
    nagcheck=do_request(:GET => url, :query => "report=true")
  end

  def nagcheck_service(host,service)
    url = "/nagcheck/service/#{host}/#{service}"
    dbg("nagcheck url= #{url}")
    nagcheck=do_request(:GET => url, :query => "report=true")
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