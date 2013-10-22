#!/usr/bin/perl
# /* Copyright 2013 Proofpoint, Inc. All rights reserved.
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

# $Id $

package PPOPS::PP_Inventory;
use Exporter ();
use strict;
use vars qw(
  $VERSION
  @ISA
  @EXPORT
  @EXPORT_TAGS
  @EXPORT_OK);
@ISA    = qw(Exporter);
@EXPORT = qw(
&getRecords
&getRecs
&saveRec
&saveRecord
&getCustomer
&make_json
&eat_json
);
our %EXPORT_TAGS = ( ALL => [ @EXPORT, @EXPORT_OK ] );

use strict;
use JSON;
use Getopt::Std;
use LWP::UserAgent;
use Optconfig;
my @savedARGV=@ARGV;
@ARGV=[];
my $opt = Optconfig->new('ppops-inventory', { 'ppops-inventory-http=s' => 'https',
                                      'ppops-inventory-host=s' => 'cmdb',
                                      'ppops-inventory-api_path=s' => '/inv_api/v1/',
                                      'ppops-inventory-debug' => 0,
                                      'ppops-inventory-timeout' => 320
                                   });

@ARGV=@savedARGV;
my $http  = $opt->{'ppops-inventory-http'};
my $host=$opt->{'ppops-inventory-host'};
my $api_path=$opt->{'ppops-inventory-api_path'};
my $api = $api_path . 'system/';
my $req_type   = "application/json";
my $ua = LWP::UserAgent->new;
$ua->timeout($opt->{'ppops-inventory-timeout'});
my @failures;
my $DEBUG=0;
if($ENV{INVENTORY_DEBUG} || $opt->{'ppops-inventory-debug'})
{
	$DEBUG=1;
}


=head1 NAME

PPOPS::PP_Inventory - Perl module interface to inventory for fetching and saving entities (most commonaly systems) 

=head1 SYNOPSIS

   use PPOPS::PP_Inventory;

   my $recs = getRecs('system',{fqdn=>somesystem.com},{});
	# returns arrayref of hashes
   my $return_str = saveRec('system',\%hash,$entity_key,
		{user=>'username', pass=>'password'});

=head1 DESCRIPTION

This module accesses the inventory rest API to fetch records vi query (not via full resource path) 
and can save records using the REST PUT method.  The getRecs function defaults to a readonly user if no
config is supplied.  The saveRec function will return error if no user config is supplied.


=head1 AUTHOR

Isaac Finnegan, E<lt>ifinnegan@proofpoint.comE<gt>

=cut



# my %opt;
# getopts('q:h:du',\%opt);
# my $DEBUG = $opt{'d'} ? 1 : 0;
# my $UPDATE = $opt{'u'} ? 1 : 0;
# my $QUERY = $opt{'q'} ? $opt{'q'} : "";
my $full_url   = "$http://$host$api";

my $entity_keys={
	system=>'fqdn',
	device=>'fqdn',
	router=>'fqdn',
	change_queue=>'id',
	inv_audit=>'entity_key',
	user=>'username',
	acl=>'acl_id',
	inv_normalizer=>'id',
	role=>'role_id',
	drac=>'drac_id',
	processor=>'cpu_id',
	blade_chassis=>'fqdn',
	network_switch=>'fqdn',
	load_balancer=>'fqdn',
	power_strip=>'fqdn',
	datacenter_subnet=>'subnet',
	snat=>'comkey',
	pool=>'comkey',
	vip=>'comkey',
	cluster_mta=>'cluster_id',
	cluster=>'cluster_id',
	device_ip=>'ip_address'	
};
################################################

=pod

=over

=item getCustomer
	# lookup customer by cluster_id
	getCustomer({cluster_id=>'000f1901'})
	
	# lookup customer by customer_sid
	getCustomer({customer_id=>'tdameritrade_hosted'})

getCustomer is a utility function that queries CTS for the customer name by looking up 
the customer using the cluster_id or the customer_id

=cut
sub getCustomer{
	my $params=shift;
	my $url='https://api-cts.proofpoint.com/pod_api.cgi?';
	my ($q,$v,@v);
	my $res={};
	if($$params{cluster_id})
	{
		$v=$$params{cluster_id};@v=split("",$v); pop(@v);pop(@v); $v= join("",@v);
		my $decval=hex($v);
		$$res{cluster_id}=$$params{cluster_id};
		#print STDERR $v;

		$q='customer_sid=' . $decval;
	}
	elsif($$params{customer_id})
	{
		$$params{customer_id}=~s/_hosted.*//g;
		$q='customer_id=' . $$params{customer_id};
	}
	$ua->credentials('api-cts.proofpoint.com:443','Proofpoint CTS API Access','inventory','t3stm3');
print STDERR "fetcing $url$q\n" if $DEBUG;
    my $resp=$ua->get($url . $q);
	my $c=$resp->decoded_content;
	my @lines=split("\n",$c);
	my @c=split(/\|/,$lines[1]);
	$$res{sid}=$c[0];
	$$res{customer_id}=$c[2];
	$$res{customer_name}=$c[3];

	return $res;
}


