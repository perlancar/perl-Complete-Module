package Complete::Module;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Complete;
use List::MoreUtils qw(uniq);

our %SPEC;
require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(complete_module);

our $OPT_SHORTCUTS;
if ($ENV{COMPLETE_MODULE_OPT_SHORTCUTS}) {
    $OPT_SHORTCUTS = { split /=|;/, $ENV{COMPLETE_MODULE_OPT_SHORTCUTS} };
} else {
    $OPT_SHORTCUTS = {
        dzb => 'Dist/Zilla/PluginBundle/',
        dzp => 'Dist/Zilla/Plugin/',
        pwb => 'Pod/Weaver/PluginBundle/',
        pwp => 'Pod/Weaver/Plugin/',
        pws => 'Pod/Weaver/Section/',
    };
}

$SPEC{complete_module} = {
    v => 1.1,
    summary => 'Complete with installed Perl module names',
    description => <<'_',

For each directory in `@INC` (coderefs are ignored), find Perl modules and
module prefixes which have `word` as prefix. So for example, given `Te` as
`word`, will return e.g. `[Template, Template::, Term::, Test, Test::, Text::]`.
Given `Text::` will return `[Text::ASCIITable, Text::Abbrev, ...]` and so on.

This function has a bit of overlapping functionality with `Module::List`, but
this function is geared towards shell tab completion. Compared to
`Module::List`, here are some differences: 1) list modules where prefix is
incomplete; 2) interface slightly different; 3) (currently) doesn't do
recursing; 4) contains conveniences for completion, e.g. map casing, expand
intermediate paths (see `Complete` for more details on those features),
autoselection of path separator character, some shortcuts, and so on.

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
        map_case => {
            schema => 'bool',
        },
        exp_im_path => {
            schema => 'bool',
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
        ns_prefix => {
            summary => 'Namespace prefix',
            schema  => 'str*',
            description => <<'_',

This is useful if you want to complete module under a specific namespace
(instead of the root). For example, if you set `ns_prefix` to
`Dist::Zilla::Plugin` (or `Dist::Zilla::Plugin::`) and word is `F`, you can get
`['FakeRelease', 'FileFinder::', 'FinderCode']` (those are modules under the
`Dist::Zilla::Plugin::` namespace).

_
        },
    },
    result_naked => 1,
};
sub complete_module {
    require Complete::Path;

    my %args = @_;

    my $word = $args{word} // '';
    my $ci          = $args{ci} // $Complete::OPT_CI;
    my $map_case    = $args{map_case} // $Complete::OPT_MAP_CASE;
    my $exp_im_path = $args{exp_im_path} // $Complete::OPT_EXP_IM_PATH;
    my $ns_prefix = $args{ns_prefix} // '';
    $ns_prefix =~ s/(::)+\z//;

    # find shortcuts
    {
        my $tmp = lc $word;
        if ($OPT_SHORTCUTS->{$tmp}) {
            $word = $OPT_SHORTCUTS->{$tmp};
        }
    }

    # convenience: allow Foo/Bar.{pm,pod,pmc}
    $word =~ s/\.(pm|pmc|pod)\z//;

    # convenience (and compromise): if word doesn't contain :: we use the
    # "safer" separator /, but if already contains '::' we use '::'. (Can also
    # use '.' if user uses that.) Using "::" in bash means user needs to use
    # quote (' or ") to make completion behave as expected since : is by default
    # a word break character in bash/readline.
    my $sep = $word =~ /::/ ? '::' :
        $word =~ /\./ ? '.' : '/';
    $word =~ s!(::|/|\.)!::!g;

    my $find_pm      = $args{find_pm}     // 1;
    my $find_pmc     = $args{find_pmc}    // 1;
    my $find_pod     = $args{find_pod}    // 1;
    my $find_prefix  = $args{find_prefix} // 1;

    my $res = Complete::Path::complete_path(
        word => $word,
        ci => $ci, map_case => $map_case, exp_im_path => $exp_im_path,
        starting_path => $ns_prefix,
        list_func => sub {
            my ($path, $intdir, $isint) = @_;
            (my $fspath = $path) =~ s!::!/!g;
            my @res;
            for my $inc (@INC) {
                next if ref($inc);
                my $dir = $inc . (length($fspath) ? "/$fspath" : "");
                opendir my($dh), $dir or next;
                for (readdir $dh) {
                    next if $_ eq '.' || $_ eq '..';
                    next unless /\A\w+(\.\w+)?\z/;
                    my $is_dir = (-d "$dir/$_");
                    next if $isint && !$is_dir;
                    push @res, "$_\::" if $is_dir && ($isint || $find_prefix);
                    push @res, $1 if /(.+)\.pm\z/  && $find_pm;
                    push @res, $1 if /(.+)\.pmc\z/ && $find_pmc;
                    push @res, $1 if /(.+)\.pod\z/ && $find_pod;
                }
            }
            [sort(uniq(@res))];
        },
        path_sep => '::',
        is_dir_func => sub { }, # not needed, we already suffix "dirs" with ::
    );

    for (@$res) { s/::/$sep/g }

    $res;
}

1;
#ABSTRACT:

=head1 SYNOPSIS

 use Complete::Module qw(complete_module);
 my $res = complete_module(word => 'Text::A');
 # -> ['Text::ANSI', 'Text::ANSITable', 'Text::ANSITable::', 'Text::Abbrev']


=head1 SETTINGS

=head2 C<$Complete::Module::OPT_SHORTCUTS> => hash

Some shortcut prefixes. The default is:

# CODE: $Complete::Module::Shortcuts

If user types one of the keys, it will be replaced with the matching value from
this hash.


=head1 ENVIRONMENT

=head2 C<COMPLETE_MODULE_OPT_SHORTCUTS> => str

Can be used to set the default for C<$Complete::Module::Shortcuts>. It should be
in the form of:

 shortcut1=Value1;shortcut2=Value2;...

For example:

 dzp=Dist/Zilla/Plugin/;pwp=Pod/Weaver/Plugin/

=cut
