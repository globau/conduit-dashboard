#!/usr/bin/env perl
BEGIN { $ENV{MOJO_MODE} = 'production'; }
use Mojolicious::Lite;

app->secrets('!bteam!');

get '/' => 'index';

group {
    under sub {
        require BTeam::RPC;
    };
    get '/rpc/pending'      => sub { BTeam::RPC->pending(@_)     };
    get '/rpc/pending_pri'  => sub { BTeam::RPC->pending_pri(@_) };
    get '/rpc/in_progress'  => sub { BTeam::RPC->in_progress(@_) };
    get '/rpc/in_dev'       => sub { BTeam::RPC->in_dev(@_)      };
    get '/rpc/stalled'      => sub { BTeam::RPC->stalled(@_)     };
    get '/rpc/infra'        => sub { BTeam::RPC->infra(@_)       };
    get '/rpc/all'          => sub { BTeam::RPC->all(@_)         };
};

helper javascript_file => sub {
    my ($c, $file) = @_;
    my $mtime = app->static->file($file)->mtime;
    return Mojo::ByteStream->new(
        '<script src="' . $file . '?' . $mtime . '"></script>'
    );
};

helper stylesheet_file => sub {
    my ($c, $file) = @_;
    my $mtime = app->static->file($file)->mtime;
    return Mojo::ByteStream->new(
        '<link href="' . $file . '?' . $mtime . '" rel="stylesheet">'
    );
};

app->start;
