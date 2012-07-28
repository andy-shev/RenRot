package Image::RenRot::TimeUtil;

#
# vim: ts=2 sw=2 et :
#

use strict;
use warnings;
require 5.006;
require Exporter;
use Time::localtime;
use Time::Local;

use Image::RenRot::Logging;

use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(now time_validator get_unix_time);

########################################################################################
# Usage      : now();
# Purpose    : builds timestamp in form YYYYmmddHHMMSS
# Returns    : string
# Parameters : none
# Throws     : no exceptions
# Comments   : none
# See Also   : n/a
sub now {
  my $date = localtime();
  my $time_now = sprintf("%.4d%.2d%.2d%.2d%.2d%.2d",
      $$date[5] + 1900, $$date[4] + 1, $$date[3],
      $$date[2], $$date[1], $$date[0]);
  return $time_now;
}

########################################################################################
#
# time_validator() returns correctness of timestamp in form YYYYmmddHHMMSS
#
sub time_validator {
  my $timestamp = shift;

  # check length (14)
  return 1 if (length($timestamp) != 14);

  my @tm = ($timestamp =~ m/(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/);
  return 1 unless @tm == 6;
  dbgmsg (4, "@tm\n");

  return 1 if (
      ($tm[0] < 1900) or                              # check year
      (($tm[1] > 12) or ($tm[1] < 1)) or              # check month
      (($tm[2] > 31) or ($tm[2] < 1)) or              # check day
      ($tm[3] > 23) or ($tm[4] > 59) or ($tm[5] > 59) # check hour, minute, second
  );

  return 0;
}

########################################################################################
#
# get_unix_time() converts timestamp to unix time form
#
sub get_unix_time {
  my $timestamp = shift;
  my @tm = ($timestamp =~ m/(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/);
  $tm[0] -= 1900;     # convert year
  $tm[1] -= 1;        # convert month
  @tm = reverse @tm;  # change to order required by timelocal()
  return Time::Local::timelocal(@tm);
}

########################################################################################
1;  # end
