#!/usr/bin/env perl
use local::lib;

use FindBin qw( $RealBin );
use lib $RealBin;

use BTeam::Cache;
use BTeam::RPC;
use Mojo::File;
use Mojolicious::Lite;

app->secrets('!bteam!');
$0 = 'bteam-dashboard.app';
if (($ARGV[0] // '') eq 'daemon' && app->mode eq 'production') {
    Mojo::File->new("$RealBin/bteam-dashboard.app.pid")->spurt("$$\n");
}

get '/' => 'index';

group {
    get '/rpc/untriaged' => sub { BTeam::RPC->untriaged(@_) };
    get '/rpc/p1'        => sub { BTeam::RPC->p1(@_)        };
    get '/rpc/stalled'   => sub { BTeam::RPC->stalled(@_)   };
    get '/rpc/stories'   => sub { BTeam::RPC->stories(@_)   };
    get '/rpc/upstream'  => sub { BTeam::RPC->upstream(@_)  };
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
    BTeam::Cache->delete_stale();
};

app->start;
