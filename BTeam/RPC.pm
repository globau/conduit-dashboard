package BTeam::RPC;
use strict;

use BTeam::Bugzilla;
use BTeam::Constants;
use BTeam::Date;
use Mojo::JSON qw(j);

sub pending {
    my ($class, $app) = @_;
    my $result;

    my $bugs = $class->_bugs(['Administration', 'Custom Bug Entry Forms']);
    BUG: foreach my $bug (@$bugs) {
        # skip assigned bugs
        next if $bug->{assigned_to} ne 'nobody@mozilla.org';

        # a due_date means it has been answererd
        next if $bug->{cf_due_date};
        delete $bug->{cf_due_date};

        # skip needinfo
        foreach my $flag (@{ $bug->{flags} }) {
            next unless $flag->{name} eq 'needinfo';
            my $requestee = $flag->{requestee};
            next BUG unless grep { $requestee eq $_ } BTEAM;
        }
        delete $bug->{flags};

        # last comment
        my $comment = $class->_last_comment($bug);
        $bug->{last_comment_time} = $comment->{time};
        $bug->{last_commenter} = $comment->{author};

        push @$result, $bug;
    }

    $app->render( text => j($class->_prepare($result)), format => 'json' );
}

sub in_progress {
    my ($class, $app) = @_;
    my $result;

    my $bugs = $class->_bugs(['Administration', 'Custom Bug Entry Forms', 'Infrastructure']);
    BUG: foreach my $bug (@$bugs) {
        # skip unassigned bugs
        next if
            $bug->{assigned_to} eq 'nobody@mozilla.org'
            && $bug->{cf_due_date} eq '';

        # last comment
        my $comment = $class->_last_comment($bug);
        $bug->{last_comment_time} = $comment->{time};
        $bug->{last_commenter} = $comment->{author};

        # skip needinfo
        foreach my $flag (@{ $bug->{flags} }) {
            next BUG if $flag->{name} eq 'needinfo';
        }
        delete $bug->{flags};

        my $comment = $class->_last_comment($bug);
        $bug->{state_date} = $comment->{time};

        push @$result, $bug;
    }

    $app->render( text => j($class->_prepare($result)), format => 'json' );
}

sub stalled {
    my ($class, $app) = @_;
    my $result;

    my $bugs = $class->_bugs(['Administration', 'Custom Bug Entry Forms']);
    BUG: foreach my $bug (@$bugs) {
        foreach my $flag (@{ $bug->{flags} }) {
            next unless $flag->{name} eq 'needinfo';
            my $requestee = $flag->{requestee};
            next BUG if grep { $requestee eq $_ } BTEAM;
            $bug->{needinfo_time} = $flag->{creation_date};
            $bug->{needinfo} = $requestee;
        }
        next unless $bug->{needinfo};
        delete $bug->{flags};

        push @$result, $bug;
    }

    $app->render( text => j($class->_prepare($result)), format => 'json' );
}

sub infra {
    my ($class, $app) = @_;
    my $result;

    my $bugs = $class->_bugs(['Infrastructure']);
    BUG: foreach my $bug (@$bugs) {
        # skip bugs with open blockers
        # because we don't authentiate, we can't tell if non-public bugs are
        # resolved.  assume they are resolved.
        if (@{ $bug->{depends_on} }) {
            my $depends_on_bugs = BTeam::Bugzilla->search({
                id              => join(',', @{ $bug->{depends_on} }),
                include_fields  => 'id',
                bug_status      => '__closed__',
            });
            next if @$depends_on_bugs == @{ $bug->{depends_on} };
        }

        # last comment
        my $comment = $class->_last_comment($bug);
        $bug->{last_comment_time} = $comment->{time};
        $bug->{last_commenter} = $comment->{author};

        # skip needinfo
        foreach my $flag (@{ $bug->{flags} }) {
            next unless $flag->{name} eq 'needinfo';
            $bug->{needinfo_time} = $flag->{creation_date};
            $bug->{needinfo} = $flag->{requestee};
        }
        delete $bug->{flags};

        my $comment = $class->_last_comment($bug);
        $bug->{state_date} = $comment->{time};

        push @$result, $bug;
    }

    $app->render( text => j($class->_prepare($result)), format => 'json' );
}

sub all {
    my ($class, $app) = @_;

    my $bugs = $class->_bugs(['Administration', 'Custom Bug Entry Forms', 'Infrastructure']);
    $app->render( text => j($class->_prepare($bugs)), format => 'json' );
}

sub _bugs {
    my ($class, $components) = @_;
    return BTeam::Bugzilla->search({
        include_fields  => join(',', qw(
            id
            summary
            creation_time
            cf_due_date
            component
            flags
            status
            assigned_to
            depends_on
        )),
        product         => 'bugzilla.mozilla.org',
        component       => $components,
        bug_status      => '__open__',
    });
}

sub _last_comment {
    my ($class, $bug) = @_;
    my $comments = BTeam::Bugzilla->comments({
        bug_id          => $bug->{id},
        include_fields  => ['author', 'time'],
    });
    return pop @$comments;
}

sub _prepare {
    my ($class, $bugs) = @_;

    # fix dates
    my $now = time();
    foreach my $bug (@$bugs) {
        foreach my $field (qw(creation_time cf_due_date last_comment_time needinfo_time)) {
            next unless exists $bug->{$field} && $bug->{$field};
            $bug->{$field . '_epoch'} = BTeam::Date->new($bug->{$field})->epoch;
            $bug->{$field . '_age'} = $now - $bug->{$field . '_epoch'};
        }
    }

    return $bugs;
}

1;
