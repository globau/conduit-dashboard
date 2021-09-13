#!/usr/bin/env perl
use FindBin qw( $RealBin );
use lib $RealBin;

use Dash::Cache;
use Dash::RPC;
use Mojo::File;
use Mojolicious::Lite;

app->secrets('!Dash!');
if (($ARGV[0] // '') eq 'daemon' && app->mode eq 'production') {
    Mojo::File->new("$RealBin/dashboard.app.pid")->spurt("$$\n");
}
Dash::Cache->init();

get '/' => 'index';

group {
    get '/rpc/untriaged' => sub { Dash::RPC->untriaged(@_) };
    get '/rpc/stalled'   => sub { Dash::RPC->stalled(@_)   };
    get '/rpc/tally'     => sub { Dash::RPC->tally(@_)     };
    get '/rpc/p1'        => sub { Dash::RPC->p1(@_)        };
    get '/rpc/p2'        => sub { Dash::RPC->p2(@_)        };
    get '/rpc/upstream'  => sub { Dash::RPC->upstream(@_)  };
};

helper javascript_file => sub {
    my ($c, $file) = @_;
    my $mtime = app->static->file('static/' . $file)->mtime;
    return Mojo::ByteStream->new(
        '<script src="static/' . $file . '?' . $mtime . '"></script>'
    );
};

helper stylesheet_file => sub {
    my ($c, $file) = @_;
    my $mtime = app->static->file('static/' . $file)->mtime;
    return Mojo::ByteStream->new(
        '<link href="static/' . $file . '?' . $mtime . '" rel="stylesheet">'
    );
};

hook after_render => sub {
    Dash::Cache->delete_stale();
};

app->start;
