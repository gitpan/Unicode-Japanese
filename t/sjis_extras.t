#! /usr/bin/perl -w

use strict;
use warnings;
use Test::More tests => 8;
use Unicode::Japanese;

&test_extras;

sub test_extras
{
	foreach my $code (qw(00a2 00a3 00a5 00ac 2016 203e 2212 301c))
	{
		my $sjis = Unicode::Japanese->new(pack("H*",$code),"ucs2")->sjis;
		like($sjis, qr/^[^?&].?$/, "U+$code => sjis");
	}
}
