
package CGI::Application::Plugin::AnyTemplate;

=head1 NAME

CGI::Application::Plugin::AnyTemplate - Use any templating system from within CGI::Application using a unified interface

=head1 VERSION

Version 0.06

=cut

our $VERSION = '0.06';

=head1 SYNOPSIS

In your CGI::Application-based webapp:

    use base 'CGI::Application';
    use CGI::Application::Plugin::AnyTemplate;

    sub cgiapp_init {
        my $self = shift;

        # Set template options
        $self->template->config(
            default_type => 'TemplateToolkit',
        );
    }


Later on, in a runmode:

    sub my_runmode {
        my $self = shift;

        my %template_params = (
            name     => 'Winston Churchill',
            age      => 7,
        );

        $self->template->fill('some_template', \%template_params);
    }

=head1 DESCRIPTION

=head2 Template-Independence

C<CGI::Application::Plugin::AnyTemplate> allows you to use any
supported Perl templating system using a single consistent interface.

Currently supported templating systems include L<HTML::Template>,
L<HTML::Template::Expr>, L<Template::Toolkit|Template> and L<Petal>.

You can access any of these templating systems using the same interface.
In this way, you can use the same code and switch templating systems on
the fly.

This approach has many uses.  For instance, it can be useful in
migrating your application from one templating system to another.

=head2 Embedded Components

In addition to template abstraction, C<AnyTemplate> also provides a
I<embedded component mechanism>.  For instance, you might include a
I<header> component at the top of every page and a I<footer> component
at the bottom of every page.

These components are actually full L<CGI::Application> run modes, and
can do anything normal run mode can do, including processing form
parameters and filling in their own templates.  See
below under L<"EMBEDDED COMPONENTS"> for details.

=head2 Multiple Named Template Configurations

You can set up multiple named template configurations and select between
them at run time.

    sub cgiapp_init {
        my $self = shift;

        # Can't use Template::Toolkit any more -
        # The boss wants everything has to be XML,
        # so we switch to Petal

        # Set old-style template options (legacy scripts)
        $self->template('oldstyle')->config(
            default_type => 'TemplateToolkit',
            TemplateToolkit => {
                POST_CHOMP => 1,
            }
        );
        # Set new-style template options as default
        $self->template->config(
            default_type => 'Petal',
            auto_add_template_extension => 0,
        );
    }

    sub old_style_runmode {
        my $self = shift;

        # ...

        # use TemplateToolkit to fill template edit_user.tmpl
        $self->template('oldstyle')->fill('edit_user', \%params);

    }

    sub new_style_runmode {
        my $self = shift;

        # ...

        # use Petal to fill template edit_user.xhml
        $self->template->fill('edit_user.xhtml', \%params);

    }

=head2 Flexible Syntax

The syntax is pretty flexible.  Pick a style that's most comfortable for
you.

=head3 CGI::Application::Plugin::TT style syntax

    $self->template->process('edit_user', \%params);

or (with slightly less typing):

    $self->template->fill('edit_user', \%params);

=head3 CGI::Application load_tmpl style syntax

    my $template = $self->template->load('edit_user');
    $template->param('foo' => 'bar');
    $template->output;

=head3 Verbose syntax (for complete control)

    my $template = $self->template('named_config')->load(
        file             => 'edit_user'
        type             => 'TemplateToolkit'
        add_include_path => '.',
    );

    $template->param('foo' => 'bar');
    $template->output;

See also below under L<"CHANGING THE NAME OF THE 'template' METHOD">.

=cut

use strict;
use base 'Exporter';
use CGI::Application;
use Carp;
use Scalar::Util qw(weaken);

use Clone;

our @ISA    = 'Exporter';
our @EXPORT = qw(template);

our $CAPAT_Namespace = '__ANY_TEMPLATE';

sub _new {
    my $proto     = shift;
    my $class     = ref $proto || $proto;
    my $webapp    = shift;
    my $conf_name = shift;

    my $self = {
        'conf_name'      => $conf_name,
        'base_config'    => {},
        'current_config' => {},
        'webapp'         => $webapp,
    };

    bless $self, $class;

    weaken $self->{'webapp'};

    return $self;
}

sub _default_type      { 'HTMLTemplate' }
sub _default_extension { '.html'        }

