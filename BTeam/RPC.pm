package BTeam::RPC;
use strict;

use BTeam::Bugzilla;
use BTeam::Constants;
use BTeam::Date;
use Mojo::JSON qw(j);

sub pending {
    my ($class, $app) = @_;
    my $result;

    my $bugs = $class->_bugs([
        'Administration',
        'Custom Bug Entry Forms',
        'Extensions: MozProjectReview',
    ]);
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

        push @$result, $bug;
    }

    $class->_last_comments($result);
    $result = $class->_prepare($result, 'last_comment_time_age');
    $app->render( text => j($result), format => 'json' );
}

sub in_progress {
    my ($class, $app) = @_;
    my $result;

    my $bugs = $class->_bugs([
        'Administration',
        'Custom Bug Entry Forms',
        'Extensions: MozProjectReview',
        'Infrastructure',
    ]);
    BUG: foreach my $bug (@$bugs) {
        # skip unassigned bugs
        next if
            $bug->{assigned_to} eq 'nobody@mozilla.org'
            && $bug->{cf_due_date} eq '';

        # skip needinfo
        foreach my $flag (@{ $bug->{flags} }) {
            next BUG if $flag->{name} eq 'needinfo';
        }
        delete $bug->{flags};

        push @$result, $bug;
    }

    $class->_last_comments($result);
    foreach my $bug (@$result) {
        $bug->{state_date} = $bug->{last_comment_time};
    }
    $result = $class->_prepare($result, 'last_comment_time_age');
    $app->render( text => j($result), format => 'json' );
}

sub in_dev {
    my ($class, $app) = @_;
    my $result;

    my $bugs;
    BUG: foreach my $bug (@{ $class->_bugs_with_attachments() }) {
        # skip unassigned bugs
        next if $bug->{assigned_to} eq 'nobody@mozilla.org';

        # skip needinfo
        foreach my $flag (@{ $bug->{flags} }) {
            next BUG if $flag->{name} eq 'needinfo';
        }
        delete $bug->{flags};

        push @$bugs, $bug;
    }

    $class->_last_comments($bugs);
    $bugs = $class->_prepare($bugs, 'last_comment_time_age');
    foreach my $bug (@$bugs) {
        next if $bug->{last_comment_time_age} < 60 * 60 * 24 * 14;
        $bug->{state_date} = $bug->{last_comment_time};
        push @$result, $bug;
    }
    $app->render( text => j($result), format => 'json' );
}

sub stalled {
    my ($class, $app) = @_;
    my $result;

    my $bugs = $class->_bugs([]);
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
    $result = $class->_prepare($result, 'needinfo_time_age');
    $app->render( text => j($result), format => 'json' );
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

        # skip needinfo
        foreach my $flag (@{ $bug->{flags} }) {
            next unless $flag->{name} eq 'needinfo';
            $bug->{needinfo_time} = $flag->{creation_date};
            $bug->{needinfo} = $flag->{requestee};
        }
        delete $bug->{flags};

        push @$result, $bug;
    }

    $class->_last_comments($result);
    foreach my $bug (@$result) {
        $bug->{state_date} = $bug->{last_comment_time};
    }
    $result = $class->_prepare($result, 'creation_time_age');
    $app->render( text => j($result), format => 'json' );
}

sub all {
    my ($class, $app) = @_;

    my $bugs = $class->_bugs([
        'Administration',
        'Custom Bug Entry Forms',
        'Extensions: MozProjectReview',
        'Infrastructure',
    ]);
    $app->render( text => j($class->_prepare($bugs)), format => 'json' );
}

sub _bugs {
    my ($class, $components) = @_;
    my $bugs = BTeam::Bugzilla->search({
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
            groups
        )),
        product         => 'bugzilla.mozilla.org',
        component       => $components,
        bug_status      => '__open__',
    });
    foreach my $bug (@$bugs) {
        $bug->{summary} = '' if @{ $bug->{groups} // [] };
    }
    return $bugs;
}

sub _bugs_with_attachments {
    my $all_bugs = BTeam::Bugzilla->search({
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
        bug_status      => '__open__',
        f1              => 'attachments.ispatch',
        o1              => 'equals',
        v1              => '1',
    });

    # exclude bugs that only have obsolete attachments
    my $attachments = BTeam::Bugzilla->attachments(
        {
            bug_ids         => [ map { $_->{id} } @$all_bugs ],
            include_fields  => 'is_obsolete',
        }
    );
    my $bugs = [];
    foreach my $bug (@$all_bugs) {
        my $obsolete_count = 0;
        foreach my $attachment (@{ $attachments->{$bug->{id}} }) {
            $obsolete_count++ if $attachment->{is_obsolete};
        }
        next if $obsolete_count == scalar @{ $attachments->{$bug->{id}} };
        push @$bugs, $bug;
    }
    return $bugs;
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

    # fix dates
    my $now = time();
    foreach my $bug (@$bugs) {
        foreach my $field (qw(creation_time cf_due_date last_comment_time needinfo_time)) {
            next unless exists $bug->{$field} && $bug->{$field};
            $bug->{$field . '_epoch'} = BTeam::Date->new($bug->{$field})->epoch;
            $bug->{$field . '_age'} = $now - $bug->{$field . '_epoch'};
        }
    }

    # sort
    if ($sort_field) {
        return [ sort { $b->{creation_time_age} <=> $a->{creation_time_age} } @$bugs ];
    } else {
        return $bugs;
    }
}

1;
