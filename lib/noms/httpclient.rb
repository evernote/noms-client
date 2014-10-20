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

class Hash

    # The mkdir -p of []=
    def set_deep(keypath, value)
        if keypath.length == 1
            self[keypath[0]] = value
        else
            self[keypath[0]] ||= Hash.new
            self[keypath[0]].set_deep(keypath[1 .. -1], value)
        end
    end

end

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

    @@mocked = false

    def self.mock!(datafile=nil)
        @@mocked = true
        @@mockdata = datafile
    end

    def self.mockery
        NOMS::HttpClient::RestMock
    end

    def initialize(opt)
        @delegate = (@@mocked ? self.class.mockery.new(self, opt) :
            NOMS::HttpClient::Real.new(self, opt))
    end

    def config_key
        'httpclient'
    end

    # Used mostly for mocking behavior
    def allow_partial_updates
        # Replace during PUT
        false
    end

    def default_content_type
        'application/json'
    end

    def ignore_content_type
        false
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

    def method_missing(meth, *args, &block)
        @delegate.send(meth, *args, &block)
    end

end

class NOMS::HttpClient::RestMock < NOMS::HttpClient

    def initialize(delegator, opt)
        @delegator = delegator
        @data = { }
        @opt = opt
        @opt['return-hash'] = true unless @opt.has_key? 'return-hash'
        self.dbg "Initialized with options: #{opt.inspect}"
    end

    def allow_partial_updates
        @delegator.allow_partial_updates
    end

    def config_key
        @delegator.config_key
    end

    def default_content_type
        @delegator.default_content_type
    end

    def ignore_content_type
        @delegator.ignore_content_type
    end


    def id_field(dummy=nil)
        'id'
    end

    def maybe_save
        if @@mockdata
            File.open(@@mockdata, 'w') { |fh| fh << JSON.pretty_generate(@data) }
        end
    end

    def maybe_read
        if @@mockdata and File.exist? @@mockdata
            @data = File.open(@@mockdata, 'r') { |fh| JSON.load(fh) }
        end
    end

    def all_data
        maybe_read
        @data
    end

    def do_request(opt={})
        maybe_read
        method = [:GET, :PUT, :POST, :DELETE].find do |m|
            opt.has_key? m
        end
        method ||= :GET
        opt[method] ||= ''

        rel_uri = opt[method]
        dbg "relative URI is #{rel_uri}"
        url = URI.parse(@opt[config_key]['url'])
        url.path = rtrim(url.path) + '/' + ltrim(rel_uri) unless opt[:absolute]
        url.query = opt[:query] if opt.has_key? :query
        dbg "url=#{url}"

        # We're not mocking absolute URLs specifically
        case method

        when :PUT
            # Upsert - whole objects only
            dbg "Processing PUT"
            @data[url.host] ||= { }
            collection_path_components = url.path.split('/')
            id = collection_path_components.pop
            collection_path = collection_path_components.join('/')
            @data[url.host][collection_path] ||= [ ]
            object_index =
                @data[url.host][collection_path].index { |el| el[id_field(collection_path)] == id }
            if object_index.nil?
                object = opt[:body].merge({ id_field(collection_path) => id })
                dbg "creating in collection #{collection_path}: #{object.inspect}"
                @data[url.host][collection_path] << opt[:body].merge({ id_field(collection_path) => id })
            else
                if allow_partial_updates
                    object = @data[url.host][collection_path][object_index].merge(opt[:body])
                    dbg "updating in collection #{collection_path}: to => #{object.inspect}"
                else
                    object = opt[:body].merge({ id_field(collection_path) => id })
                    dbg "replacing in collection #{collection_path}: #{object.inspect}"
                end
                @data[url.host][collection_path][object_index] = object
            end
            maybe_save
            object

        when :POST
            # Insert/Create
            dbg "Processing POST"
            @data[url.host] ||= { }
            collection_path = url.path
            @data[url.host][collection_path] ||= [ ]
            id = opt[:body][id_field(collection_path)] || opt[:body].object_id
            object = opt[:body].merge({id_field(collection_path) => id})
            dbg "creating in collection #{collection_path}: #{object.inspect}"
            @data[url.host][collection_path] << object
            maybe_save
            object

        when :DELETE
            dbg "Processing DELETE"
            if @data[url.host]
                if @data[url.host].has_key? url.path
                    # DELETE on a collection
                    @data[url.host].delete url.path
                    true
                elsif @data[url.host].has_key? url.path.split('/')[0 .. -2].join('/')
                    # DELETE on an object by Id
                    path_components = url.path.split('/')
                    id = path_components.pop
                    collection_path = path_components.join('/')
                    object_index = @data[url.host][collection_path].index { |obj| obj[id_field(collection_path)] == id }
                    if object_index.nil?
                        raise "Error (#{self.class} making #{config_key} request " +
                            "(404): No such object id (#{id_field(collection_path)} == #{id}) in #{collection_path}"
                    else
                        @data[url.host][collection_path].delete_at object_index
                    end
                    maybe_save
                    true
                else
                    raise "Error (#{self.class}) making #{config_key} request " +
                        "(404): No objects at location or in collection #{url.path}"
                end
            else
                raise "Error (#{self.class}) making #{config_key} request " +
                    "(404): No objects on #{url.host}"
            end

        when :GET
            dbg "Performing GET"
            if @data[url.host]
                dbg "we store data for #{url.host}"
                if @data[url.host].has_key? url.path
                    # GET on a collection
                    # TODO get on the query string
                    dbg "returning collection #{url.path}"
                    @data[url.host][url.path]
                elsif @data[url.host].has_key? url.path.split('/')[0 .. -2].join('/')
                    # GET on an object by Id
                    path_components = url.path.split('/')
                    id = path_components.pop
                    collection_path = path_components.join('/')
                    dbg "searching in collection #{collection_path}: id=#{id}"
                    dbg "data: #{@data[url.host][collection_path].inspect}"
                    object = @data[url.host][collection_path].find { |obj| obj[id_field(collection_path)] == id }
                    if object.nil?
                        raise "Error (#{self.class} making #{config_key} request " +
                            "(404): No such object id (#{id_field(collection_path)} == #{id}) in #{collection_path}"
                    end
                    dbg "   found #{object.inspect}"
                    object
                else
                    raise "Error (#{self.class}) making #{config_key} request " +
                        "(404): No objects at location or in collection #{url.path}"
                end
            else
                raise "Error (#{self.class}) making #{config_key} request " +
                    "(404): No objects on #{url.host}"
            end
        end
    end

end

class NOMS::HttpClient::Real < NOMS::HttpClient

    def initialize(delegator, opt)
        @delegator = delegator
        @opt = opt
        @opt['return-hash'] = true unless @opt.has_key? 'return-hash'
        self.dbg "Initialized with options: #{opt.inspect}"
    end

    def config_key
        @delegator.config_key
    end

    def default_content_type
        @delegator.default_content_type
    end

    def ignore_content_type
        @delegator.ignore_content_type
    end


    def do_request(opt={})
        method = [:GET, :PUT, :POST, :DELETE].find do |m|
            opt.has_key? m
        end
        if method == nil
          method = :GET
          opt[method] = ''
        end
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
          request['Content-Type'] = content_type
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
                # Ruby JSON doesn't like bare values in JSON, we'll try to wrap these as
                # one-element array
                bodytext = response.body
                bodytext = '[' + bodytext + ']' unless ['{', '['].include? response.body[0].chr
               JSON.parse(bodytext)
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
            ['message', 'error', 'error_message'].each do |key|
                return structure[key].to_s if structure.has_key? key
            end
            body_text.to_s
        rescue
            body_text.to_s
        end
    end

end
