use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'renrot',
    'AUTHOR'		=> 'Zeus Panchenko <zeus@dn.farlep.net>',
    'VERSION_FROM'	=> 'renrot', # finds $VERSION
    'PREREQ_PM'		=> { 'Image::ExifTool' },
    'EXE_FILES'		=> [ 'renrot' ],
);