=head1 METHODS

=head2 config

Initialize the C<AnyTemplate> system and provide the default
configuration.

    $self->template->config(
        default_type => 'HTMLTemplate',
    );

You can keep multiple configurations handy at the same time by passing a
value to C<template>:

    $self->template('oldstyle')->config(
        default_type => 'HTML::Template',
    );
    $self->template('newstyle')->config(
        default_type => 'HTML::Template::Expr',
    );

Then in a runmode you can mix and match configurations:

    $self->template('oldstyle')->load  # loads an HTML::Template driver object
    $self->template('newstyle')->load  # loads an HTML::Template::Expr driver object


The configuration passed to C<config> is divided into three areas:
I<plugin configuration>, I<driver configuration>, and I<native
configuration>:

    Config Type       What it Configures
    -----------       ------------------
    Plugin Config     AnyTemplate itself
    Driver Config     AnyTemplate Driver (e.g. HTMLTemplate)
    Native Config     Actual template module (e.g. HTML::Template)

These are described in more detail below.

=head3 Plugin Configuration

These configuration params are specific to the C<CGI::Application::Plugin::AnyTemplate> itself.
They are included at the top level of the configuration hash passed to C<config>.  For instance:

    $self->template->config(
        default_type                => 'HTMLTemplate',
        auto_add_template_extension => 0,
    );

The I<plugin configuration> parameters and their defaults are as follows:

=over 4

=item default_type

=item type

The default type of template for this named configuration.  Should be the name of a driver
in the C<CGI::Application::Plugin::AnyTemplate::Driver> namespace:

    Type                Driver
    ----                ------
    HTMLTemplate        CGI::Application::Plugin::AnyTemplate::Driver::HTMLTemplate
    HTMLTemplateExpr    CGI::Application::Plugin::AnyTemplate::Driver::HTMLTemplateExpr
    TemplateToolkit     CGI::Application::Plugin::AnyTemplate::Driver::TemplateToolkit
    Petal               CGI::Application::Plugin::AnyTemplate::Driver::Petal

=item include_paths

Include Paths (sometimes called search paths) are used by the various
template backends to find filenames that aren't fully qualified by an
absolute path.  Each directory is searched in turn until the template
file is found.

Can be a single string or a reference to a list.

=item auto_add_template_extension

Add a template-system specific extension to template filenames.

So, if this feature is enabled and you provide the filename C<myfile>,
then the actual filename will depend on the current template driver:

    Driver                 Template
    ------                 --------
    HTMLTemplate           myfile.html
    HTMLTemplateExpr       myfile.html
    TemplateToolkit        myfile.tmpl
    Petal                  myfile.xhtml

The per-type extension is controlled by the driver config for each
C<AnyTemplate> driver (see below under L<"Driver and Native Configuration"> for how
to set this).

The C<auto_add_template_extension> feature is on by default.  To disable
it, pass a value of zero:

    $self->template->config(
        auto_add_template_extension => 0,
    );

=item component_handler_class

Normally, component embedding is handled by
L<CGI::Application::Plugin::AnyTemplate::ComponentHandler>.  If you want to
use a different class for this purpose, specify the class name as the
value of this paramter.

It still has to provide the same interface as
L<CGI::Application::Plugin::AnyTemplate::ComponentHandler>.  See the source
code of that module for details.

=back

=head3 Driver and Native Configuration

You can configure all the drivers at once with a single call to
C<config>, by including subsections for each driver type:

    $self->template->config(
        default_type => 'HTMLTemplate',
        HTMLTemplate => {
            cache              => 1,
            global_vars        => 1,
            die_on_bad_params  => 0,
            template_extension => '.html',
        },
        HTMLTemplateExpr => {
            cache              => 1,
            global_vars        => 1,
            die_on_bad_params  => 0,
            template_extension => '.html',
        },
        TemplateToolkit => {
            POST_CHOMP         => 1,
            template_extension => '.tmpl',
        },
        Petal => {
            error_on_undef     => 0,
            template_extension => '.xhtml',
        },
    );


Each driver knows how to separate its own configuration from the
configuration belonging to the underlying template system.

For instance in the example above, the C<HTMLTemplate> driver knows that
C<template_extension> is a driver config parameter, but
C<cache_global_vars> and C<die_on_bad_params> are all HTML::Template
configuration parameters.

