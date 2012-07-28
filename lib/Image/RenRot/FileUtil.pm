package Image::RenRot::FileUtil;

#
# vim: ts=2 sw=2 et :
#

use strict;
use warnings;
require 5.006;
require Exporter;
use File::Path;

use Image::RenRot::Logging;

use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(makedir);

########################################################################################
#
# getFileDatLns() gets data from a given file in array of lines. it returns hash
#                 of format: $hash{'field1'}[0] => 1
#                            ...
#                            $hash{'field1'}[N] => fieldN
#                 where N is the number of fields, starting from 1
#
sub getFileDatLns {
  my $self = shift;
  my $file = shift; # name of the file to be processed

  if (not defined $file or $file eq "") {
    warnmsg ("Can't read file with empty name!\n");
    return;
  }

  if (open(XXXFILE, "<$file")) {
    binmode XXXFILE;
    my %xxxData; # splited line hash
    my @chunks = ();  # arr, chunks to be placed to
    my ($i, $j);

    while (<XXXFILE>){
      chomp;
      @chunks = split(/\s+/);
      $xxxData{$chunks[0]}[0] = 1;
      for ($i = 1; $i < scalar(@chunks); $i++) {
        $xxxData{$chunks[0]}[$i] = $chunks[$i];
        dbgmsg (4, "xxxData{$chunks[0]}[$i] = $chunks[$i]\n");
      }
      undef @chunks;
    }
    unless (close(XXXFILE)) { errmsg ("$file wasn't closed!\n"); }
    return \%xxxData;
  }

  warnmsg ("Can't read file: $file!\n");
  return;
}

########################################################################################
#
# getFileDataLines() gets data from a given file in array of lines
#
sub getFileDataLines {
  my $self = shift;
  my $file = shift;

  if (not defined $file or $file eq "") {
    warnmsg ("Can't read file with empty name!\n");
    return;
  }

  if (open(XXXFILE, "<$file")) {
    binmode XXXFILE;
    my @xxxData = <XXXFILE>;
    unless (close(XXXFILE)) { errmsg ("$file wasn't closed!\n"); }
    return @xxxData;
  }

  warnmsg ("Can't read file: $file!\n");
  return;
}

########################################################################################
#
# getFileData() gets data from a given file in one-line string
#
sub getFileData {
  my $self = shift;
  my $file = shift;

  my @result = $self->getFileDataLines($file);
  return join ("", @result) if (scalar(@result) > 0);
  return undef;
}

########################################################################################
# Usage      : makedir($dir);
# Purpose    : makes one level directory
# Returns    : none
# Parameters : $dir str - directory to make
# Throws     : no exceptions
# Comments   : none
# See Also   : n/a
sub makedir {
  my $new_dir = shift;
  if (not -d $new_dir) {
    eval { mkpath($new_dir, 0, 0700) };
    if ($@) {
      errmsg ("Couldn't create $new_dir: $@");
    }
  }
}

########################################################################################
# Usage      : piper();
# Purpose    : opens two pipes for process object via the command passed as argument
# Returns    : $pipe_obj processed via $pipe_cmd
# Parameters : $pipe_obj bin - the object to be processed via pipe
#            : $pipe_cmd str - the command for the processing
# Throws     : no exceptions
# Comments   : none
# See Also   : n/a
sub piper {
  use FileHandle;
  use IPC::Open2;

  my $self = shift;

  my $pipe_obj = shift;	# the object to be processed via pipe
  my $pipe_cmd = shift;	# the pipe command

  local (*READ_FROM_FH, *WRITE_TO_FH);	# file handlers
  unless (open2(\*READ_FROM_FH, \*WRITE_TO_FH, $pipe_cmd)) {
    errmsg ("Unable to create the pipe.\n");
    return;
  }

  binmode WRITE_TO_FH;
  print WRITE_TO_FH $pipe_obj;

  unless (close(WRITE_TO_FH)) { warnmsg ("WRITE handle wasn't closed!\n"); };

  binmode READ_FROM_FH;
  my @piped_arr = <READ_FROM_FH>;

  unless (close(READ_FROM_FH)) { warnmsg ("READ handle wasn't closed!\n"); };

  return join("", @piped_arr);
}

########################################################################################
1;  # end
