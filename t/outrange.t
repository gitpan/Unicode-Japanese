
use Test;

use Unicode::Japanese;

BEGIN { plan tests => 6 }

## check from utf8 convert

my $string;

# sjis
$string = new Unicode::Japanese "\xe2\x99\xa5";
ok($string->sjis, "&#9829;");

# euc
$string = new Unicode::Japanese "\xe2\x99\xa5";
ok($string->euc, "&#9829;");

# jis(iso-2022-jp)
$string = new Unicode::Japanese "\xe2\x99\xa5";
ok($string->jis, "&#9829;");

# imode
$string = new Unicode::Japanese "\xe2\x99\xa5";
ok($string->sjis_imode, "?");

# dot-i
$string = new Unicode::Japanese "\xe2\x99\xa5";
ok($string->sjis_doti, "?");

# j-sky
$string = new Unicode::Japanese "\xe2\x99\xa5";
ok($string->sjis_jsky, "?");


