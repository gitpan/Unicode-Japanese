## ----------------------------------------------------------------------------
# t/jis.t
# -----------------------------------------------------------------------------
# $Id: jis.t,v 1.2 2005/05/15 08:34:48 hio Exp $
# -----------------------------------------------------------------------------

use strict;
use Test;
BEGIN { plan tests => 8, };

# -----------------------------------------------------------------------------
# load module

use Unicode::Japanese;
my $xs = Unicode::Japanese->new();
my $pp = Unicode::Japanese::PurePerl->new();
sub jisToUtf8_xs($){ tt($xs->set($_[0],'jis')->utf8()); }
sub jisToUtf8_pp($){ tt($pp->set($_[0],'jis')->utf8()); }
sub jisToSjis_xs($){ tt($xs->set($_[0],'jis')->sjis()); }
sub jisToSjis_pp($){ tt($pp->set($_[0],'jis')->sjis()); }
sub tt($){ join(' ',map{unpack("H*",$_)}split(//,$_[0])); }
sub bin($){ $_[0]; }

{
  # ASCII : \e(B 
  #
  my $test = "\e(B123ABC\e(B123";
  my $correct = tt("123ABC123");
  ok(jisToUtf8_xs($test),$correct,"escapet to ASCII (xs)");
  ok(jisToUtf8_pp($test),$correct,"escapet to ASCII (pp)");
}

{
  # jis.roman : \e(J
  #
  my $test = "\e(J123ABC\e(B123";
  my $correct = tt("123ABC123");
  ok(jisToUtf8_xs($test),$correct,"escapet to jis.roman (xs)");
  ok(jisToUtf8_pp($test),$correct,"escapet to jis.roman (pp)");
}

{
  # jis.kana : \e(I
  #
  my $test = "\e(I123ABC\e(B123";
  my $correct_utf8 = bin("ef bd b1 ef bd b2 ef bd b3 ef be 81 ef be 82 ef be 83 31 32 33");
  my $correct_sjis = bin("b1 b2 b3 c1 c2 c3 31 32 33");
  ok(jisToSjis_xs($test),$correct_sjis,"escapet to jis.kana (xs/sjis)");
  ok(jisToSjis_pp($test),$correct_sjis,"escapet to jis.kana (pp/sjis)");
  ok(jisToUtf8_xs($test),$correct_utf8,"escapet to jis.kana (xs/utf8)");
  ok(jisToUtf8_pp($test),$correct_utf8,"escapet to jis.kana (pp/utf8)");
}
{
  # jis.kana(so/si)
  #
  my $test = "\x0e123ABC\x0f123";
  my $correct = bin("ef bd b1 ef bd b2 ef bd b3 ef be 81 ef be 82 ef be 83 31 32 33");
  #skip("so/si not supported yet",jisToUtf8_xs($test),$correct,"escapet to jis.roman (xs)");
  #skip("so/si not supported yet",jisToUtf8_pp($test),$correct,"escapet to jis.roman (pp)");
}

{
  # jis-x-0208-1978(旧JIS) : \e$@
  # jis-x-0208-1983(新JIS) : \e$B
  # jis-x-0208-1990 : \e&@\e$B
  #skip("jis-x-0208 not ready");
  #skip("jis-x-0208 not ready");
  ;
}

{
  # jis-x-0212-1990: \e$(D
  #skip("jis-x-0212 not ready");
  #skip("jis-x-0212 not ready");
  ;
}

# -----------------------------------------------------------------------------
# End Of File.
# -----------------------------------------------------------------------------
