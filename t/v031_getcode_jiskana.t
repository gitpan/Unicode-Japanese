#! /usr/bin/perl -w
# $Id: v031_getcode_jiskana.t,v 1.1 2005/09/28 13:17:10 hio Exp $
use strict;
use Test::More tests => 2;

use Unicode::Japanese;

# JIS, HANKAKU-KATAKANA, "TE SU TO"
my $txt = "\e(IC=D\e(B";

Unicode::Japanese->new(); # load dyncode.
is( Unicode::Japanese->getcode($txt), "jis", "getcode(xs): jis");
is( Unicode::Japanese::PurePerl->getcode($txt), "jis", "getcode(pp): jis");