Similarly, The C<TemplateToolkit> driver knows that template_extension
is a driver config parameter, but C<POST_CHOMP> is a
C<Template::Toolkit> configuration parameter.

For details on driver configuration, see the docs for the individual
drivers:

=over 4

=item L<CGI::Application::Plugin::AnyTemplate::Driver::HTMLTemplate>

=item L<CGI::Application::Plugin::AnyTemplate::Driver::HTMLTemplateExpr>

=item L<CGI::Application::Plugin::AnyTemplate::Driver::TemplateToolkit>

=item L<CGI::Application::Plugin::AnyTemplate::Driver::Petal>

=back

=head3 Copying Query data into Templates

By default, all data in C<< $self->query >> are copied into the template
object before the template is processed.

For the C<HTMLTemplate> and C<HTMLTemplateExpr> drivers this is done
with the C<associate> feature of L<HTML::Template> and
L<HTML::Template::Expr>, respectively:

    my $template = HTML::Template->new(
        associate => $self->query,
    );

For the other systems, this feature is emulated, by copying the query
params into the template params before the template is processed.

To disable this feature, pass a false value to C<associate_query> or
C<emulate_associate_query> (depending on the template system):

    $self->template->config(
        default_type => 'HTMLTemplate',
        HTMLTemplate => {
            associate_query => 0,
        },
        HTMLTemplateExpr => {
            associate_query => 0,
        },
        TemplateToolkit => {
            emulate_associate_query => 0,
        },
        Petal => {
            emulate_associate_query => 0,
        },
    );



=cut

sub config {
    my $self = shift;

    my $config = ref $_[0] eq 'HASH' ? $_[0] : { @_ };

    $config->{'callers_package'} = scalar caller;

    # reset storage and add configuration
    $self->_clear_configuration($self->{'base_config'});
    $self->_add_configuration($self->{'base_config'}, $config);
}


# The template method returns or creates an CAP::AnyTemplate object
# either the default one (if no name provided, or the named one)
sub template {
    my ($self, $config_name) = @_;

    # TODO: make CAPAT subclassable somehow?

    if (defined $config_name) {
        # Named config
        if (not exists $self->{$CAPAT_Namespace}->{'__NAMED_CONFIGS'}->{$config_name}) {
            $self->{$CAPAT_Namespace}->{'__NAMED_CONFIGS'}->{$config_name} = __PACKAGE__->_new($self, $config_name);
        }
        return $self->{$CAPAT_Namespace}->{'__NAMED_CONFIGS'}->{$config_name};
    }
    else {
        # Default config
        if (not exists $self->{$CAPAT_Namespace}->{'__DEFAULT_CONFIG'}) {
            $self->{$CAPAT_Namespace}->{'__DEFAULT_CONFIG'} = __PACKAGE__->_new($self);
        }
        return $self->{$CAPAT_Namespace}->{'__DEFAULT_CONFIG'};
    }
}

=head2 load

Create a new template object and configure it.

This can be as simple (and magical) as:

    my $template = $self->template->load;

When you call C<load> with no parameters, it uses the default template
type, the default template configuration, and it determines the name of
the template based on the name of the current run mode.

If you call C<load> with one paramter, it is taken to be either the
filename or a reference to a string containing the template text:

    my $template = $self->template->load('somefile');
    my $template = $self->template->load(\$some_text);

If the parameter C<auto_add_template_exension> is true, then the
appropriate extension will be added for this template type.

If you call C<load> with more than one parameter, then
you can specify filename and configuration paramters directly:

    my $template = $self->template->load(
        file                        => 'some_file.tmpl',
        type                        => 'HTMLTemplate',
        auto_add_template_extension => 0,
        add_inlcude_path            => '..',
        HTMLTemplate => {
            die_on_bad_params => 1,
        },
    );

To initialize the template from a string rather than a file, use:

    my $template = $self->template->load(
        string =>  \$some_text,
    );

The configuration parameters you pass to C<load> are merged with the
configuration that was passed to L<"config">.

You can include any of the configuration parameters that you can pass to
config, plus the following extra parameters:

=over 4

=item file

If you are loading the template from a file, then the C<file> parameter
contains the template's filename.

