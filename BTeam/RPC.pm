package BTeam::RPC;
use strict;
use utf8;

use BTeam::Bugzilla;
use BTeam::Constants;
use BTeam::Date;
use Mojo::JSON qw(j);
use List::Util qw(any);

sub untriaged {
    my ($class, $app) = @_;
    my $result;

    my $bugs = $class->_bugs(
        keywords => 'conduit-triaged',
        keywords_type => 'nowords',
        );
    BUG: foreach my $bug (@$bugs) {
        # skip needinfo
        foreach my $flag (@{ $bug->{flags} }) {
            next unless $flag->{name} eq 'needinfo';
            my $requestee = $flag->{requestee};
            next BUG unless grep { $requestee eq $_ } BTEAM;
        }
        delete $bug->{flags};

        push @$result, $bug;
    }

    $class->_last_comments($result);
    $result = $class->_prepare($result, 'last_comment_time_age');
    $app->render( json => $result );
}

sub p1 {
    my ($class, $app) = @_;
    my $result;

    my $bugs = $class->_bugs(
        priority     => 'P1',
        _include_bmo => 1,
        );
    foreach my $bug (@$bugs) {
        if ($bug->{product} eq 'bugzilla.mozilla.org') {
            $bug->{component} = '⒝ ' . $bug->{component};
        } else {
            $bug->{component} = '⒞ ' . $bug->{component};
        }
        push @$result, $bug;
    }

    $class->_last_comments($result);
    $result = $class->_prepare($result, 'last_comment_time_age');
    $app->render( json => $result );
}

sub p2 {
    my ($class, $app) = @_;
    my $result;

    $result = $class->_bugs(
        priority     => 'P2',
        keywords => 'conduit-upstream',
        keywords_type => 'nowords',
        );

    $class->_last_comments($result);
    $result = $class->_prepare($result, 'last_comment_time_age');
    $app->render( json => $result );
}

sub stalled {
    my ($class, $app) = @_;
    my $result;

    my $bugs = $class->_bugs();
    BUG: foreach my $bug (@$bugs) {
        foreach my $flag (@{ $bug->{flags} }) {
            next unless $flag->{name} eq 'needinfo';
            my $requestee = $flag->{requestee};
            $bug->{needinfo_time} = $flag->{creation_date};
            $bug->{needinfo} = $requestee;
        }
        next unless $bug->{needinfo};
        delete $bug->{flags};

        push @$result, $bug;
    }
    $result = $class->_prepare($result, 'needinfo_time_age');
    $app->render( json => $result );
}

sub upstream {
    my ($class, $app) = @_;
    my $result;

    my $bugs = $class->_bugs(
        keywords => 'conduit-triaged,conduit-upstream',
    );
    BUG: foreach my $bug (@$bugs) {
        push @$result, $bug;
    }

    $class->_last_comments($result);
    $result = $class->_prepare($result, 'last_comment_time_age');
    $app->render( json => $result );
}

sub tally {
    my ($class, $app) = @_;
    my $base = 'https://bugzilla.mozilla.org/';
    my @buckets = qw( assigned unassigned stalled upstream );
    my @priorities = qw( -- P1 P2 P3 P4 P5 );

    my %tally;
    foreach my $bucket (@buckets) {
        foreach my $pri (@priorities) {
            $tally{$bucket}{$pri} = [];
        }
    }

    my $bugs = $class->_bugs();
    foreach my $bug (@$bugs) {
        my $priority = $bug->{priority};

        my $stalled = 0;
        foreach my $flag (@{ $bug->{flags} }) {
            next unless $flag->{name} eq 'needinfo';
            $stalled = 1;
            last;
        }

        if (any { $_ eq 'conduit-upstream' } @{ $bug->{keywords } }) {
            push @{ $tally{upstream}{$priority}}, $bug->{id};
        } elsif ($stalled) {
            push @{ $tally{stalled}{$priority}}, $bug->{id};
        } elsif ($bug->{assigned_to} eq 'nobody@mozilla.org') {
            push @{ $tally{unassigned}{$priority}}, $bug->{id};
        } else {
            push @{ $tally{assigned}{$priority}}, $bug->{id};
        }
    }

    my @result;
    push @result, ['Priority', map { ucfirst } @buckets];
    foreach my $pri (@priorities) {
        my @row;
        foreach my $bucket (@buckets) {
            my $count = scalar(@{ $tally{$bucket}{$pri} });
            my $warn = ($pri eq 'P2') && ($count >= 20) ? 1 : 0;
            my $url;
            if ($count == 1) {
                $url = $base . 'show_bug.cgi?id=' . $tally{$bucket}{$pri}->[0];
            } else {
                $url = $base . 'buglist.cgi?bug_id=' . join('%2C', @{ $tally{$bucket}{$pri} });
            }
            push @row, { priority => $pri, count => $count, warn => $warn, url => $url };
        }
        push @result, \@row;
    }

    $app->render( json => \@result );
}

sub _bugs {
    my ($class, %args) = @_;
    my $include_fields = join(',', qw(
        assigned_to
        component
        creation_time
        depends_on
        flags
        groups
        id
        keywords
        priority
        status
        summary
        url
        product
    ));
    my $include_bmo = delete $args{_include_bmo};
    my $bugs = BTeam::Bugzilla->search({
        include_fields  => $include_fields,
        product         => 'Conduit',
        bug_status      => '__open__',
        %args,
    });
    push @$bugs, @{ BTeam::Bugzilla->search({
        include_fields  => $include_fields,
        product         =>'bugzilla.mozilla.org',
        component       => 'Extensions: PhabBugz',
        bug_status      => '__open__',
        %args,
    }) };
    if ($include_bmo) {
        push @$bugs, @{ BTeam::Bugzilla->search({
            include_fields  => $include_fields,
            product         =>'bugzilla.mozilla.org',
            bug_status      => '__open__',
            %args,
        }) };
    }
    my @result;
    foreach my $bug (@$bugs) {
        # meta bugs are always excluded
        next if any { $_ eq 'meta' } @{ $bug->{keywords } };

        $bug->{summary} = '' if @{ $bug->{groups} // [] };
        push @result, $bug;
    }
    return \@result;
}

sub _last_comments {
    my ($class, $bugs) = @_;
    my $comments = BTeam::Bugzilla->comments({
        bug_ids => [ map { $_->{id} } @$bugs ],
        include_fields  => ['author', 'time'],
    });
    foreach my $bug (@$bugs) {
        next unless exists $comments->{$bug->{id}};
        my $comment = pop @{ $comments->{$bug->{id}}->{comments} };
        $bug->{last_comment_time} = $comment->{time};
        $bug->{last_commenter} = $comment->{author} unless @{ $bug->{groups} // [] };
    }
}

sub _prepare {
    my ($class, $bugs, $sort_field) = @_;

    my $now = time();
    foreach my $bug (@$bugs) {
        # fix dates
        foreach my $field (qw(creation_time cf_due_date last_comment_time needinfo_time)) {
            next unless exists $bug->{$field} && $bug->{$field};
            $bug->{$field . '_epoch'} = BTeam::Date->new($bug->{$field})->epoch;
            $bug->{$field . '_age'} = $now - $bug->{$field . '_epoch'};
        }

        # url --> phid
        if ($bug->{url} !~ m{^https://(?:admin\.phacility\.com/PHI|secure\.phabricator\.com/T)\d+$}) {
            delete $bug->{url};
        }
    }

    # sort
    if ($sort_field) {
        return [ sort { $b->{$sort_field} <=> $a->{$sort_field} } @$bugs ];
    } else {
        return $bugs;
    }
}

1;
