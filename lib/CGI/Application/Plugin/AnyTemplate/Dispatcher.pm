
package CGI::Application::Plugin::AnyTemplate::Dispatcher;

=head1 NAME

CGI::Application::Plugin::AnyTemplate::Dispatcher - Dispatch to run modes from within a template

=head1 DESCRIPTION

This is a little helper module used by the
L<CGI::Application::Plugin::AnyTemplate> to handle the actual dispatch
of embedded components to the proper run modes.

You shouldn't need to use this module directly unless you are adding
support for a new template system.

For information on component dispatch see the docs of
L<CGI::Application::Plugin::AnyTemplate>.

=cut

use strict;
use Carp;
use Scalar::Util qw(weaken);

=head1 METHODS

=over 4

=item new

Creates a new C<CGI::Application::Plugin::AnyTemplate::Dispatcher> object.

    my $dispatcher = CGI::Application::Plugin::AnyTemplate::Dispatcher->new(
        webapp              => $webapp,
        containing_template => $template,
    );

The C<webapp> parameter should be a reference to a C<CGI::Application>
object.

The C<containing_template> parameter should be a reference to the template
object in which this component is embedded.

=cut


sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my %args = @_;

    my $self = {};
    bless $self, $class;

    $self->{'webapp'}              = $args{'webapp'};
    $self->{'containing_template'} = $args{'containing_template'};

    weaken $self->{'webapp'};

    return $self;
}

=item dispatch

Runs the specified C<runmode> of the C<webapp> object.
Returns the results of this call.

Parameters passed to dispatch should be passed on to the run mode.

If the results are a scalar reference, then the return value is
dereferenced before returning.  This is the safest way of dispatching,
but it involves returning potentially very large strings from
subroutines.

=cut

sub dispatch {
    my $self          = shift;
    my $run_mode_name = shift;

    my $webapp              = $self->{'webapp'};
    my $containing_template = $self->{'containing_template'};

    my %run_modes = $webapp->run_modes;

    my $run_mode_sub = $run_modes{$run_mode_name}
        or confess("Can't dispatch to run mode [$run_mode_name] in web app [$webapp]: run mode not listed in \$self->run_modes\n");

    unless (UNIVERSAL::can($webapp, $run_mode_sub)) {
        confess("Can't dispatch to run mode [$run_mode_name] in web app [$webapp]: run mode sub ($run_mode_sub) not found\n");
    }

    my $output = $webapp->$run_mode_sub($containing_template, @_);

    if (ref $output eq 'SCALAR') {
        return $$output;
    }
    else {
        return $output;
    }
}


=item dispatch_direct

Runs the specified C<runmode> of the C<webapp> object.
Returns the results of this call.

Parameters passed to dispatch should be passed on to the run mode.

Even if the result of this call is a scalar reference, the result
is NOT dereferenced before returning it.

If you call this method instead of dispatch, you should be careful to
deal with the possibility that your results are a reference to a string
and not the string itself.

=back

=cut

sub dispatch_direct {
    my $self          = shift;
    my $run_mode_name = shift;

    my $webapp              = $self->{'webapp'};
    my $containing_template = $self->{'containing_template'};

    my %run_modes = $webapp->run_modes;

    my $run_mode_sub = $run_modes{$run_mode_name}
        or confess("Can't dispatch to run mode [$run_mode_name] in web app [$webapp]: run mode not listed in \$self->run_modes\n");

    unless (UNIVERSAL::can($webapp, $run_mode_sub)) {
        confess("Can't dispatch to run mode [$run_mode_name] in web app [$webapp]: run mode sub ($run_mode_sub) not found\n");
    }
    return $webapp->$run_mode_sub($containing_template, @_);
}

=head1 AUTHOR

Michael Graham, C<< <mag-perl@occamstoothbrush.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Michael Graham, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;



