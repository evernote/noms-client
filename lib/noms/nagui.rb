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

  def config_key
    'nagui'
  end

  def system(hostname)
    results = do_request( :query => URI.encode("query=GET hosts|Filter: name ~~ #{hostname}"))
    if results.kind_of?(Array) && results.length > 0
      results[0]
    else
      nil
    end
  end

  def query(type, *condlist)
    do_request(:GET => "#{type}", :query => URI.encode(condlist.join('&')))
  end
end