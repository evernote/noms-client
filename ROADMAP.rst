noms
====

This is the roadmap for a second-generation of the 'noms' general purpose interface.

**noms** is a remote command-line interface interpreter. It's designed to be a stable runtime environment for interpreting server-defined command-line interfaces for (principally) rest-like data stores (or for commands that are side-effect free, but *not* commands that change any state on the system on which the command runs).

The web browser is a platform in which the operator of a web service can implement a graphical user interface to data it controls. For example, it's a common pattern to offer access to services and data via a ReST or ReST-like interface, making http requests against a remote API understanding the HTTP verbs and returning results in the form of HTTP responses, header metadata and response bodies containing serialized data (e.g. JSON). Such interfaces are generally implemented in a combination of HTML documents and Javascript which modifies the document model of the HTML page(s).

**noms** enables an author to offer a command-line interface designed along the same pattern: structured documents modified by javascript programs, interpreted and rendered on the client. **noms** has sandboxing similar to web browsers (no modifying of local storage outside of restricted, application-specific local storage and automatic caching of javascript files).

**noms** is *not* a web browser and is not designed to offer terminal user interfaces like lynx or elinks. It is also *not* an interactive shell--it's designed to be used from a shell. It maintains authenticated sessions state when necessary.

Syntax
------

The basic way of invoking an **noms** command is as follows::

  noms *url* *options* *arguments*

**noms** invokes the app at *url* with the given options and arguments, displaying the results.

Special URLs
~~~~~~~~~~~~

Certain invalid "URLs" are interpreted specially:

* ``noms login *url*``

Normally **noms** handles user authentication implicitly. With this command, it does a HEAD request against the application URL, forcing login if required.

* ``noms logout *url*``

Causes **noms** to forget its session state for the given application URL.

* ``noms *bookmark*[/arg] ...``

The **noms** itself has a configuration file (``~/.noms``, ``/usr/local/etc/noms.conf``, ``/etc/noms.conf`` in that order) which defines bookmarks to different URLs. For example, given the following in ``/etc/noms.conf``::

  { 
    "cmdb": "https://cmdb.noms-example.com/cmdb.json",
    "instance": "https://ncc-api.noms-example.com/ncc-api.json",
    "nagios": "https://nagios.noms-example.com/nagui.json",
    "nag": "https://nagios.noms-exmaple.com/nagui.json"
  }

When invoked in the following ways, it's the equivalent to the command on the right:

Command given
noms cmdb query fqdn~^m00         noms https://cmdb.noms-example.com/cmdb.json query fqdn~^m00 # argv[0] set to 'cmdb'
noms cmdb/env list                noms https://cmdb.noms-example.com/cmdb.json list            # argv[0] set to 'cmdb/env'
noms nag alerts                   noms https://cmdb.noms-example.com/nagui.json alerts         # argv[0] set to 'nag'

Implementation
--------------

If the type is ``text/plain``, it's simply displayed.

If the type is a recognized data serialization format:

* application/json
* application/x-json
* text/json
* application/yaml
* application/x-yaml
* text/yaml
* text/csv (a list of objects)

If the fetched content is a single object and the object has the top-level key '$doctype', it may be interpreted according to "Dynamic Doctypes", below. Otherwise, it is assumed to be either a single object to display or a list of such. Otherwise **noms** will render the object or array using its default format (usually YAML).

Dynamic Doctypes
~~~~~~~~~~~~~~~~

The principle dynamic doctype is the ``noms-v2``, which is an object with the following top-level attributes:

``$doctype``
  Must be ``noms-v2``. In future, backwards-incompatible extensions may be implemented in ``noms-v3`` or higher doctypes.

``$format-fields``
  An array of objects, each having (at least) a ``name`` and ``width`` attribute. May also include a ``label`` attribute
  for the column heading.

``$body``
  The body of the document is the data to display. See `Output Description Notation`_ below.

Output Description Notation
~~~~~~~~~~~~~~~~~~~~~~~~~~~

The following entities are allowed in the body of a **noms=2** document.

* Arrays - Each item in the array is concatenated with a line-break between them.
* Strings and numbers - A string or number is just displayed
* Raw objects - Raw objects are rendered using **noms** default formatting (usually YAML)
* Described objects - Described objects are data along with information on how to render them. A described object
  has a top-level attribute called **$type** which defines how the described object is rendered.

  * ``$type``: **object-list** An object list is a (usually) tabular list of objects with information on how
    wide to make the fields or how to otherwise serialize the objects. It has the following attributes:

    * **render**: The format in which to render, one of: **json**, **yaml**, **text** (default **text**)
    * **fields**: Field names, headings and widths
    * **objects**: The objects to render

  * ``$type``: **object** An object described-object has the following attributes:

    * **render**: The format in which to render, one of: **json**, **yaml**, **text** (default **yaml**)
    * **object**: The object data