=item string

If you are loading the template from a string, then the C<string> parameter
contains the text of the template.  It can be either a scalar or a
reference to a scalar.  Both of the following will work:

    # passing a string
    my $template = $self->template->load(
        string => $some_text,
    );

    # passing a reference to a string
    my $template = $self->template->load(
        string => \$some_text,
    );

=item add_include_paths

Additional include paths.  These will be merged with C<include_paths>
before being passed to the template driver.

=back

The C<load> method returns a template driver object.  See below under
C<DRIVER METHODS>, for how to use this object.

=cut

sub load {
    my $self = shift;

    my $config;
    if (@_) {
        if (@_ == 1) {
            if (ref $_[0] eq 'HASH') {
                # args: single hashref
                $config = $_[0];
            }
            else {
                # args: single value (=filename or string_ref)
                if (ref $_[0] eq 'SCALAR') {
                    $config = {
                        'string' => $_[0],
                    };
                }
                else {
                    $config = {
                        'file' => $_[0],
                    };
                }
            }
        }
        else {
            # args: hash
            $config = { @_ };
        }
    }

    # Where we get our subroutine name from.  Usually from the subroutine
    # immediately above us, but occasionally from further up
    # (such as when we are called from fill or process)
    my $call_level = delete $config->{'call_level'} || 1;

    # set current configuration from base


    if (keys %$config) {
        $self->{'current_config'} = Clone::clone($self->{'base_config'});
        $self->_add_configuration($self->{'current_config'}, $config);
    }
    else {
        $self->{'current_config'} = $self->{'base_config'};
    }

    my $plugin_config = $self->{'current_config'}{'plugin_config'};

    # manage include paths

    my $include_paths = $self->_merged_include_paths($plugin_config);

    # determine template type

    my $type = $plugin_config->{'type'}
            || $plugin_config->{'default_type'}
            || $self->_default_type;


    # require driver
    my $driver_class = $self->_require_driver($type);

    # Generate driver config and native config
    my %driver_config = $driver_class->default_driver_config;

    # Copy all params with keys listed in the driver_config_keys
    foreach my $param ($driver_class->driver_config_keys) {
        if (exists $self->{'current_config'}{'driver_config'}{$type}{$param}) {
            $driver_config{$param} = $self->{'current_config'}{'driver_config'}{$type}{$param};
        }
    }

    # Copy whatever is left over into native config
    my $native_config = $self->{'current_config'}{'native_config'}{$type};

    foreach my $param (keys %{ $self->{'current_config'}{'driver_config'}{$type} }) {
        # skip values copied into %driver_config
        if (not exists $driver_config{$param}) {
            $native_config->{$param} = $self->{'current_config'}{'driver_config'}{$type}{$param};
        }
    }

    my $string_ref;
    if (exists $plugin_config->{'string'}) {
        $string_ref = $plugin_config->{'string'} || '';
        $string_ref = \$string_ref unless ref $string_ref;
    }

    # if no string, then guess template filename
    my $filename;
    unless ($string_ref) {
        $filename = $self->_guess_template_filename($plugin_config, \%driver_config, $type, (caller($call_level))[3]);
    }

    # create and initialize driver

    my $driver = $driver_class->_new(
         'driver_config'           => \%driver_config,
         'native_config'           => $native_config,
         'include_paths'           => $include_paths,
         'filename'                => $filename,
         'string_ref'              => $string_ref,
         'callers_package'         => $plugin_config->{'callers_package'},
         'webapp'                  => $self->{'webapp'},
         'component_handler_class' => $plugin_config->{'component_handler_class'},
    );

    return $driver;

}

# These are the param keys of the plugin_config (see below)
sub _plugin_config_keys {
    qw/
        callers_package
        auto_add_template_extension
        default_type
        type
        include_paths
        add_include_paths
        file
        string
        component_handler_class
    /;
}

# This is the default plugin_config (see below)
sub _default_plugin_config {
    (
        auto_add_template_extension => 1
    );
}

