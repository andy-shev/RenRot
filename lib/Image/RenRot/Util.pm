package Image::RenRot::Util;

#
# vim: ts=2 sw=2 et :
#

########################################################################################
###                               COMMON HELPERS                                     ###
########################################################################################

use strict;
use warnings;
require 5.006;
require Exporter;

use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(trim bool2str str2bool loadpkg);

########################################################################################
# Usage      : trim($value)
# Purpose    : removes heading and trailing spaces
# Returns    : trimmed $value
# Parameters : $value string
# Throws     : no exceptions
# Comments   : none
# See Also   : N/A
sub trim($) {
  my $value = shift;
  $value =~ s/^\s*//; # heading
  $value =~ s/\s*$//; # trailing
  return $value;
}

########################################################################################
# Usage      : bool2str($var)
# Purpose    : converts boolean value to human readable string
# Returns    : string "Yes" or "No"
# Parameters : 0 or 1
# Throws     : no exceptions
# Comments   : none
# See Also   : str2bool()
sub bool2str($) {
  if (shift == 0) {
    return "No";
  } else {
    return "Yes";
  }
}

########################################################################################
# Usage      : str2bool($var)
# Purpose    : converts given string to a boolean value
# Returns    : number 1 or 0
# Parameters : one of "1", "Yes", "True", "On", "0", "No", "False" or "Off"
# Throws     : no exceptions
# Comments   : none
# See Also   : bool2str()
sub str2bool($) {
  my $value = trim(shift);
  if ($value =~ m/^(0|No|False|Off|Disable)$/i) {
    return 0;
  } elsif ($value =~ m/^(1|Yes|True|On|Enable)$/i) {
    return 1;
  }
  return $value;
}

########################################################################################
# Usage      : loadpkg($pkg)
# Purpose    : checks availability of given package (renrot could be depend of it)
# Returns    : nothing in case the package available and undef if not
# Parameters : $pkg - string with package name
# Throws     : no exceptions
# Comments   : none
# See Also   : n/a
sub loadpkg($) {
  my $pkg = shift;
  return undef unless eval "require $pkg";
}

########################################################################################
1;  # end