################################################

=pod

=item getRecords

This function is deprecated, use getRecs

=cut

sub getRecords{
	my $params=shift;
	my $url=shift || $full_url;
	my $results;
	my $query='?_format=json';
	foreach(keys(%$params))
	{
		$query.="&$_=$$params{$_}";
	}
	#$query=~s/\*/\%/g;
	print STDERR "fetching: $url$query\n" if $DEBUG;
	my $port= $http eq 'http' ? '80' : '443';
	my $user= 'readonly';
	my $pass= 'readonly';
	$ua->credentials("$host:$port",'Authorized Personnel Only',$user,$pass);
	my $response = $ua->get( "$url$query" );
    if ( $response->code == 200 ) {
		print STDERR "received:" . $response->content . "\n" if $DEBUG;
		if($response->content)
		{
			$results=eat_json($response->content,{allow_nonref=>1,relaxed=>1,allow_unknown=>1}); 
		}
	}
else
{
	print STDERR $response->code . ": " . $response->content . "\n" if $DEBUG;
}
	return $results;
}

=pod

=item getRecs

This function is used to query for entity records from inventory.  Any entity can be queried. 
	
	getRecs($entity_name, \@query,\%config)
	 or
	getRecs($entity_name, \%query,\%config)

$entity_name = just a straight string name of the entity 
Example:
	system
	cluster
	service_instance

\@query
Array ref of query strings.   This is the most flexible way to query, as nonstandard 
operators ( ~ !~ > < ) can be used.
Example:
	[" system_type ~ POD|Eng",
	" data_center_code ~ SC4|TOR6 ",
	" agent_reported > 2011-05-01 "]

\%query
Hash of key/value query parameters.  All key/value are = sign operator queries.
Example: 
	{
		system_type=>"POD",
		data_center_code=>"SC4"
	}


\%config
The configuration hashref is optional for getRecs but can contain the following parameters:
	user	Username. Defaults to 'readonly'
	pass	Password. Defaults to 'readonly'
	path	URL Path. Defatuls to current version api path.  (Currently '/inv_api/v1/' )
	host	API Host. Defaults to cmdb (backend api server)
	http	HTTP Method to use. Defaults to 'http'
	port	HTTP Port to use. Defaults to 80
	format	Data return format URL parameter to pass to the REST API. Defaults to JSON (only current option)

=cut

sub getRecs{
	my($entity,$qparms,$config)=@_;
	$config=$config || {};
	my $query_str="?_format=";
	$query_str.= $config->{'format'} || 'json';
	my $hostname=$config->{'host'} || $host;
	my $http_method=$config->{'http'} || $http;
	my $port= $http_method eq 'http' ? '80' : '443';
	my $path=$config->{'path'} || $api_path;
	my $user=$config->{'user'} || 'readonly';
	my $pass=$config->{'pass'} || 'readonly';
	$ua->credentials("$hostname:$port",'Authorized Personnel Only',$user,$pass);
	my $url = "$http_method://$hostname$path$entity/";
	my $results;
	if(ref $qparms eq 'HASH') {
		foreach(keys(%$qparms))
		{
			$query_str.="&$_=$qparms->{$_}";
		}
	}
	elsif(ref $qparms eq 'ARRAY') {
		foreach my $item (@$qparms) {
			next unless $item =~ /(\w+)([!~>=<]+)(.*)/;
			my $key = $1;
			my $op = $2;
			my $val = $3;
			$query_str.="&${key}${op}${val}";
		}
	}
	print STDERR "fetching: $url$query_str\n" if $DEBUG;
	my $response = $ua->get( "$url$query_str" );
    if ( $response->code == 200 ) {
		print STDERR "received:" . $response->content . "\n" if $DEBUG;
		if($response->content)
		{
			$results=eat_json($response->content,{allow_nonref=>1,relaxed=>1,allow_unknown=>1}); 
		}		
	}
	else
	{
		print STDERR "received code:" . $response->code . " " .  $response->content . "\n" if $DEBUG;		
	}
	return $results;
}

=pod

=item saveRec

This function is used to save a single record using the inventory REST API. Any entity can be saved
	
	saveRec($entity_name, \%record,$key, \%config)

$entity_name = just a straight string name of the entity 
Example:
	system
	cluster
	service_instance

\%record
A hash ref to the fields being changed.  All fields do not need to be submitted to save a record.  If
the record is new then any fields required by the API will need to be present in the hash.

$key
Optional parameter to specify the entity key used in the REST PUT 

\%config
The configuration hashref is required for saveRec and can contain the following parameters:
	user	Username. has no default, this function will error out if no username is supplied'
	pass	Password. has no default, this function will error out if no password is supplied''
	updateonly	If this is set (updateonly=>1) then the function will not try to create the record if 
