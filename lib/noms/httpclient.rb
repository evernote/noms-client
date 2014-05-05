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


require 'net/http'
require 'net/https'
require 'rubygems'
require 'rexml/document'
require 'json'

class NOMS

end

class NOMS::XmlHash < Hash

    attr_accessor :element, :name

    def initialize(el)
        super
        @element = el
        @name = el.name
        self['text'] = el.text
        el.attributes.each do |attr, value|
           self[attr] = value
        end
        self['children'] = []
        el.elements.each do |child|
           self['children'] << NOMS::XmlHash.new(child)
        end
    end

    def to_xml(name=nil)
        el = REXML::Element.new(name || self.name)
        el.text = self['text'] if self.has_key? 'text'
        self.each do |key, val|
           next if ['children', 'text'].include? key
           el.add_attribute(key, val)
        end
        if self.has_key? 'children'
           self['children'].each do |child|
              el.add_element child.to_xml
           end
        end
        el
    end

end

class NOMS::HttpClient

    def config_key
        'httpclient'
    end

    def default_content_type
        'application/json'
    end

    def ignore_content_type
        false
    end

    def initialize(opt)
        @opt = opt
        @opt['return-hash'] = true unless @opt.has_key? 'return-hash'
        self.dbg "Initialized with options: #{opt.inspect}"
    end

    def dbg(msg)
        if @opt.has_key? 'debug' and @opt['debug'] > 1
            puts "DBG(#{self.class}): #{msg}"
        end
    end

    def trim(s, c='/', dir=:both)
        case dir
        when :both
            trim(trim(s, c, :right), c, :left)
        when :right
            s.sub(Regexp.new(c + '+/'), '')
        when :left
            s.sub(Regexp.new('^' + c + '+'), '')
        end
    end

    def ltrim(s, c='/')
        trim(s, c, :left)
    end

    def rtrim(s, c='/')
        trim(s, c, :right)
    end

    def do_request(opt={})
        method = [:GET, :PUT, :POST, :DELETE].find do |m|
            opt.has_key? m
        end
        method ||= :GET
        rel_uri = opt[method]
        opt[:redirect_limit] ||= 10
        if opt[:absolute]
          url = URI.parse(rel_uri)
        else
          url = URI.parse(@opt[config_key]['url'])
          url.path = rtrim(url.path) + '/' + ltrim(rel_uri) unless opt[:absolute]
          url.query = opt[:query] if opt.has_key? :query
        end
        self.dbg("#{method.inspect} => #{url.to_s}")
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true if url.scheme == 'https'
        if http.use_ssl?
            self.dbg("using SSL/TLS")
            if @opt[config_key].has_key? 'verify-with-ca'
                http.verify_mode = OpenSSL::SSL::VERIFY_PEER
                http.ca_file = @opt[config_key]['verify-with-ca']
            else
                http.verify_mode = OpenSSL::SSL::VERIFY_NONE
            end
        else
            self.dbg("NOT using SSL/TLS")
        end
        reqclass = case method
                   when :GET
                       Net::HTTP::Get
                   when :PUT
                       Net::HTTP::Put
                   when :POST
                       Net::HTTP::Post
                   when :DELETE
                       Net::HTTP::Delete
                   end
        request = reqclass.new(url.request_uri)
        self.dbg request.to_s
        if @opt[config_key].has_key? 'username'
            self.dbg "will do basic authentication as #{@opt[config_key]['username']}"
            request.basic_auth(@opt[config_key]['username'],
                          @opt[config_key]['password'])
        else
            self.dbg "no authentication"
        end
        if opt.has_key? :body
          content_type = opt[:content_type] || default_content_type
          request.body = case content_type
                         when /json$/
                           opt[:body].to_json
                         when /xml$/
                           opt[:body].to_xml
                         else
                           opt[:body]
                         end
        end

        response = http.request(request)
        self.dbg response.to_s
        if response.is_a? Net::HTTPRedirection
            if opt[:redirect_limit] == 0
                raise "Error (#{self.class}) making #{config_key} request " +
                  "(redirect limit exceeded): on #{response['location']}"
            end
            # TODO check if really absolute or make sure it is
            self.dbg "Redirect to #{response['location']}"
            do_request opt.merge({ :GET => response['location'],
                                   :absolute => true,
                                   :redirect_limit => opt[:redirect_limit] - 1
                                   })
        end

        unless response.is_a? Net::HTTPSuccess
            raise "Error (#{self.class}) making #{config_key} request " +
                "(#{response.code}): " + error_body(response.body)
        end

        if response.body
            type = ignore_content_type ? default_content_type :
                (response.content_type || default_content_type)
            self.dbg "Response body is type #{type}"
            case type
            when /xml$/
               doc = REXML::Document.new response.body
               if @opt['return-hash']
                   _xml_to_hash doc
               else
                   doc
               end
            when /json$/
               JSON.parse(response.body)
            else
               response.body
            end
        else
            true
        end
    end

    def _xml_to_hash(rexml)
        NOMS::XmlHash.new rexml.root
    end

    def error_body(body_text, content_type=nil)
        content_type ||= default_content_type
        begin
            extracted_message = case content_type
                                when /json$/
                                  structure = JSON.parse(body_text)
                                  structure['message']
                                when /xml$/
                                  REXML::Document.new(body_text).root.elements["//message"].first.text
                        else
                          Hash.new
                        end
            return structure['message'] if structure.has_key? 'message'
            body_text
        rescue
            body_text
        end
    end

end
