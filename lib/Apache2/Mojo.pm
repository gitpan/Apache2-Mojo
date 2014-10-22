package Apache2::Mojo;
our $VERSION = '0.002';


use strict;
use warnings;

use Apache2::Const -compile => qw(OK);
use Apache2::RequestIO;
use Apache2::RequestRec;
use Apache2::RequestUtil;
use Apache2::URI;
use APR::URI;

use Mojo::Loader;


eval "use Apache2::ModSSL";
if ($@) {
    *_is_https = \&_is_https_fallback;
} else {
    *_is_https = \&_is_https_modssl;
}

my $_app = undef;


sub _app {
    if ($ENV{MOJO_RELOAD} and $_app) {
        Mojo::Loader->reload;
        $_app = undef;
    }
    $_app ||= Mojo::Loader->load_build($ENV{MOJO_APP} || 'Mojo::HelloWorld');
    return $_app;
}

sub handler {
    my $r = shift;

    # call _app() only once (because of MOJO_RELOAD)
    my $app = _app;
    my $tx  = $app->build_tx;
    my $req = $tx->req;

    # Request
    _request($r, $req);

    # Handler
    $app->handler($tx);

    my $res = $tx->res;

    # Response
    _response($r, $res);

    return Apache2::Const::OK;
}

sub _request {
    my ($r, $req) = @_;

    my $url  = $req->url;
    my $base = $url->base;

    # headers
    my $headers = $r->headers_in;
    foreach my $key (keys %$headers) {
        $req->headers->header($key, $headers->get($key));
    }

    # path
    $url->path->parse($r->path_info);

    # query
    $url->query->parse($r->parsed_uri->query);

    # method
    $req->method($r->method);

    # base path
    $base->path->parse($r->location);

    # host/port
    my $host = $r->get_server_name;
    my $port = $r->get_server_port;
    $url->host($host);
    $url->port($port);
    $base->host($host);
    $base->port($port);

    # scheme
    my $scheme = _is_https($r) ? 'https' : 'http';
    $url->scheme($scheme);
    $base->scheme($scheme);

    # version
    if ($r->protocol =~ m|^HTTP/(\d+\.\d+)$|) {
        $req->version($1);
    } else {
        $req->version('0.9');
    }

    # body
    $req->state('content');
    $req->content->state('body');
    my $offset = 0;
    while (!$req->is_finished) {
        last unless (my $read = $r->read(my $buffer, 4096, $offset));
        $offset += $read;
        $req->parse($buffer);
    }
}

sub _response {
    my ($r, $res) = @_;

    # status
    $r->status($res->code);

    # headers
    my $headers = $res->headers;
    foreach my $key ($headers->names) {
        my @value = $headers->header($key);
        next unless @value;
        $r->headers_out->set($key => shift @value);
        $r->headers_out->add($key => $_) foreach (@value);
    }

    # content-type gets ignored in headers_out()
    $r->content_type($headers->content_type);

    # body
    my $offset = 0;
    while (1) {
        my $chunk = $res->get_body_chunk($offset);

        # No content yet, try again
        unless (defined $chunk) {
            sleep 1;
            next;
        }

        # End of content
        last unless length $chunk;

        # Content
        my $written = $r->print($chunk);
        $offset += $written;
    }
}

sub _is_https_modssl {
    my ($r) = @_;

    return $r->connection->is_https;
}

sub _is_https_fallback {
    my ($r) = @_;

    return $r->get_server_port == 443;
}


1;

__END__

=pod

=head1 NAME

Apache2::Mojo - mod_perl2 handler for Mojo

=head1 VERSION

version 0.002

=head1 SYNOPSIS

in httpd.conf:

  <Perl>
    use lib '...';
    use Apache2::Mojo;
    use TestApp;
  </Perl>

  <Location />
     SetHandler  perl-script
     PerlSetEnv  MOJO_APP TestApp
     PerlHandler Apache2::Mojo
  </Location>

=head1 DESCRIPTION

This is a mod_perl2 handler for L<Mojo>/L<Mojolicious>.

Set the application class with the environment variable C<MOJO_APP>.

C<MOJO_RELOAD> is also supported (e. g. C<PerlSetEnv MOJO_RELOAD 1>).

=head1 SEE ALSO

L<Apache2>, L<Mojo>, L<Mojolicious>.

=head1 AUTHOR

Uwe Voelker, <uwe.voelker@gmx.de>

=cut