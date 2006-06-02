use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'renrot',
    'AUTHOR'		=> 'Zeus Panchenko <zeus@dn.farlep.net>',
    'VERSION_FROM'	=> 'renrot', # finds $VERSION
    'PREREQ_PM'		=> { 'Image::ExifTool' => 5.72, 'Getopt::Long' => 2.34 },
    'PREREQ_FATAL'	=> 'true',
    'EXE_FILES'		=> [ 'renrot' ],
    'dist'		=> { COMPRESS => 'gzip', SUFFIX => 'gz' },
);
