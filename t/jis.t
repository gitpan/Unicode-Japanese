## ----------------------------------------------------------------------------
# t/jis.t
# -----------------------------------------------------------------------------
# $Id: jis.t,v 1.1 2004/05/25 15:12:03 hio Exp $
# -----------------------------------------------------------------------------

use strict;
use Test;
BEGIN { plan tests => 6, };

# -----------------------------------------------------------------------------
# load module

use Unicode::Japanese;
my $xs = Unicode::Japanese->new();
my $pp = Unicode::Japanese::PurePerl->new();
sub jisToUtf8_xs($){ tt($xs->set($_[0],'jis')->utf8()); }
sub jisToUtf8_pp($){ tt($pp->set($_[0],'jis')->utf8()); }
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
  my $correct = bin("ef bd b1 ef bd b2 ef bd b3 ef be 81 ef be 82 ef be 83 31 32 33");
  ok(jisToUtf8_xs($test),$correct,"escapet to jis.kana (xs)");
  ok(jisToUtf8_pp($test),$correct,"escapet to jis.kana (pp)");
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