# Internally, the configuration is split into three separate sections:
#
#     General
#     -------
#     'plugin'  - configuration for CAP::AnyTemplate itself
#               - This includes keys specified in _plugin_config_keys()
#
#     Per-driver
#     ----------
#     'driver'  - configuration for the driver module
#     'native'  - configuration for the underlying template system module
#
# For instance:
#
#    $self->template->config(
#        default_type   => 'TemplateToolkit',    # plugin config
#        auto_extension => 1,                    # plugin config
#        'TemplateToolkit' => {
#            template_extension => '.html',      # driver config
#            POST_CHOMP         => 1,            # native config
#        }
#    );
#

sub _clear_configuration {
    my ($self, $storage) = @_;

    $storage->{'plugin_config'} = { $self->_default_plugin_config };
    $storage->{'driver_config'} = {};
    $storage->{'native_config'} = {};
}

sub _add_configuration {
    my ($self, $storage, $config) = @_;

    $storage->{'plugin_config'} ||= { $self->_default_plugin_config };
    $storage->{'driver_config'} ||= {};
    $storage->{'native_config'} ||= {};

    foreach my $key ($self->_plugin_config_keys) {
        $storage->{'plugin_config'}{$key} = delete $config->{$key} if exists $config->{$key};
    }

    # After we've removed the config keys for the 'plugin'
    # configuration, the only keys that should remain
    # are the names of drivers

    foreach my $driver (keys %$config) {

        my $module = $self->_require_driver($driver);

        # Start with a blank config
        $storage->{'driver_config'}{$driver} ||= {};

        # add the module's default config
        my %default_config = $module->default_driver_config;

        foreach my $key (keys %default_config) {
            $storage->{'driver_config'}{$key} ||= $default_config{$key};
        }

        # add the config provided by the user
        # values of known driver config keys get put into driver_config
        foreach my $key ($module->driver_config_keys) {
            if (exists $config->{$driver}{$key}) {
                $storage->{'driver_config'}{$driver}{$key} = delete $config->{$driver}{$key};
            }
        }

        # ... and the remaining keys get put into native_config
        foreach my $key (keys %{ $config->{$driver} }) {
            $storage->{'native_config'}{$driver}{$key} = $config->{$driver}{$key};
        }
    }
}

sub _merged_include_paths {
    my ($self, $config) = @_;

    if ($config->{'include_paths'} and ref $config->{'include_paths'} ne 'ARRAY') {
        $config->{'include_paths'} = [ $config->{'include_paths'} ];
    }

    my @include_paths     = @{ $config->{'include_paths'} || [] };

    $config->{'add_include_paths'} ||= [];
    $config->{'add_include_paths'} = [$config->{'add_include_paths'}] unless ref $config->{'add_include_paths'} eq 'ARRAY';

    unshift @include_paths, @{$config->{'add_include_paths'}};

    # remove duplicates
    my %seen_include_path;
    my @unique_include_paths;
    foreach my $path (@include_paths) {
        next if $seen_include_path{$path};
        $seen_include_path{$path} = 1;
        push @unique_include_paths, $path;
    }

    return @unique_include_paths if wantarray;
    return \@unique_include_paths;
}

# Finds a template driver beneath the namespace of the current package
# followed by '::Driver::'.  Requires this module and returns its package
# name
#
#
# For instance:
#     $module = _require_driver('HTMLTemplate');
#     print $module;  # 'CGI::Application::Plugin::AnyTemplate::Driver::HTMLTemplate'

sub _require_driver {
    my ($self, $driver) = @_;

    # only allow word characters and colons
    if ($driver =~ /[^\w:]/) {
        croak "CAP::AnyTemplate: Illegal template driver name: $driver\n";
    }

    my $module = (ref $self) . '::Driver::' . $driver;

    eval "require $module";

    if ($@) {
        croak "CAP::AnyTemplate: template driver $module could not be found: $@";
    }
    return $module;
}

sub _guess_template_filename {
    my ($self, $plugin_config, $driver_config, $type, $calling_sub) = @_;

    my $filename;
    if (exists $plugin_config->{'file'}) {
        $filename = $plugin_config->{'file'};
    }
    else {
        # split off subroutine name from package name
        $filename = substr(
            $calling_sub, rindex($calling_sub, '::') + 2
        );
    }

    if ($plugin_config->{'auto_add_template_extension'}) {

        # add extension
        my $extension = $driver_config->{'template_extension'}
                     || $self->_default_extension;

        $filename = $filename . $extension;
    }

    return $filename;
}

