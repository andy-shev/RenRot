package Image::RenRot::Config;

#
# vim: ts=2 sw=2 et :
#

########################################################################################
###                          CONFIGURATION FRAMEWORK                                 ###
########################################################################################

use strict;
use warnings;
require 5.006;
require Exporter;

use Image::RenRot::Util;
use Image::RenRot::Logging;

use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(str2hash update_cfg_value parse2hash assign2hash get_cfg_value);

my %options = (
  Sections => [],
  MultiOptions => [],
);

sub init {
  my $self = shift;

  while (@_) {
    my $option = shift;
    my $value = shift;

    map { push(@{$options{$option}},  $_) } @$value;
  }
}

my %incFiles = ();  # hash of included files while parsing configuration file

########################################################################################
# Usage      : parsekv() gets (key, value) pair from the string like
#            : [multiword] key = "value"
# Purpose    : parses pairs of data
# Returns    : $key, $value string
# Parameters : string like [multiword] key = "value"
# Throws     : no exceptions
# Comments   : none
# See Also   : N/A
sub parsekv {
  my $str = shift;
  my $key = undef;
  my $value = shift;

  if ($str =~ m/^([^=]+)=(.+)/) {
    ($key, $value) = (trim($1), trim($2));
    $value =~ s/^[\'\"](.+)[\'\"]/$1/;	# trim quotes
    dbgmsg (4, "Parsed: '$key' <- '$value'\n");
  } elsif ($str =~ m/^([^=]+)=$/) {
    $key = trim($1);
    dbgmsg (4, "Parsed empty '$key', applying default value: ", defined $value ? "'$value'" : "undef", "\n");
  }

  return ($key, $value);
}

########################################################################################
#
# str2hash() parses given string to a hash
#
sub str2hash {
  my $str = shift;
  my $default = shift;
  my %hash = ();

  $str =~ s/:/=/;		# change first occurrence of ':' to '='
  my ($key, $value) = parsekv($str, $default);
  if (defined $key) {
    $key =~ s/\s*[\(\[]([^\(\)\[\]]*)[\)\]]$//;
    my $group = (defined $1 and $1 ne "") ? $1 : undef;
    $hash{$key} = {value => $value, group => $group};

    # Print debug message
    $value = "" if (not defined $value);
    $group = "" if (not defined $group);
    dbgmsg (4, "Parsed: $key [$group] = '$value'\n");
  } else {
    warnmsg ("Invalid line format: $str\n");
  }
  return %hash;
}

########################################################################################
#
# parsefile() parses one file to a hash and merges it with already passed
#
sub parsefile {
  my $self = shift;
  my $file = shift;
  my $hash = shift;
  my $fc = @_ ? shift : 1;

  return if (not -f $file);

  my $tmphash = {};

  if (open (CFGFILE, "<$file")) {
    my @cfgfile = <CFGFILE>;
    unless (close (CFGFILE)) { errmsg ("$file wasn't closed!\n"); }
    $incFiles{$file} = $fc;
    my $i = 0;
    while ($i < scalar(@cfgfile)) {
      my $line = $cfgfile[$i++];

      # skip empty and comment lines
      next if (($line =~ m/^\s*$/) or ($line =~ m/^\s*#/));

      $line =~ s/#(.*)$//;  # remove trailing comments

      my ($key, $value) = parsekv($line);
      if (defined $value) {
        $key = lc($key);
        if ($key eq "include" and not $incFiles{$value}) {
          dbgmsg (2, "Parsing included file: '$value'\n");
          $self->parsefile($value, $tmphash, $fc + 1);
        }
        $key .= sprintf("#%d#%d", $fc, $i) if (grep (/^$key$/, @{$options{MultiOptions}}));
        $key .= ' ' . 'enabled' if (grep (/^$key$/, @{$options{Sections}}));
        $tmphash->{$key} = str2bool($value);
        dbgmsg (3, "Parsed line($i): '$key' <- '$tmphash->{$key}'\n");
      } else {
        warnmsg ("Unparsed line $i in configuration file.\n");
      }
    }
  } else {
    errmsg ("Can't open configuration file: $file\n");
  }
  map { $hash->{$_} = $tmphash->{$_} } keys %$tmphash;
}

########################################################################################
#
# update_cfg_value()
#
sub update_cfg_value {
  my $hash = shift;
  my $value = shift;
  return if (not defined $value);
  if (not defined $hash->{default}) {
    $hash->{default} = $hash->{value};
  }
  $hash->{value} = $value;
}

########################################################################################
# Usage      : parse2hash() gets hash with (key, value) pairs from the string like
#            : key1="value1":key2="value2":...:keyM="valueN"
# Purpose    : parses pairs of data
# Returns    : filled hash %hash
# Parameters : $str    [str] string like key1="value1":key2="value2":...:keyM="valueN"
#              $hash   [ref] reference to hash
#              $option [str] subtree in the hash
# Throws     : no exceptions
# Comments   : "value1", "value2", ..., "valueN" should not contain ':' symbol
# See Also   : parsekv()
sub parse2hash {
  my $str = shift;
  my $hash = shift;
  my $sect = shift;

  return if (not defined $str);

  my @k = keys %{$hash->{$sect}};
  foreach my $pair (split(/:/, $str)) {
    my ($key, $value) = parsekv($pair);
    next if (not defined $key);
    if (not grep (/^$key$/, @k)) {
      warnmsg ("Invalid key '$key' in '$sect'. Skiping...\n");
      next;
    }
    $value = str2bool($value) if ($hash->{$sect}{$key}{type} eq "!");
    update_cfg_value($hash->{$sect}{$key}, $value);
    dbgmsg (4, "Parsed: '$sect' -> '$key': '$value'\n");
  }
}

########################################################################################
#
# assign2hash() assignes given values to a hash
#
sub assign2hash {
  my $hash = shift;
  my $sect = shift;
  my $values = shift;
  return if (not defined $values);
  map { update_cfg_value($hash->{$sect}{$_}, $values->{$_}) } keys %$values;
}

########################################################################################
#
# apply() applies values by priority:
#     default -> config -> CLI new -> CLI old
#
sub apply {
  my $self = shift;
  my $hash = shift;
  my $value;

  foreach my $option (keys %$hash) {
    next if (ref($hash->{$option}) ne "");   # Skip non-SCALAR
    next if ($option =~ m/^[^#]+#\d+#\d+$/); # Skip multi-option

    my ($sect, $key) = undef;
    foreach my $s (@{${options}{Sections}}) {
      if ($option =~ m/^$s(.*)/) {
        ($sect, $key) = ($s, trim($1));
        last;
      }
    }
    ($sect, $key) = ('general', $option) if (not defined $sect);
    next if (not defined $hash->{$sect}{$key});

    dbgmsg (4, "Option '$option' will be put into '$sect'\n");

    # Get default value
    $value = $hash->{$sect}{$key}{default};
    my $vdef = (defined $value) ? $value : "undef";           # For debug message

    # Apply value from configuration file
    $value = $hash->{$option} if (defined $hash->{$option});
    my $vcfg = (defined $hash->{$option}) ? $value : "undef"; # For debug message

    # Apply value from command line
    $hash->{$sect}{$key}{value} = $value if (not defined $hash->{$sect}{$key}{value});

    dbgmsg (4, "'$vdef' -> '$vcfg' -> '$hash->{$sect}{$key}{value}'\n");
  }
}

########################################################################################
#
# get_cfg_value() returnes value of the given configuration option
#
sub get_cfg_value {
  my $hash = shift;
  my $key = shift;
  return $hash->{$key}{value} if (defined $hash->{$key}{value});
  return $hash->{$key}{default};
}

########################################################################################
1;  # end
