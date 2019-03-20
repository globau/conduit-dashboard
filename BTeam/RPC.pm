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
    my $url = 'https://bugzilla.mozilla.org/buglist.cgi?query_format=advanced&product=Conduit&bug_status=__open__';
    my $result = {
        conduit => { '--' => 0, P1 => 0, P2 => 0, P3 => 0, P4 => 0, P5 => 0 },
        upstream => { '--' => 0, P1 => 0, P2 => 0, P3 => 0, P4 => 0, P5 => 0 },
        conduit_url => "$url&keywords=conduit-upstream&keywords_type=nowords",
        upstream_url => "$url&keywords=conduit-upstream",
    };

    my $bugs = $class->_bugs();
    foreach my $bug (@$bugs) {
        my $is_upstream = any { $_ eq 'conduit-upstream' } @{ $bug->{keywords } };
        my $product = $is_upstream ? 'upstream' : 'conduit';
        $result->{$product}->{$bug->{priority}}++;
    }

    $app->render( json => $result );
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
            url
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
