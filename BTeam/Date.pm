package BTeam::Date;
use Mojo::Base 'Mojo::Date';

use Time::Local 'timegm';

has 'orig';

sub parse {
    my ($self, $date) = @_;

    if ($date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)Z$/) {
        my ($year, $month, $day, $h, $m, $s) = ($1, $2 - 1, $3, $4, $5, $6);
        $self->epoch(timegm($s, $m, $h, $day, $month, $year));
        $self->orig($date);
        return $self;
    } else {
        return $self->SUPER::parse($date);
    }
}

sub as_string {
    my ($self) = @_;
    return $self->orig ? $self->orig : $self->SUPER::as_string;
}

1;
