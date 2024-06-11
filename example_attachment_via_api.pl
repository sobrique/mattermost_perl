#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use JSON::XS;
use LWP;
use HTTP::Request::Common;

my $API = 'https://mattermost.url.here/api/v4'; 

#login credentials in mattermost.
my $user = 'username';
my $pass = 'password';

#where to write stuff
my $channel = "bot-test";
my $teamname = "my_mattermost_team";

my $filename = 'example.txt';
my $file_content = 'Here is some content'; # pretty pointless this short, but 'just' load file content or grep a log or something instead. 
                                           ## Note - might need to do some encoding if it's binary too. 

## Create JSON parser.
my $json = JSON::XS -> new;

#create useragent.
my $agent = LWP::UserAgent -> new;

# Authenticate and get a token (NB: Tokens expire) my $login_request = HTTP::Request::Common::POST ( "$API/users/login", 
	                              Content_Type => 'application/json', 
				      Content => JSON::XS -> new -> encode ( {login_id => $user, password => $pass} ),
			      );

my $result = $agent -> request ( $login_request ); my $login_token = $result -> headers -> {token};

# Enumarate teams list to extract team ID. Probably only one unless you're an admin, but ...
my $team_list = $agent->get( "$API/teams", Authorization => "Bearer $login_token" ); my $teams = $json->decode( $team_list->content );

print Dumper $teams;

my $team_id_to_query = "UNKNOWN";

foreach my $team (@$teams) {
    print join( " ", $team->{name}, $team->{id} ), " \n";
    if ( $team->{name} =~ m/$teamname/ ) {
        $team_id_to_query = $team->{id};
    }
}

my $chan_result = $agent->get( "$API/teams/$team_id_to_query/channels/name/$channel",
                                Authorization => "Bearer $login_token" ); my $channel_metadata = $json -> decode ( $chan_result -> content ); my $channel_id = $channel_metadata -> {id};



my $upload = HTTP::Request::Common::POST ( "$API/files?channel_id=$channel_id&filename=$filename",
			      Authorization => "Bearer $login_token",
			      Content_Type => "text/plain",
			      Content => $file_content
			      );

			      ## You'd want to open a file, read content, and... I'd imagine probably encode if if it's binary?

my $upload_response = $agent -> request ( $upload );

my $uploaded_file_metadata = $json -> decode ( $upload_response -> content ); print Dumper $uploaded_file_metadata; my $file_id = $uploaded_file_metadata -> {file_infos} -> [0] -> {id};

print "Got ID of $file_id\n";

my $message_to_channel = HTTP::Request::Common::POST ( "$API/posts",
                              Content_Type => 'application/json',
			      Authorization => "Bearer $login_token",
                              Content => $json -> encode ( { channel_id => $channel_id,
				                           message => "Hello here is your file", 
							   file_ids => [ $file_id ] }),

                              );

my $message_response = $agent -> request ( $message_to_channel ); print Dumper $message_response;
