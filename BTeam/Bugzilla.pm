package BTeam::Bugzilla;
use strict;
use feature 'state';

use BTeam::Cache;
use FindBin qw($RealBin);
use Mojo::File;
use Mojo::JSON qw(j);
use Mojo::URL;
use Mojo::UserAgent;

my $_instance;
sub instance {
    my ($class) = @_;
    return $_instance //= bless({}, $class);
}

sub _ua {
    my ($self) = @_;
    return $self->{ua} //= Mojo::UserAgent->new();
}

sub rest {
    my ($self, $method, $params) = @_;

    state $api_key;
    if (!defined $api_key) {
        if (-e $RealBin . '/api-key') {
            chomp($api_key = Mojo::File->new($RealBin . '/api-key')->slurp);
        } else {
            $api_key = '';
        }
    }

    my $url = Mojo::URL->new('https://bugzilla.mozilla.org/rest/' . $method);
    foreach my $name (sort keys %$params) {
        $url->query->param($name => $params->{$name});
    }
    if ($api_key) {
        $url->query->param(api_key => $api_key);
    }

    if (my $cached = BTeam::Cache->get($url)) {
        return j($cached);
    }

    my $result = $self->_ua->get($url, { X_BUGZILLA_API_KEY => $api_key })->res->json;

    BTeam::Cache->put($url, j($result));
    return $result;
}

#

sub search {
    my ($class, $params) = @_;
    return $class->instance->rest('bug', $params)->{bugs};
}

sub attachments {
    my ($class, $params) = @_;
    if (exists $params->{bug_id}) {
        my $bug_id = delete $params->{bug_id};
        return $class->instance->rest("bug/$bug_id/attachment", $params)->{bugs}->{$bug_id};
    } else {
        my $ids = delete $params->{bug_ids};
        my $id = shift @$ids;
        $params->{ids} = $ids;
        return $class->instance->rest("bug/$id/attachment", $params)->{bugs};
    }
}

sub comments {
    my ($class, $params) = @_;
    if (exists $params->{bug_id}) {
        my $bug_id = delete $params->{bug_id};
        return $class->instance->rest("bug/$bug_id/comment", $params)->{bugs}->{$bug_id}->{comments};
    } else {
        my $ids = delete $params->{bug_ids};
        my $id = shift @$ids;
        $params->{ids} = $ids;
        return $class->instance->rest("bug/$id/comment", $params)->{bugs};
    }
}

1;
