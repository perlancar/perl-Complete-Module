package Complete::Module;

use 5.010001;
use strict;
use warnings;

use Cwd;
use List::MoreUtils qw(uniq);

our %SPEC;
require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(complete_module);

# VERSION
# DATE

our @_built_prefix;

$SPEC{complete_module} = {
    v => 1.1,
    summary => 'Complete Perl module names',
    description => <<'_',

For each directory in `@INC` (coderefs are ignored), find Perl modules and
module prefixes which have `word` as prefix. So for example, given `Te` as
`word`, will return e.g. `[Template, Template::, Term::, Test, Test::, Text::]`.
Given `Text::` will return `[Text::ASCIITable, Text::Abbrev, ...]` and so on.

This function has a bit of overlapping functionality with `Module::List`, but
this function is geared towards shell tab completion. Compared to
`Module::List`, here are some differences: 1) list modules where prefix is
incomplete; 2) interface slightly different; 3) (currently) doesn't do
recursing.

_
    args => {
        word => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
        ci => {
            summary => 'Whether to do case-insensitive search',
            schema  => 'bool*',
        },
        separator => {
            schema  => 'str*',
            default => '::',
            description => <<'_',

Instead of the default `::`, output separator as this character. Colon is
problematic e.g. in bash when doing tab completion.

_
        },
        find_pm => {
            summary => 'Whether to find .pm files',
            schema  => 'bool*',
            default => 1,
        },
        find_pod => {
            summary => 'Whether to find .pod files',
            schema  => 'bool*',
            default => 1,
        },
        find_pmc => {
            summary => 'Whether to find .pmc files',
            schema  => 'bool*',
            default => 1,
        },
        find_prefix => {
            summary => 'Whether to find module prefixes',
            schema  => 'bool*',
            default => 1,
        },
    },
    result_naked => 1,
};
sub complete_module {
    my %args = @_;

    my $word = $args{word} // '';
    my $ci   = $args{ci};
    my $sep  = $args{separator} // '::';

    my $find_pm      = $args{find_pm}     // 1;
    my $find_pmc     = $args{find_pmc}    // 1;
    my $find_pod     = $args{find_pod}    // 1;
    my $find_prefix  = $args{find_prefix} // 1;

    my $sep_re = qr!(?:::|/|\Q$sep\E)!;

    my ($prefix0, $pm);
    if ($word =~ m!(.+)$sep_re(.*)!) {
        $word = $2;
        $prefix0 = [split($sep_re, $1)];
    } else {
        $prefix0 = [];
        $pm = $word;
    }
    my $prefix = join "/", @$prefix0;
    say "D:prefix0=[".join(",",@$prefix0)."] prefix=$prefix word=$word";

    my $word_re = $ci ? qr/\A\Q$word/i : qr/\A\Q$word/;

    my @dirs;
    if ($ci && @$prefix0) {
        # for case-insensitive search: for each prefix we'll need to handle the
        # possibility of more than one matches (e.g. foo/ and Foo/ on a
        # case-sensitive filesystem)
        my $cwd = getcwd();
        my $j;
        for my $dir (@INC) {
            say "D:dir=$dir";
            next if ref($dir);
            chdir $cwd if $j++;
            chdir $dir or next;
            my $dig;
            local @_built_prefix;
            $dig = sub {
                my $i = shift;
                say "  D:i=$i, built_prefix=".join("/", @_built_prefix).", cwd=".getcwd();
                opendir my($dh), "." or return;
                for my $e (readdir $dh) {
                    next if $e eq '.' || $e eq '..';
                    next unless (-d $e) && lc($e) eq lc($prefix0->[$i]);
                    local $_built_prefix[$i] = $e;
                    if ($i == @$prefix0-1) {
                        push @dirs, [
                            $dir . (@_built_prefix ? "/" : "") .
                                join("/", @_built_prefix),
                            join($sep, @_built_prefix) .
                                (@_built_prefix ? $sep:''),
                        ];
                    } else {
                        chdir $e or return;
                        $dig->($i+1);
                        chdir "..";
                    }
                }
            };
            $dig->(0);
        }
        chdir $cwd;
    } else {
        for my $dir0 (@INC) {
            next if ref($dir0);
            my $dir = $dir0 . (length($prefix) ? "/$prefix" : "");
            next unless -d $dir;
            push @dirs, [$dir, join($sep, @$prefix0) . (@$prefix0 ? $sep:'')];
        }
    }
    use DD; dd @dirs;

    my @res;
    for my $e (@dirs) {
        my ($dir, $resprefix) = @$e;
        next if ref($dir);
        opendir my($dh), $dir or next;
        for my $e (readdir $dh) {
            #say "D:$dir <$e>";
            next if $e =~ /\A\.\.?/;
            my $is_dir = (-d "$dir/$e"); # stat once
            #say "  D:<$e> is dir" if $is_dir;
            if ($find_prefix && $is_dir) {
                #say "  D:<$e> $word_re";
                push @res, $resprefix . $e . $sep if $e =~ $word_re;
            }
            my $f;
            if ($find_pm && $e =~ qr/(.+)\.pm\z/) {
                $f = $1;
                push @res, $resprefix . $f if $f =~ $word_re;
            }
            if ($find_pmc && $e =~ qr/(.+)\.pmc\z/) {
                $f = $1;
                push @res, $resprefix . $f if $f =~ $word_re;
            }
            if ($find_pod && $e =~ qr/(.+)\.pod\z/) {
                $f = $1;
                push @res, $resprefix . $f if $f =~ $word_re;
            }
        }

    }

    [sort(uniq(@res))];
}

1;
#ABSTRACT: Complete Perl module names

=head1 SYNOPSIS

 use Complete::Module qw(complete_module);
 my $res = complete_module(word => 'Te');
 # -> ['Template', 'Template::', 'Test', 'Test::', 'Text::']

=cut
