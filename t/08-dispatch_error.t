
use strict;
use Test::More 'no_plan';

my $Per_Template_Driver_Tests = 4;

{
    package WebApp;
    use base 'CGI::Application';
    use Test::More;
    use CGI::Application::Plugin::AnyTemplate;

    sub setup {
        my $self = shift;
        $self->header_type('none');
        $self->start_mode('dispatch_start');
        $self->run_modes([qw/
            dispatch_start
            dispatch_non_existent_runmode_sub
        /]);
        $self->template->config(
            # default_type  => $self->param('template_driver'),
            include_paths => 't/tmpl',
            HTMLTemplate => {
                die_on_bad_params => 0,
            },
            HTMLTemplateExpr => {
                die_on_bad_params  => 0,
                template_extension => '.html_expr',
            },
        );
    }

    sub dispatch_start {
        my $self = shift;

        my $driver = $self->param('template_driver');

        my $template = $self->template->load(
            'dispatch_error1',
        );

        my $output;


        eval {
            $output = $template->output;
        };

        ok($@, "Caught dispatch to non existent runmode");
        like($@, qr/dispatch_non_existent_runmode.*listed/, "Caught dispatch to non existent runmode (error message ok)");

        $template = $self->template->load(
            'dispatch_error2',
        );

        eval {
            $output = $template->output;
        };

        ok($@, "Caught dispatch to non existent runmode sub ");
        like($@, qr/dispatch_non_existent_runmode.*sub/, "Caught dispatch to non existent runmode sub (error message ok)");


        '';
    }

}


SKIP: {
    if (test_driver_prereqs('HTMLTemplate')) {
        WebApp->new(PARAMS => { template_driver => 'HTMLTemplate' })->run;
    }
    else {
        skip "HTML::Template not installed", $Per_Template_Driver_Tests;
    }
}

sub test_driver_prereqs {
    my $driver = shift;
    my $driver_module = 'CGI::Application::Plugin::AnyTemplate::Driver::' . $driver;
    eval "require $driver_module;";
    die $@ if $@;

    my @required_modules = $driver_module->required_modules;

    eval "require $_;" for @required_modules;

    if ($@) {
        return;
    }
    return 1;
}
