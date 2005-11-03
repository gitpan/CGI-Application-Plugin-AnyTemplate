#!/usr/bin/perl

=pod

This script allows you to run the test suite, simulating the absense of
a particular set of Perl modules, even if they are installed on your
system.

To run the test suite multiple times in a row, each tie multiple times
(each with a different selection of absent modules), run:

    $ perl misc/prove_without_modules.pl t/*.t

To add a new set of absent modules, make a subdir under t/prereq_scenarios, and
add a dummy perl module for every module you want to skip.  This file
should be empty.  For instance if you wanted to simulate the absense of
Text::Template and Text::TagTemplate, you would do the following:

    $ mkdir t/prereq_scenarios/skip_tt+ttt
    $ mkdir t/prereq_scenarios/skip_tt+ttt/Text
    $ touch t/prereq_scenarios/skip_tt+ttt/Text/Template.pm
    $ touch t/prereq_scenarios/skip_tt+ttt/Text/TagTemplate.pm

Finally, add this directory to the @Scenarios array below.

Note that this technique only works because of how AnyTemplate and its
test suite are written.  The AnyTemplate drivers each provide a method
returning the list of modules they depend on.  Each test script gets the
list of modules and attempts to load them:

    my @required_modules = $driver_module->required_modules;

    foreach (@required_modules) {
        eval "require $_;";
        if ($@) {
            return;
        }
    }
    return 1;

If any of the modules fail to load, then the test script skips the tests
associated with that module.

=cut

my @Scenarios = qw(
    t/prereq_scenarios/skip_none
    t/prereq_scenarios/skip_ht
    t/prereq_scenarios/skip_htp
    t/prereq_scenarios/skip_hte
    t/prereq_scenarios/skip_tt
    t/prereq_scenarios/skip_petal
    t/prereq_scenarios/skip_ht+hte+htp+petal+template
    t/prereq_scenarios/skip_hte+htp+petal+tt
    t/prereq_scenarios/old_cap_forward
);

###################################################################
use strict;
use File::Find;

unless (@ARGV) {
    die "Usage: $0 [args to prove]\n";
}

my %Skip_Modules;
my $errors;
foreach my $prereq_scenarios_dir (@Scenarios) {
    if (!-d $prereq_scenarios_dir) {
        $errors = 1;
        warn "Skip lib dir does not exist: $prereq_scenarios_dir\n";
        next;
    }
    my @modules;
    find(sub {
        return unless -f;
        my $dir = "$File::Find::dir/$_";
        $dir =~ s/^\Q$prereq_scenarios_dir\E//;
        $dir =~ s/\.pm$//;
        $dir =~ s{^/}{};
        $dir =~ s{/}{::}g;
        push @modules, $dir;
    }, $prereq_scenarios_dir);
    $Skip_Modules{$prereq_scenarios_dir} = \@modules;
}
die "Terminating." if $errors;

foreach my $prereq_scenarios_dir (@Scenarios) {
    my $modules = join ', ', sort @{ $Skip_Modules{$prereq_scenarios_dir} };
    $modules ||= 'none';
    print "\n##############################################################\n";
    print "Running tests.  Old (or absent) modules in this scenario:\n";
    print "$modules\n";
    my @prove_command = ('prove', '-Ilib', "-I$prereq_scenarios_dir", @ARGV);
    system(@prove_command) && do {
        die <<EOF;
##############################################################
One or more tests failed.  The old or absent modules were:
    $modules

The command was:
    @prove_command

Terminating.
##############################################################
EOF
    };
}

