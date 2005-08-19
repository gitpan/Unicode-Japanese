## ----------------------------------------------------------------------------
# t/getcode.t
# -----------------------------------------------------------------------------
# $Id: getcode.t,v 1.7 2005/08/02 09:16:42 hio Exp $
# -----------------------------------------------------------------------------

use strict;
use Test;
BEGIN { plan tests => 17*2 }

# -----------------------------------------------------------------------------
# load module

use Unicode::Japanese qw(no_I18N_Japanese);

# wake lazy-loader
Unicode::Japanese->new();
print "xs status : [$Unicode::Japanese::xs_loaderror]\n";

my $code;

test("\x00\x00\xfe\xff",'utf32');

test("\xff\xfe\x00\x00",'utf32');

test("\xfe\xff",'utf16');

test("\xff\xfe",'utf16');

test("\x00\x00\x61\x1b",'utf32-be');

test("\x1b\x61\x00\x00",'utf32-le');

test("love", 'ascii');

test("\x1b\x24\x42\x30\x26\x1b\x28\x42",'jis');

test("\e\$Bx4u0u1vE\x7a\x78\x7b\x50\x7a\x70\e(B",'jis-au');

test("\x88\xa4\e\$EE\x0f",'sjis-jsky');

test("\x1b\x24\x42\x30\x26\x1b\x28\x42\e\$EE\x0f",'jis-jsky');

test("\xb0\xa6",'euc');

test("\x88\xa4",'sjis');

test("\x88\xa4\xf8\xdf", 'sjis-imode');

test("\x88\xa4\xf1\xb5",'sjis-doti');

test("\xe6\x84\x9b",'utf8');

test("\xcd\x10\x89\x01",'unknown');

# -----------------------------------------------------------------------------
# test($str,$charset)
#   test if $str is Charset $charset.
#   test both xs and purperl.
#   
sub test
{
  my $src = shift;
  my $icode = shift;
  my ($pkg,$file,$line) = caller();
  my $caller = "$file at $line";
  
  my $code = Unicode::Japanese->getcode($src);
  ok($code, $icode, 'src:'.unpack('H*',$src)." (xs) $caller");
  
  $code = Unicode::Japanese::PurePerl->getcode($src);
  ok($code, $icode, 'src:'.unpack('H*',$src)." (pp) $caller");
}
