## ----------------------------------------------------------------------------
#  t/illegal.t
# -----------------------------------------------------------------------------
# Mastering programed by YAMASHINA Hio
#
# Copyright YMIRLINK,Inc.
# -----------------------------------------------------------------------------
# $Id: illegal.t,v 1.4 2005/05/15 10:29:29 hio Exp $
# -----------------------------------------------------------------------------
use strict;
use Test::More tests => 36;
use Unicode::Japanese;

my $Z1 = "\0";
my $Z2 = "\xc0\x80";
my $Z3 = "\xe0\x80\x80";
my $Z4 = "\xf0\x80\x80\x80";
my $Z5 = "\xf8\x80\x80\x80\x80";
my $Z6 = "\xfc\x80\x80\x80\x80\x80";

sub u{ unpack("H*",$_[0]) }

# -----------------------------------------------------------------------------
# internal data
#
{
  my $d = "internal data / \\x00";
  my $U = Unicode::Japanese->new();
  is(u($U->set($Z1)->{str}), u("\x00"), "$d (1 byte)");
  is(u($U->set($Z2)->{str}), u("?"),    "$d (2 bytes)");
  is(u($U->set($Z3)->{str}), u("?"),    "$d (3 bytes)");
  is(u($U->set($Z4)->{str}), u("?"),    "$d (4 bytes)");
  is(u($U->set($Z5)->{str}), u("?"),    "$d (5 bytes)");
  is(u($U->set($Z6)->{str}), u("?"),    "$d (6 bytes)");
}

# -----------------------------------------------------------------------------
# sjis
#
{
  my $d = "sjis / \\x00";
  my $U = Unicode::Japanese->new();
  $U->{str}=$Z1; is(u($U->sjis()), u("\x00"), "$d (1 byte)");
  $U->{str}=$Z2; is(u($U->sjis()), u("?"),    "$d (2 bytes)");
  $U->{str}=$Z3; is(u($U->sjis()), u("?"),    "$d (3 bytes)");
  $U->{str}=$Z4; is(u($U->sjis()), u("?"),    "$d (4 bytes)");
  $U->{str}=$Z5; is(u($U->sjis()), u("?"),    "$d (5 bytes)");
  $U->{str}=$Z6; is(u($U->sjis()), u("?"),    "$d (6 bytes)");
}

# -----------------------------------------------------------------------------
# utf8
#
{
  my $d = "utf8 / \\x00";
  my $U = Unicode::Japanese->new();
  $U->{str}=$Z1; is(u($U->utf8()), u("\x00"), "$d (1 byte)");
  $U->{str}=$Z2; is(u($U->utf8()), u("?"),    "$d (2 bytes)");
  $U->{str}=$Z3; is(u($U->utf8()), u("?"),    "$d (3 bytes)");
  $U->{str}=$Z4; is(u($U->utf8()), u("?"),    "$d (4 bytes)");
  $U->{str}=$Z5; is(u($U->utf8()), u("?"),    "$d (5 bytes)");
  $U->{str}=$Z6; is(u($U->utf8()), u("?"),    "$d (6 bytes)");
}

# -----------------------------------------------------------------------------
# ucs2
#
{
  my $d = "ucs2 / \\x00";
  my $U = Unicode::Japanese->new();
  $U->{str}=$Z1; is(u($U->ucs2()), u("\x00\x00"), "$d (1 byte)");
  $U->{str}=$Z2; is(u($U->ucs2()), u("\x00?"),    "$d (2 bytes)");
  $U->{str}=$Z3; is(u($U->ucs2()), u("\x00?"),    "$d (3 bytes)");
  $U->{str}=$Z4; is(u($U->ucs2()), u("\x00?"),    "$d (4 bytes)");
  $U->{str}=$Z5; is(u($U->ucs2()), u("\x00?"),    "$d (5 bytes)");
  $U->{str}=$Z6; is(u($U->ucs2()), u("\x00?"),    "$d (6 bytes)");
}

# -----------------------------------------------------------------------------
# ucs4
#
{
  my $d = "ucs4 / \\x00";
  my $U = Unicode::Japanese->new();
  $U->{str}=$Z1; is(u($U->ucs4()), u("\x00\x00\x00\x00"), "$d (1 byte)");
  $U->{str}=$Z2; is(u($U->ucs4()), u("\x00\x00\x00?"),    "$d (2 bytes)");
  $U->{str}=$Z3; is(u($U->ucs4()), u("\x00\x00\x00?"),    "$d (3 bytes)");
  $U->{str}=$Z4; is(u($U->ucs4()), u("\x00\x00\x00?"),    "$d (4 bytes)");
  $U->{str}=$Z5; is(u($U->ucs4()), u("\x00\x00\x00?"),    "$d (5 bytes)");
  $U->{str}=$Z6; is(u($U->ucs4()), u("\x00\x00\x00?"),    "$d (6 bytes)");
}

# -----------------------------------------------------------------------------
# utf16
#
{
  my $d = "utf16 / \\x00";
  my $U = Unicode::Japanese->new();
  $U->{str}=$Z1; is(u($U->utf16()), u("\x00\x00"), "$d (1 byte)");
  $U->{str}=$Z2; is(u($U->utf16()), u("\x00?"),    "$d (2 bytes)");
  $U->{str}=$Z3; is(u($U->utf16()), u("\x00?"),    "$d (3 bytes)");
  $U->{str}=$Z4; is(u($U->utf16()), u("\x00?"),    "$d (4 bytes)");
  $U->{str}=$Z5; is(u($U->utf16()), u("\x00?"),    "$d (5 bytes)");
  $U->{str}=$Z6; is(u($U->utf16()), u("\x00?"),    "$d (6 bytes)");
}

# -----------------------------------------------------------------------------
# End Of File.
# -----------------------------------------------------------------------------
