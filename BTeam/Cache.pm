package BTeam::Cache;
use strict;

use FindBin qw($RealBin);
use Mojo::Util qw(md5_sum slurp spurt);

use constant LIFETIME_MINUTES => 5;

my $_instance;
sub instance {
    my ($class) = @_;
    return $_instance //= bless({
        path => "$RealBin/cache",
    }, $class);
}

sub get {
    my ($class, $key) = @_;
    my $filename = $class->filename($key);
    return -e $filename ? slurp($filename) : undef;
}

sub put {
    my ($class, $key, $value) = @_;
    my $filename = $class->filename($key);
    spurt($value, $filename);
}

sub delete_stale {
    my ($class) = @_;
    my $prefix = $class->filename_prefix();
    my $len = length($prefix);
    chdir($class->instance->{path});
    foreach my $file (glob('*.cache')) {
        next if substr($file, 0, $len) eq $prefix;
        unlink($file);
    }
}

sub filename {
    my ($class, $key) = @_;
    return $class->instance->{path} . '/' .
        $class->filename_prefix() . md5_sum($key) . '.cache';
}

sub filename_prefix {
    my ($class) = @_;
    my $minutes = int(time() / 60);
    return ($minutes - ($minutes % LIFETIME_MINUTES)) . '-';
}

END {
    BTeam::Cache->delete_stale();
}

1;
