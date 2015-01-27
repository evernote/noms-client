#!/usr/bin/env bats

# @test "noms-mock instance" {
#     noms --mock=/dev/null cloud list
# }

setup() {
    mkdir -p test/etc
    cat >test/etc/noms.conf <<EOF
{ "cmdb": { "url": "http://cmdb/cmdb_api/v1" },
  "ncc":  { "url": "http://ncc-api/ncc_api/v2" }
}
EOF
    cat >test/data.json <<EOF
{ "ncc-api": {
  "/ncc_api/v2": {
    "version": "0.6.9"
  },
  "/ncc_api/v2/clouds": ["os0", "aws"],
  "/ncc_api/v2/clouds/os0": {
     "provider": "openstack",
     "status": "ok"
  },
  "/ncc_api/v2/clouds/os0/instances/1": {
     "name": "testist1.local",
     "id": "1",
     "status": "active",
     "role": [ ],
     "size": "m1.small",
     "image": "deb6",
     "host": "ostack01.local"
  },
  "/ncc_api/v2/clouds/os0/instances/1/console": {
     "url": "vnc://ostack01.local:5959"
  },
  "/ncc_api/v2/sizes": [
    {
      "name": "m1.large",
      "description": "8GB RAM 80GB disk",
      "cores": 4,
      "ram": 8000,
      "disk": 80
    },
    {
      "name": "m1.small",
      "description": "2GB RAM 10GB disk",
      "cores": 1,
      "ram": 2000,
      "disk": 10
    }
  ],
  "/ncc_api/v2/images": [
    {
      "operatingsystemrelease": "6",
      "osfamily": "debian",
      "description": "Debian6 Image",
      "operatingsystem": "Debian"
    },
    {
      "operatingsystemrelease": "7",
      "osfamily": "debian",
      "description": "Debian7 Image",
      "operatingsystem": "Debian"
    }
  ]
  }
}
EOF
}

teardown() {
    rm -rf test/etc
}

@test "noms-admin server-info" {
    noms --config=test/etc/noms.conf --mock=test/data.json describe ncc | grep "version: 0.6.9"
}

@test "noms-admin describe cloud os0" {
    noms --config=test/etc/noms.conf --mock=test/data.json describe cloud os0 | grep 'provider: openstack'
}

@test "noms-admin get console (negative)" {
    noms --config=test/etc/noms.conf --mock=test/data.json instance show os0 1 | grep -v 'console_url'
}

@test "noms-admin get console (positive)" {
    noms --config=test/etc/noms.conf --mock=test/data.json --fields fqdn,console instance show os0 1 |\
        grep 'console: vnc://ostack01.local:5959'
}

