## ----------------------------------------------------------------------------
# t/emoji.t
# -----------------------------------------------------------------------------
# $Id: emoji.t,v 1.9 2004/03/07 10:10:44 hio Exp $
# -----------------------------------------------------------------------------

use strict;
use Test;
BEGIN { plan tests => 20 *14 +6*2; }

# -----------------------------------------------------------------------------
# load module

use Unicode::Japanese qw(no_I18N_Japanese);

require './esc.pl';

# -----------------------------------------------------------------------------
# test(type, ucs4, sjis
#      imode1, imode2, doti, jsky1, jsky2 );
#  type: imode1/imode2/doti/jsky1/doti2
#  ucs4: 0x0fxxxx
# 
# 14 tests at one test() call.
# 7 tests, ucs4,sjis,imode1,imode2,doti,jsky1, and jsky2 are
# by XS and PurePerl.
# 
# (ja:) °ìÅÙ¤Î test() ¸Æ¤Ó½Ð¤·¤Ç, 14¤Î¥Æ¥¹¥È
# (ja:) (ucs4,sjis,imode1,imode2,doti,jsky1,jsky2 ¤Î£·¼ïÎà¤ò XS ¤È PurePerl ¤Ç)
#

# jsky-escape
sub je
{
  "\e\$".join('',@_)."\x0f";
}

my $STR = Unicode::Japanese->new();
my $PPSTR = Unicode::Japanese::PurePerl->new();
if( !-e 't/pureperl.flag' && $Unicode::Japanese::xs_loaderror )
{
  print STDERR "xs load error : [$Unicode::Japanese::xs_loaderror]\n";
}


# -----------------------------------------------------------------------------
# sunset (jsky2 only)
# jsky2.Í¼Æü => jsky1.Í¼¾Æ¤±
$STR->set("\x00\x0f\xfc\xea",'ucs4');
ok(escfull($STR->ucs4()),escfull("\0\x0f\xfc\xea"));
ok(escfull($STR->sjis_jsky2()),escfull(je("\x50\x6a")));
ok(escfull($STR->sjis_jsky1()),escfull(je("\x45\x66")));
$PPSTR->set("\x00\x0f\xfc\xea",'ucs4');
ok(escfull($PPSTR->ucs4()),escfull("\0\x0f\xfc\xea"));
ok(escfull($PPSTR->sjis_jsky2()),escfull(je("\x50\x6a")));
ok(escfull($PPSTR->sjis_jsky1()),escfull(je("\x45\x66")));

# -----------------------------------------------------------------------------
# dollar bag (imode2 only)
# imode2.¡ðÂÞ => imode1.ÂÞ
$STR->set("\x00\x0f\xf9\xba",'ucs4');
ok(escfull($STR->ucs4()),escfull("\0\x0f\xf9\xba"));
ok(escfull($STR->sjis_imode2()),escfull("\xf9\xba"));
ok(escfull($STR->sjis_imode1()),escfull("\xf9\x51"));
$PPSTR->set("\x00\x0f\xf9\xba",'ucs4');
ok(escfull($PPSTR->ucs4()),escfull("\0\x0f\xf9\xba"));
ok(escfull($PPSTR->sjis_imode2()),escfull("\xf9\xba"));
ok(escfull($PPSTR->sjis_imode1()),escfull("\xf9\x51"));

# -----------------------------------------------------------------------------
# the sun
# À²¤ì,F89F,,F0E5,476A,,002C
# 
test( 'imode1', 0x0FF89F, '?',
      "\xF8\x9F", "\xF8\x9F", "\xF0\xE5", je("\x47\x6a"), je("\x47\x6a") );
test( 'imode2', 0x0FF89F, '?',
      "\xF8\x9F", "\xF8\x9F", "\xF0\xE5", je("\x47\x6a"), je("\x47\x6a") );
test( 'doti', 0x0FF0E5, '?',
      "\xF8\x9F", "\xF8\x9F", "\xF0\xE5", je("\x47\x6a"), je("\x47\x6a") );
test( 'jsky1', 0x0FFD6A, '?',
      "\xF8\x9F", "\xF8\x9F", "\xF0\xE5", je("\x47\x6a"), je("\x47\x6a") );
test( 'jsky2', 0x0FFD6A, '?',
      "\xF8\x9F", "\xF8\x9F", "\xF0\xE5", je("\x47\x6a"), je("\x47\x6a") );

# -----------------------------------------------------------------------------
# rainy (umbrella/rain cloud)
# ±«(»±),F8A1,,F1BA,476B,,005F
# ±«(±«±À),=F8A1,,F0E7,=476B,,=005F
# 
test( 'imode1', 0x0FF8A1, '?',
      "\xF8\xA1", "\xF8\xA1", "\xF1\xBA", je("\x47\x6b"), je("\x47\x6b") );
test( 'imode2', 0x0FF8A1, '?',
      "\xF8\xA1", "\xF8\xA1", "\xF1\xBA", je("\x47\x6b"), je("\x47\x6b") );
test( 'doti', 0x0FF1BA, '?',
      "\xF8\xA1", "\xF8\xA1", "\xF1\xBA", je("\x47\x6b"), je("\x47\x6b") );
test( 'jsky1', 0x0FFD6B, '?',
      "\xF8\xA1", "\xF8\xA1", "\xF1\xBA", je("\x47\x6b"), je("\x47\x6b") );
