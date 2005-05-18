use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'CGI::Application::Plugin::AnyTemplate',
    license             => 'perl',
    dist_author         => 'Michael Graham <mag-perl@occamstoothbrush.com>',
    dist_version_from   => 'lib/CGI/Application/Plugin/AnyTemplate.pm',
    requires => {
        'Test::More'       => 0,
        'Clone'            => 0,
        'Scalar::Util'     => 0,
        'CGI::Application' => 0,   # We know that CGI::App requires HTML::Template
                                   # so we will have at least one templating system
                                   # installed
    },
    add_to_cleanup      => [ 'CGI-Application-Plugin-AnyTemplate-*' ],
    create_makefile_pl  => 'traditional',
);

$builder->create_build_script();
