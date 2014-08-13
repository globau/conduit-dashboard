package BTeam::RPC;
use strict;

use BTeam::Bugzilla;
use BTeam::Constants;
use BTeam::Date;
use Mojo::JSON qw(j);

sub unanswered {
    my ($class, $app) = @_;
    my $result;

    my $bugs = $class->_bugs();
    BUG: foreach my $bug (@$bugs) {

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

        # check the last commenter on admin bugs
        if ($bug->{component} eq 'Administration') {
            my $comment = $class->_last_comment($bug);
            my $author = $comment->{author};
            next if grep { $author eq $_ } BTEAM;
            $bug->{state_date} = $comment->{time};
        }

        push @$result, $bug;
    }

    $app->render( text => j($class->_prepare($result)), format => 'json' );
}

sub pending {
    my ($class, $app) = @_;
    my $result;

    my $bugs = $class->_bugs();
    BUG: foreach my $bug (@$bugs) {
        next unless $bug->{status} eq 'NEW' or $bug->{status} eq 'ASSIGNED';

        # due_date
        if ($bug->{component} eq 'Custom Bug Entry Forms') {
            next unless $bug->{cf_due_date};
        }

        # check the last commenter on admin bugs
        if ($bug->{component} eq 'Administration') {
            my $comment = $class->_last_comment($bug);
            my $author = $comment->{author};
            next unless grep { $author eq $_ } BTEAM;
            $bug->{state_date} = $comment->{time};
        }

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

sub needinfo {
    my ($class, $app) = @_;
    my $result;

    my $bugs = $class->_bugs();
    BUG: foreach my $bug (@$bugs) {
        foreach my $flag (@{ $bug->{flags} }) {
            next unless $flag->{name} eq 'needinfo';
            my $requestee = $flag->{requestee};
            next BUG if grep { $requestee eq $_ } BTEAM;
            $bug->{state_date} = $flag->{creation_date};
            $bug->{needinfo} = $requestee;
        }
        next unless $bug->{state_date};
        delete $bug->{flags};

        push @$result, $bug;
    }

    $app->render( text => j($class->_prepare($result)), format => 'json' );
}

sub all {
    my ($class, $app) = @_;

    my $bugs = $class->_bugs();
    $app->render( text => j($class->_prepare($bugs)), format => 'json' );
}

sub _bugs {
    return BTeam::Bugzilla->search({
        include_fields  => 'id,summary,creation_time,cf_due_date,component,flags,status,assigned_to',
        product         => 'bugzilla.mozilla.org',
        component       => ['Administration', 'Custom Bug Entry Forms'],
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
        $bug->{state_date} //= $bug->{creation_time};
        foreach my $field (qw(creation_time state_date)) {
            next unless exists $bug->{$field};
            $bug->{$field . '_epoch'} = BTeam::Date->new($bug->{$field})->epoch;
            $bug->{$field . '_age'} = $now - $bug->{$field . '_epoch'};
        }
    }

    return [ sort { $a->{state_date_epoch} <=> $b->{state_date_epoch} } @$bugs ];
}

1;