=head2 fill

Fill is a convenience method which in a single step creates the
template, fills it with the template paramters and returns its output.

You can call it with or without a filename.

The code:

    $self->template->fill('filename', \%params);

is equivalent to:

    my $template = $self->template->load('filename');
    $template->output(\%params);

And the code:

    $self->template->fill(\%params);

is equivalent to:

    my $template = $self->template->load;
    $template->output(\%params);


=cut

sub fill {
    my $self = shift;

    my ($file, $params, $template);

    if (@_ == 2) {
        ($file, $params) = @_;
        $template = $self->load($file);
    }
    else {
        ($params) = @_;
        $template = $self->load(
            call_level => 2,
        );
    }

    $params ||= {};

    $template->output($params);
}

=head2 process

C<"process"> is an alias for L<"fill">.

=cut

sub process {
    goto &fill;
}

=head1 DRIVER METHODS

These are the most commonly used methods of the C<AnyTemplate> driver
object.  The driver is what you get back from calling C<< $self->template->load >>.

=over 4

=item param

The C<param> method gets and sets values within the template.

    my $template = $self->template->load;

    my @param_names = $template->param();

    my $value = $template->param('name');

    $template->param('name' => 'value');
    $template->param(
        'name1' => 'value1',
        'name2' => 'value2'
    );

It is designed to behave similarly to the C<param> method in other modules like
L<CGI> and L<HTML::Template>.

=item get_param_hash

Returns the template variables as a hash of names and values.

    my %params     = $self->template->get_param_hash;

In a scalar context, returns a reference to the hash used
internally to contain the values:

    my $params_ref = $self->template->get_param_hash;

    $params_ref->{'foo'} = 'bar';  # directly change parameter 'foo'

=item output

Returns the template with all the values filled in.

    return $template->output;

You can also supply names and values to the template at this stage:

    return $template->output('name' => 'value', 'name2' => 'value2');


=back


=head1 PRE- AND POST- PROCESS

Before the template output is generated, your application's
C<< $self->template_pre_process >> method is called.
This method is passed a reference to the C<$template> object.

It can modify the parameters passed into the template by using the C<param> method:

    sub template_pre_process {
        my ($self, $template) = @_;

        # Change the internal template parameters by reference
        my $params = $template->get_param_hash;

        foreach my $key (keys %$params) {
            $params{$key} = to_piglatin($params{$key});
        }

        # Can also set values using the param method
        $template->param('foo', 'bar');

    }


After the template output is generated, your application's
C<< $self->template_post_process >> method is called.
This method is passed a reference to the template object and a reference
to the output generated by the template.  You can modify this output:

    sub template_post_process {
        my ($self, $template, $output_ref) = @_;

        $$output_ref =~ s/foo/bar/;
    }


When you call the C<output> method, any components embedded in the
template are run.  See L<"EMBEDDED COMPONENTS">, below.


=head1 EMBEDDED COMPONENTS

=head2 Introduction

C<CGI::Application::Plugin::AnyTemplate> allows you to include application
components within your templates.

For instance, you might include a I<header> component a the top of every
page and a I<footer> component at the bottom of every page.

These componenets are actually first-class run modes.  When the template
engine finds a special tag marking an embedded component, it passes
control to the run mode of that name.  That run mode can then do
whatever a normal run mode could do.  But typically it will load its own
template and return the template's output.

This output returned from the embedded run mode is inserted into the
containing template.

The syntax for embed components is specific to each type of template
driver.

=head2 Syntax

L<HTML::Template> syntax:

    <TMPL_VAR NAME="CGIAPP_embed('some_run_mode')">

L<HTML::Template::Expr> syntax:

    <TMPL_VAR EXPR="CGIAPP_embed('some_run_mode')">

L<Template::Toolkit|Template> syntax:

    [% CGIAPP.embed("some_run_mode") %]

L<Petal> syntax:

    <span tal:replace="structure CGIAPP/embed 'some_run_mode'">
        this text gets replaced by the output of some_run_mode
    </span>

=head2 Getting Template Variables from the Containing Template

The component run mode is passed a reference to the template object that
contained the component.  The component run mode can use this object
to access the params that were passed to the containing template.

