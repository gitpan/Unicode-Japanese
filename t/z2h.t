
use strict;
use Test;
BEGIN { plan tests => $]>=5.008 ? 16 : 8 }

use Unicode::Japanese;
require 'esc.pl';

#print STDERR $Unicode::Japanese::PurePerl?"PurePerl mode\n":"XS mode\n";

# -----------------------------------------------------------------------------
# h2z/z2h convert
# 

my $string;

# h2z num
$string = new Unicode::Japanese "0129";
$string->h2z();
ok($string->utf8(), "\xef\xbc\x90\xef\xbc\x91\xef\xbc\x92\xef\xbc\x99");
$]>=5.008 and ok(escfull($string->getu()), escfull("\x{ff10}\x{ff11}\x{ff12}\x{ff19}"));

# h2z alpha
$string = new Unicode::Japanese "abzABZ";
$string->h2z();
ok($string->utf8(), "\xef\xbd\x81\xef\xbd\x82\xef\xbd\x9a\xef\xbc\xa1\xef\xbc\xa2\xef\xbc\xba");
$]>=5.008 and ok($string->getu(), "\x{ff41}\x{ff42}\x{ff5a}\x{ff21}\x{ff22}\x{ff3a}");

# h2z symbol
$string = new Unicode::Japanese "!#^*(-+~{]>?";
$string->h2z();
ok($string->utf8(), "\xef\xbc\x81\xef\xbc\x83\xef\xbc\xbe\xef\xbc\x8a\xef\xbc\x88\xef\xbc\x8d\xef\xbc\x8b\xef\xbd\x9e\xef\xbd\x9b\xef\xbc\xbd\xef\xbc\x9e\xef\xbc\x9f");
$]>=5.008 and ok($string->getu(),"\x{ff01}\x{ff03}\x{ff3e}\x{ff0a}\x{ff08}\x{ff0d}\x{ff0b}\x{ff5e}\x{ff5b}\x{ff3d}\x{ff1e}\x{ff1f}");

# h2z kana / KUTEN KATA-SMALL-O HIRA-SMALL-O KANA-VU
$string = new Unicode::Japanese "\xef\xbd\xa1\xef\xbd\xab\xe3\x81\x89\xef\xbd\xb3\xef\xbe\x9e";
$string->h2z();
ok($string->utf8(), "\xe3\x80\x82\xe3\x82\xa9\xe3\x81\x89\xe3\x83\xb4");
$]>=5.008 and ok($string->getu(),"\x{3002}\x{30a9}\x{3049}\x{30f4}");

# z2h num
$string = new Unicode::Japanese "\xef\xbc\x90\xef\xbc\x91\xef\xbc\x92\xef\xbc\x99";
$string->z2h();
ok($string->utf8(), "0129");
$]>=5.008 and ok($string->getu(),"\x{30}\x{31}\x{32}\x{39}");

# z2h alpha
$string = new Unicode::Japanese "\xef\xbd\x81\xef\xbd\x82\xef\xbd\x9a\xef\xbc\xa1\xef\xbc\xa2\xef\xbc\xba";
$string->z2h();
ok($string->utf8(), "abzABZ");
$]>=5.008 and ok($string->getu(),"\x{61}\x{62}\x{7a}\x{41}\x{42}\x{5a}");

# z2h symbol
$string = new Unicode::Japanese "\xef\xbc\x81\xef\xbc\x83\xef\xbc\xbe\xef\xbc\x8a\xef\xbc\x88\xef\xbc\x8d\xef\xbc\x8b\xef\xbd\x9e\xef\xbd\x9b\xef\xbc\xbd\xef\xbc\x9e\xef\xbc\x9f";
$string->z2h();
ok($string->utf8(), "!#^*(-+~{]>?");
$]>=5.008 and ok($string->getu(),"\x{21}\x{23}\x{5e}\x{2a}\x{28}\x{2d}\x{2b}\x{7e}\x{7b}\x{5d}\x{3e}\x{3f}");

# z2h kana, HIRAGANA LETTER SMALL O is kept.
$string = new Unicode::Japanese "\xe3\x80\x82\xe3\x82\xa9\xe3\x81\x89\xe3\x83\xb4";
$string->z2h();
ok($string->utf8(), "\xef\xbd\xa1\xef\xbd\xab\xe3\x81\x89\xef\xbd\xb3\xef\xbe\x9e");
$]>=5.008 and ok($string->getu(),"\x{ff61}\x{ff6b}\x{3049}\x{ff73}\x{ff9e}");
