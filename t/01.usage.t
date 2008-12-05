#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

plan skip_all => 'set TEST_APACHE2_MOJO to run tests against http://localhost/mojo'
    unless $ENV{TEST_APACHE2_MOJO};

plan tests => 2;


require LWP::Simple;


my $base = 'http://localhost/mojo';

# simple request
my $html = LWP::Simple::get($base);
like($html, qr/Congratulations, your Mojo is working!/, 'simple get request');

# get request with params
$html = LWP::Simple::get("$base/diag/dump_params?id=123&id=456&abc=");
like($html, qr/'id' => \[\s+'123',\s+'456'\s+\]/s, 'get request with params');

