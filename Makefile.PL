use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Win32::SystemInfo',
    'VERSION_FROM'	=> 'SystemInfo.pm', # finds $VERSION
    'PREREQ_PM'		=> {'Win32::API' => 0,
                                      'Win32::TieRegistry' => 0.23}, # e.g., Module::Name => 1.1
);
