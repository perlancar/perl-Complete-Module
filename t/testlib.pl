use 5.010;
use strict;
use warnings;

use Complete;
use Complete::Module qw(complete_module);
use Complete::Path;
use Data::Dumper; # force use, before we empty @INC
use File::Slurp::Tiny qw(write_file);
use File::Temp qw(tempdir);
use Filesys::Cap qw(fs_is_cs);
use Test::More 0.98;
use mro; # force use, before we empty @INC
use Test::More 0.98;

sub test_complete {
    my %args = @_;
    my $actual_res = complete_module(%{$args{args}});
    is_deeply($actual_res, $args{result}) or diag explain $actual_res;
}

1;