it does not exist
	key 	The key to use to save the entity against (needed for REST)
	path	URL Path. Defatuls to current version api path.  (Currently '/inv_api/v1/' )
	host	API Host. Defaults to cmdb (backend api server)
	realm	HTTP Auth Realm. Defaults to 'Authorized Personnel Only'
	http	HTTP Method to use. Defaults to 'http'
	port	HTTP Port to use. Defaults to 80
	format	Data return format URL parameter to pass to the REST API. Defaults to JSON (only current option)

=cut

sub saveRec{
	my($entity,$rec,$rec_key,$config)=@_;
	$config=$config || {};
	return 'error: user and pass required'	unless($config->{'user'} && $config->{'pass'});
	my $hostname=$config->{'host'} || $host;
	my $http_method=$config->{'http'} || $http;
	my $port= $http_method eq 'http' ? '80' : '443';
	my $path=$config->{'path'} || $api_path;
	my $realm=$config->{'realm'} || 'Authorized Personnel Only';
	my $user=$config->{'user'} || 'readonly';
	my $pass=$config->{'pass'} || 'readonly';
	my $key=$config->{'key'} || $entity_keys->{$entity};
	my $json=make_json($rec);
	$rec_key=$rec_key || $rec->{$key};
	return 'error: key needed for this entity' unless($key);
	$ua->credentials("$hostname:$port",$realm,$user,$pass);
	my $url = "$http_method://$hostname$path$entity/";
    my $response = $ua->get( "$url$rec_key" );
 	print STDERR "got " . $response->code . " for $url$rec_key\n" if $DEBUG;
   if ( $response->code == 200 ) {
	#return "found in inventory";
        # UPDATE
        my $request = HTTP::Request->new('PUT' => "$url$rec_key");
        $request->content_type('application/json');
        $request->content ($json);
        $response = $ua->request($request);
        
        if( $response->is_success ){
            return " $entity($rec_key) updated successfully.";
        } else {
            return "failed to update $entity($rec_key)" . $response->content;
	#	return 'error';
            #print FAIL "$json\n".$response->status_line.": ".$response->content."\n\n";
        }
    }
	else
	{
		if($config->{'updateonly'})
		{
			return 'no create:updateonly';
		}
		# CREATE
        my $request = HTTP::Request->new('POST' => $url);
        $request->content_type('application/json');
        $request->content ($json);
        $response = $ua->request($request);
        
        if( $response->is_success ){
            return "$entity($rec_key) successfully created.";
        } else {
            return "failed to create $entity($rec_key).  " . $response->content  . $json; 
		return 'error';
            #print FAIL "$json\n".$response->status_line.": ".$response->content."\n\n";
        }
        
	}
    $response = $ua->get( "$url$rec_key" );
    if ( $response->code != 200 ) {
		print STDERR "api says operation successful but no record found after\n" if $DEBUG;
		return "error";
	}
}


##############################################

=pod

=item saveRecord

This function is deprecated, use saveRec

=cut

sub saveRecord{
    my $rec = shift;
	my $updateonly=shift || '';
	my $url=shift || $full_url;
	my $keyval=shift || 'fqdn';
	my $fqdn=$$rec{$keyval};
	my $json=make_json($rec);
	unless($fqdn)
	{
		return "no $keyval found: $json\n";
	}
    my $response = $ua->get( "$url$fqdn" );
	print STDERR "got " . $response->code . " for $url$fqdn\n" if $DEBUG;
    if ( $response->code == 200 ) {
	#return "found in inventory";
        # UPDATE
        my $request = HTTP::Request->new('PUT' => "$url$fqdn");
        $request->content_type('application/json');
        $request->content ($json);
        $response = $ua->request($request);
        
        if( $response->is_success ){
            return "$fqdn updated successfully.";
        } else {
            return "failed to update $fqdn" . $response->content;
	#	return 'error';
            #print FAIL "$json\n".$response->status_line.": ".$response->content."\n\n";
        }
    }
	else
	{
		if($updateonly)
		{
			return 'no create:updateonly';
		}
		# CREATE
        my $request = HTTP::Request->new('POST' => $url);
        $request->content_type('application/json');
        $request->content ($json);
        $response = $ua->request($request);
        
        if( $response->is_success ){
            return "$fqdn successfully created.";
        } else {
            return "failed to create $fqdn.  " . $response->content  . $json; 
		return 'error';
            #print FAIL "$json\n".$response->status_line.": ".$response->content."\n\n";
        }
        
	}
    $response = $ua->get( "$url$fqdn" );
    if ( $response->code != 200 ) {
		print STDERR "api says operation successful but no record found after\n" if $DEBUG;
		return "error";
	} 
}

sub eat_json {
   my ($json_text, $opthash) = @_;
    return ($JSON::VERSION > 2.0 ? from_json($json_text, $opthash) : JSON->new()->jsonToObj($json_text, $opthash));
}

sub make_json {
   my ($obj, $opthash) = @_;
    return ($JSON::VERSION > 2.0 ? to_json($obj, $opthash) : JSON->new()->objToJson($obj, $opthash));
}