test( 'jsky2', 0x0FFD6B, '?',
      "\xF8\xA1", "\xF8\xA1", "\xF1\xBA", je("\x47\x6b"), je("\x47\x6b") );
#
test( 'doti', 0x0FF0E7, '?',
      "\xF8\xA1", "\xF8\xA1", "\xF0\xE7", je("\x47\x6b"), je("\x47\x6b") );

# -----------------------------------------------------------------------------
# digit 0, (normal, framed+bgcolored, framed)
# £°,=F990,,F040,=4645,,=0145
# [£°](¿§ÃÏ),=F990,,F2B2,4645,,0145
# [£°](ÇòÃÏ),F990,,F2B5,=4645,,=0145
# 
test( 'doti', 0x0FF040, '?',
      "\xf9\x90", "\xf9\x90", "\xf0\x40", je("\x46\x45"), je("\x46\x45") );
#
test( 'doti',  0x0FF2B2, '?',
      "\xf9\x90", "\xf9\x90", "\xf2\xb2", je("\x46\x45"), je("\x46\x45") );
test( 'jsky1', 0x0FFC45, '?',
      "\xf9\x90", "\xf9\x90", "\xf2\xb2", je("\x46\x45"), je("\x46\x45") );
test( 'jsky2', 0x0FFC45, '?',
      "\xf9\x90", "\xf9\x90", "\xf2\xb2", je("\x46\x45"), je("\x46\x45") );
#
test( 'imode1', 0x0FF990, '?',
      "\xf9\x90", "\xf9\x90", "\xf2\xb5", je("\x46\x45"), je("\x46\x45") );
test( 'imode2', 0x0FF990, '?',
      "\xf9\x90", "\xf9\x90", "\xf2\xb5", je("\x46\x45"), je("\x46\x45") );
test( 'doti',   0x0FF2B5, '?',
      "\xf9\x90", "\xf9\x90", "\xf2\xb5", je("\x46\x45"), je("\x46\x45") );

# -----------------------------------------------------------------------------
# bell
# ¥Ù¥ë,,F9B8,,,4F45,0030
# 
test( 'imode2', 0x0FF9B8, '?',
      '?', "\xf9\xb8", '?', '?', je("\x4f\x45") );
test( 'jsky2', 0x0FFBC5, '?',
      '?', "\xf9\xb8", '?', '?', je("\x4f\x45") );

# -----------------------------------------------------------------------------
# test method.
sub test
{
  my ($code,$ucs4,$sjis) = splice(@_,0,3);
  my ($imode1,$imode2,$doti,$jsky1,$jsky2) = splice(@_,0,5);
  
  $ucs4 = pack('N',$ucs4);
  
  if( $code !~ /^(imode[12]|doti|jsky[12])$/ )
  {
    die "code invalid [$code]";
  }
  my $src = eval "\$$code";
  $@ and die $@;
  my $str = Unicode::Japanese->new($src,"sjis-$code");
  my $pp  = Unicode::Japanese::PurePerl->new($src,"sjis-$code");
  if( $code =~ /jsky/ && $src =~ /^\e\$(.*)\x0f$/ )
  {
    $src = "$code#je(".uc(unpack('H*',$1)).')';
  }else
  {
    $src = "$code#".uc(unpack('H*',$src));
  }
  
  my ($pkg,$file,$line) = caller();
  my $caller = "$file at $line";
  
  foreach($ucs4,$sjis,$imode1,$imode2,$doti,$jsky1,$jsky2)
  {
    $_ = escfull($_);
  }
  
  # in => ucs4
  ok(escfull($str->ucs4()),$ucs4,"$src=>ucs4 (xs), $caller");
  ok(escfull($pp ->ucs4()),$ucs4,"$src=>ucs4 (pp), $caller");

  # ucs4 => others
  ok(escfull($str->sjis()),       $sjis,  "$src=>ucs4=>sjis (xs), $caller" );
  ok(escfull($pp ->sjis()),       $sjis,  "$src=>ucs4=>sjis (pp), $caller" );
  ok(escfull($str->sjis_imode1()),$imode1,"$src=>ucs4=>imode1 (xs), $caller");
  ok(escfull($pp ->sjis_imode1()),$imode1,"$src=>ucs4=>imode1 (pp), $caller");
  ok(escfull($str->sjis_imode2()),$imode2,"$src=>ucs4=>imode2 (xs), $caller");
  ok(escfull($pp ->sjis_imode2()),$imode2,"$src=>ucs4=>imode2 (pp), $caller");
  ok(escfull($str->sjis_doti()),  $doti,  "$src=>ucs4=>doti (xs), $caller" );
  ok(escfull($pp ->sjis_doti()),  $doti,  "$src=>ucs4=>doti (pp), $caller" );
  ok(escfull($str->sjis_jsky1()), $jsky1, "$src=>ucs4=>jsky1 (xs), $caller" );
  ok(escfull($pp ->sjis_jsky1()), $jsky1, "$src=>ucs4=>jsky1 (pp), $caller" );
  ok(escfull($str->sjis_jsky2()), $jsky2, "$src=>ucs4=>jsky2 (xs), $caller" );
  ok(escfull($pp ->sjis_jsky2()), $jsky2, "$src=>ucs4=>jsky2 (pp), $caller" );
}
