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
}

teardown() {
    rm -rf test/etc
}

@test "noms-mock cmdb" {
    cat >test/data.json <<EOF
{ "cmdb": {
  "/cmdb_api/v1/system": [
     { "id": "test1.example.com",
       "fqdn": "test1.example.com",
       "status": "idle",
       "environment": "testing",
       "data_center_code": "DC1",
       "ip_address": "10.0.0.1" }
    ]
  }
}
EOF
    noms --config=test/etc/noms.conf --mock=test/data.json cmdb show test1.example.com
}