Putting it all together
-----------------------

Example **noms** conversation::

  bash$ noms https://cmdb.noms-example.com/cmdb.json --format=csv system fqdn~^m00

  noms >> GET https://cmdb.noms-example.com/cmdb.json
  noms << set 'document' to retrieved object:
  { "$doctype": "appdoc",
    "$script": ["lib/optconfig.js", "noms/cmdb.js", "noms/cli.js"],
    "$body": null
  }
  noms << set 'document.argv' to ["--format=csv", "system", "fqdn~^m00"]
  noms >> GET https://cmdb.noms-example.com/lib/optconfig.js
  noms << evaluate javascript option-parsing library optconfig.js
  noms >> GET https://cmdb.noms-example.com/noms/cmdb.js
  noms << evaluate noms cmdb client library
  noms >> GET https://cmdb.noms-example.com/noms/cli.js
  noms << evaluate noms cli library
  cli.js << calls optconfig().parse with optspec
  optconfig.js << sets document.argv to ["system", "fqdn~^m00"]
  optconfig.js << sets document.options to { "format": "csv" }
  cli.js << call noms_cmdb().query("system", "fqdn~^m00")
  noms/cmdb.js << http.request("https://cmdb.noms-example.com/cmdb_api/v1/system/?fqdn~^m00")
  cli.js << sets document.body to return objects to render
  { "$doctype": "appdoc",
    "$script": ["lib/optconfig.js", "noms/cmdb.js", "noms/cli.js"],
    "$body": [{
      "$type": "object-list",
      "render": "csv",
      "fields": [
        { "name": "fqdn", "width": 36 },
        { "name": "environment_name", "width": 16, "heading": "environment" },
        { "name": "status", "width": 15 },
        { "name": "roles", "width": 15 },
        { "name": "ipaddress", "width": 15 },
        { "name": "data_center_code": 11, "heading": "datacenter" } ],
      "objects": [
        { "fqdn": "m001.noms-example.com",
          "environment_name": "production",
          "status": "production",
          "roles": "build",
          "ipaddress": "10.8.9.10",
          "data_center_code": "US2" },
        { "fqdn": "m002.noms-example.com",
          "environment_name": "testing",
          "status": "allocated",
          "roles": "webserver",
          "ipaddress": "10.8.9.11",
          "data_center_code": "US2" }
        ]
      }
    ]
  }

  noms >> print output
  fqdn,environment,status,roles,ipaddress,datacenter
  "m001.noms-example.com",production,production,build,10.8.9.10,US2
  "m002.noms-example.com",allocated,testing,webserver,10.8.9.11,US2

  bash$ noms https://ncc-api.noms-example.com/ncc.json show m002.noms-example.com

   { "$doctype": "appdoc",
     "$script": ["noms/optconfig.js", 
        { "name": "name", "width": 36 },
        { "name": "status", "width": 10 },
        { "name": "size", "width": 10 },
        { "name": "image", "width": 15 },
        { "name": "id", "width": 37 }
     ]
     "$body": null
   }

  name                                 status     size       image           id                                  
  m0000291.noms-example.net            active     m1.small   deb6            d8c4c29e-785f-49ef-9d31-e4a71e9954fc
  m0000290.noms-example.net            active     m1.small   deb7            33a88a1d-49a4-4c26-9a0c-b699703f5e64
  m0000289.noms-example.net            active     m1.small   deb7            fd82f522-f305-4150-a969-1b8b9fd2d91d
  m0000288.noms-example.net            error      m1.small   deb6            9d7f1c55-5f8f-4f98-9bf8-c1156a0506d2
  m0000287.noms-example.net            active     m1.small   deb6            c4a6310d-4927-4e79-8170-443172eb9a7c
  m0000286.noms-example.net            active     m1.small   centos6.2       88c654b6-77f2-4995-affb-c3a3bac16bd0
  m0000277.noms-example.net            active     m1.small   deb6            e34e4a8f-81ef-42a3-a9c0-40933be7595f

Invoked scripts have access to the following global objects:

* **window** - This has information about the terminal environment in which **noms** is being invoked. It has the following attributes:
  * **height** - Height (if known)
  * **width**  - Width (if known)
  * **isatty** - true if the output stream is a terminal
  * **document** - The document global object
* **document** - The document object is the current document being rendered by **noms**. In addition to the attributes of the document itself, it has the following:
  * **argv** - The arguments being invoked. The first element of this array is the first argument passed to **noms** itself (not the script it ultimately fetches, but how it's invoked, similar to ``$1``
  * **exitcode** - The numeric exit code with which **noms** will exit. Initially 0.