For instance:

    sub header {
        my ($self, $containing_template, @other_params) = @_;

        my %tmplvars = (
            'title' => 'My glorious home page',
        );

        my $template = $self->template->load;

        $template->param(%tmplvars, $containing_template->get_param_hash);
        return $template->output;
    }

In this example, the template values of the enclosing template would
override any values set by the embedded component.

=head2 Passing Parameters

The template can pass parameters to the target run mode.  These are
passed in after the reference to the containing template object.

Parameters can either be literal strings, specified within the template
text, or they can be keys that will be looked up in the template's
params.

Literal strings are enclosed in double or single quotes.  Param keys are
barewords.

L<HTML::Template> syntax:

    <TMPL_VAR NAME="CGIAPP_embed('some_run_mode', param1, 'literal string2')">

I<Note that HTML::Template doesn't support this type of callback natively>
I<and that this behaviour is emulated by the HTMLTemplate driver>
I<see the docs to> L<CGI::Application::Plugin::AnyTemplate::Driver::HTMLTemplate>
I<for limitations to the emulation>.

L<HTML::Template::Expr> syntax:

    <TMPL_VAR EXPR="CGIAPP_embed('some_run_mode', param1, 'literal string2')">

L<Template::Toolkit|Template> syntax:

    [% CGIAPP.embed("some_run_mode", param1, 'literal string2' ) %]

L<Petal> syntax:

    <span tal:replace="structure CGIAPP/embed 'some_run_mode' param1 'literal string2' ">
        this text gets replaced by the output of some_run_mode
    </span>


=cut


=head1 CHANGING THE NAME OF THE 'template' METHOD

If you want to access the features of this module using a method other
than C<template>, you can do so via Anno Siegel's L<Exporter::Renaming>
module (available on CPAN).

For instance, to use syntax similar to L<CGI::Application::Plugin::TT>:

    use Exporter::Renaming;
    use CGI::Application::Plugin::AnyTemplate Renaming => [ template => tt];

    sub cgiapp_init {
        my $self = shift;

        my %params = ( ... );

        # Set config file and other options
        $self->tt->config(
            default_type => 'TemplateToolkit',
        );

    }

    sub my_runmode {
        my $self = shift;
        $self->tt->process('file', \%params);
    }

And to use syntax similar to L<CGI::Application>'s C<load_tmpl> mechanism:

    use Exporter::Renaming;
    use CGI::Application::Plugin::AnyTemplate Renaming => [ template => tmpl];

    sub cgiapp_init {
        my $self = shift;

        # Set config file and other options
        $self->tmpl->config(
            default_type => 'HTMLTemplate',
        );

    }

    sub my_runmode {
        my $self = shift;

        my %params = ( ... );

        my $template = $self->tmpl->load('file');
        $template->param(\%params);
        $template->output;
    }

=head1 AUTHOR

Michael Graham, C<< <mag-perl@occamstoothbrush.com> >>

=head1 ACKNOWLEDGEMENTS

I originally wrote this to be a subsystem in Richard Dice's
L<CGI::Application>-based framework, before I moved it into its own module.

Various ideas taken from L<CGI::Application> (Jesse Erlbaum),
L<CGI::Application::Plugin::TT> (Cees Hek) and C<Text::Boilerplate>
(Stephen Nelson).

C<Template::Toolkit> singleton support code stolen from L<CGI::Application::Plugin::TT>.


=head1 BUGS

Please report any bugs or feature requests to
C<bug-cgi-application-plugin-anytemplate@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically
be notified of progress on your bug as I make changes.

=head1 SEE ALSO

    CGI::Application::Plugin::AnyTemplate::Base
    CGI::Application::Plugin::AnyTemplate::ComponentHandler
    CGI::Application::Plugin::AnyTemplate::Driver::HTMLTemplate
    CGI::Application::Plugin::AnyTemplate::Driver::HTMLTemplateExpr
    CGI::Application::Plugin::AnyTemplate::Driver::TemplateToolkit
    CGI::Application::Plugin::AnyTemplate::Driver::Petal

    CGI::Application

    Template::Toolkit
    HTML::Template
    Petal

    Exporter::Renaming

    CGI::Application::Plugin::TT


=head1 COPYRIGHT & LICENSE

Copyright 2005 Michael Graham, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;