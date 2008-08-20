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
    'dist'		=> { COMPRESS => 'gzip', SUFFIX => 'gz' }
);

package MY;

sub postamble {
    my $postamble = << 'END';

# Build rpm
rpm : tardist
	rpmbuild -ta $(DISTVNAME).tar.$(SUFFIX)
	$(RM_F) $(DISTVNAME).tar.$(SUFFIX)

srpm : tardist
	rpmbuild -ts $(DISTVNAME).tar.$(SUFFIX)
	$(RM_F) $(DISTVNAME).tar.$(SUFFIX)

# CVS tagging
tag :
	$(PERLRUN) -e 'use POSIX qw(strftime); $$date = strftime("%Y%m%d%H%M%S", localtime()); system("cvs tag $(NAME)_$$date");'
END
    return $postamble;
}
