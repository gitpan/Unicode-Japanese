## ----------------------------------------------------------------------------
# t/emoji.t
# -----------------------------------------------------------------------------
# $Id: emoji.t,v 1.13 2005/08/18 09:39:33 hio Exp $
# -----------------------------------------------------------------------------

use strict;
use Test;
BEGIN { plan tests => 25 *22 +6*4 + 15*2; }

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
# (ja:) ���٤� test() �ƤӽФ���, 22�Υƥ���
# (ja:) (ucs4,sjis,imode1,imode2,doti,jsky1,jsky2,au1,au2,au1-icon,au2-icon
#        ��11����� XS �� PurePerl ��)
#

# jsky-escape
sub je
{
  "\e\$".join('',@_)."\x0f";
}

# au-escape
sub ae
{
  "\e\$B" . join('', @_) . "\e\(B";
}

# au-icon
sub ai
{
  '<IMG ICON="' . join('', @_) . '">';
}


my $STR = Unicode::Japanese->new();
my $PPSTR = Unicode::Japanese::PurePerl->new();
if( !-e 't/pureperl.flag' && $Unicode::Japanese::xs_loaderror )
{
  print STDERR "xs load error : [$Unicode::Japanese::xs_loaderror]\n";
}


# -----------------------------------------------------------------------------
# sunrise (jsky2 only, jsky1 compat)
# 
# jsky2-sunrise: jsky1 compat.
$STR->set("\x00\x0f\xfc\xe9",'ucs4');
ok(escfull($STR->ucs4()),escfull("\0\x0f\xfc\xe9"));
ok(escfull($STR->sjis_jsky2()),escfull(je("\x50\x69")));
ok(escfull($STR->sjis_jsky1()),escfull(je("\x47\x6d")));
$PPSTR->set("\x00\x0f\xfc\xe9",'ucs4');
ok(escfull($PPSTR->ucs4()),escfull("\0\x0f\xfc\xe9"));
ok(escfull($PPSTR->sjis_jsky2()),escfull(je("\x50\x69")));
ok(escfull($PPSTR->sjis_jsky1()),escfull(je("\x47\x6d")));
# jsky1-sunrise: jsky2 kept.
$STR->set("\x00\x0f\xfd\x6d",'ucs4');
ok(escfull($STR->ucs4()),escfull("\0\x0f\xfd\x6d"));
ok(escfull($STR->sjis_jsky2()),escfull(je("\x47\x6d")));
ok(escfull($STR->sjis_jsky1()),escfull(je("\x47\x6d")));
$PPSTR->set("\x00\x0f\xfd\x6d",'ucs4');
ok(escfull($PPSTR->ucs4()),escfull("\0\x0f\xfd\x6d"));
ok(escfull($PPSTR->sjis_jsky2()),escfull(je("\x47\x6d")));
ok(escfull($PPSTR->sjis_jsky1()),escfull(je("\x47\x6d")));

# -----------------------------------------------------------------------------
# dollar bag (imode2 only)
# imode2.���� => imode1.��
#
# imode2-dollar bag: imode1 compat.
$STR->set("\x00\x0f\xf9\xba",'ucs4');
ok(escfull($STR->ucs4()),escfull("\0\x0f\xf9\xba"));
ok(escfull($STR->sjis_imode2()),escfull("\xf9\xba"));
ok(escfull($STR->sjis_imode1()),escfull("\xf9\x51"));
$PPSTR->set("\x00\x0f\xf9\xba",'ucs4');
ok(escfull($PPSTR->ucs4()),escfull("\0\x0f\xf9\xba"));
ok(escfull($PPSTR->sjis_imode2()),escfull("\xf9\xba"));
ok(escfull($PPSTR->sjis_imode1()),escfull("\xf9\x51"));
# imode1-dollar bag: imode2 kept.
$STR->set("\x00\x0f\xf9\x51",'ucs4');
ok(escfull($STR->ucs4()),escfull("\0\x0f\xf9\x51"));
ok(escfull($STR->sjis_imode2()),escfull("\xf9\x51"));
ok(escfull($STR->sjis_imode1()),escfull("\xf9\x51"));
$PPSTR->set("\x00\x0f\xf9\x51",'ucs4');
ok(escfull($PPSTR->ucs4()),escfull("\0\x0f\xf9\x51"));
ok(escfull($PPSTR->sjis_imode2()),escfull("\xf9\x51"));
ok(escfull($PPSTR->sjis_imode1()),escfull("\xf9\x51"));

# -----------------------------------------------------------------------------
# the sun
# ����,F89F,,F0E5,476A,,002C
# 
test( 'sjis-imode1', 0x0FF89F, '?',
      "\xF8\x9F", "\xF8\x9F", "\xF0\xE5", je("\x47\x6a"), je("\x47\x6a"),
      ae("\x75\x41"), ae("\x75\x41"), ai(44), ai(44));
test( 'sjis-imode2', 0x0FF89F, '?',
      "\xF8\x9F", "\xF8\x9F", "\xF0\xE5", je("\x47\x6a"), je("\x47\x6a"),
      ae("\x75\x41"), ae("\x75\x41"), ai(44), ai(44));
test( 'sjis-doti', 0x0FF0E5, '?',
      "\xF8\x9F", "\xF8\x9F", "\xF0\xE5", je("\x47\x6a"), je("\x47\x6a"),
      ae("\x75\x41"), ae("\x75\x41"), ai(44), ai(44));
test( 'sjis-jsky1', 0x0FFD6A, '?',
      "\xF8\x9F", "\xF8\x9F", "\xF0\xE5", je("\x47\x6a"), je("\x47\x6a"),
      ae("\x75\x41"), ae("\x75\x41"), ai(44), ai(44));
test( 'sjis-jsky2', 0x0FFD6A, '?',
      "\xF8\x9F", "\xF8\x9F", "\xF0\xE5", je("\x47\x6a"), je("\x47\x6a"),
      ae("\x75\x41"), ae("\x75\x41"), ai(44), ai(44));
test( 'jis-au1', 0x0FE02C, '?',
      "\xF8\x9F", "\xF8\x9F", "\xF0\xE5", je("\x47\x6a"), je("\x47\x6a"),
      ae("\x75\x41"), ae("\x75\x41"), ai(44), ai(44));

# -----------------------------------------------------------------------------
# rainy (umbrella/rain cloud)
# ��(��),F8A1,,F1BA,476B,,005F
# ��(����),=F8A1,,F0E7,=476B,,=005F
# 
test( 'sjis-imode1', 0x0FF8A1, '?',
      "\xF8\xA1", "\xF8\xA1", "\xF1\xBA", je("\x47\x6b"), je("\x47\x6b"),
      ae("\x75\x45"), ae("\x75\x45"), ai(95), ai(95));
test( 'sjis-imode2', 0x0FF8A1, '?',
      "\xF8\xA1", "\xF8\xA1", "\xF1\xBA", je("\x47\x6b"), je("\x47\x6b"),
      ae("\x75\x45"), ae("\x75\x45"), ai(95), ai(95));
test( 'sjis-doti', 0x0FF1BA, '?',
      "\xF8\xA1", "\xF8\xA1", "\xF1\xBA", je("\x47\x6b"), je("\x47\x6b"),
      ae("\x75\x45"), ae("\x75\x45"), ai(95), ai(95));
test( 'sjis-jsky1', 0x0FFD6B, '?',
      "\xF8\xA1", "\xF8\xA1", "\xF1\xBA", je("\x47\x6b"), je("\x47\x6b"),
      ae("\x75\x45"), ae("\x75\x45"), ai(95), ai(95));
test( 'sjis-jsky2', 0x0FFD6B, '?',
      "\xF8\xA1", "\xF8\xA1", "\xF1\xBA", je("\x47\x6b"), je("\x47\x6b"),
      ae("\x75\x45"), ae("\x75\x45"), ai(95), ai(95));
test( 'jis-au1', 0x0FE05F, '?',
      "\xF8\xA1", "\xF8\xA1", "\xF1\xBA", je("\x47\x6b"), je("\x47\x6b"),
      ae("\x75\x45"), ae("\x75\x45"), ai(95), ai(95));
#
test( 'sjis-doti', 0x0FF0E7, '?',
      "\xF8\xA1", "\xF8\xA1", "\xF0\xE7", je("\x47\x6b"), je("\x47\x6b"),
      ae("\x75\x45"), ae("\x75\x45"), ai(95), ai(95));

# -----------------------------------------------------------------------------
# digit 0, (normal, framed+bgcolored, framed)
# ��,=F990,,F040,=4645,,=0145
# [��](����),=F990,,F2B2,4645,,0145
# [��](����),F990,,F2B5,=4645,,=0145
# 
test( 'sjis-doti', 0x0FF040, '?',
      "\xf9\x90", "\xf9\x90", "\xf0\x40", je("\x46\x45"), je("\x46\x45"),
      ae("\x78\x4b"), ae("\x78\x4b"), ai(325), ai(325) );
#
test( 'sjis-doti',  0x0FF2B2, '?',
      "\xf9\x90", "\xf9\x90", "\xf2\xb2", je("\x46\x45"), je("\x46\x45"),
      ae("\x78\x4b"), ae("\x78\x4b"), ai(325), ai(325) );
test( 'sjis-jsky1', 0x0FFC45, '?',
      "\xf9\x90", "\xf9\x90", "\xf2\xb2", je("\x46\x45"), je("\x46\x45"),
      ae("\x78\x4b"), ae("\x78\x4b"), ai(325), ai(325) );
test( 'sjis-jsky2', 0x0FFC45, '?',
      "\xf9\x90", "\xf9\x90", "\xf2\xb2", je("\x46\x45"), je("\x46\x45"),
      ae("\x78\x4b"), ae("\x78\x4b"), ai(325), ai(325) );
test( 'jis-au1', 0x0FE145, '?',
      "\xf9\x90", "\xf9\x90", "\xf2\xb2", je("\x46\x45"), je("\x46\x45"),
      ae("\x78\x4b"), ae("\x78\x4b"), ai(325), ai(325) );
#
test( 'sjis-imode1', 0x0FF990, '?',
      "\xf9\x90", "\xf9\x90", "\xf2\xb5", je("\x46\x45"), je("\x46\x45"),
      ae("\x78\x4b"), ae("\x78\x4b"), ai(325), ai(325) );
test( 'sjis-imode2', 0x0FF990, '?',
      "\xf9\x90", "\xf9\x90", "\xf2\xb5", je("\x46\x45"), je("\x46\x45"),
      ae("\x78\x4b"), ae("\x78\x4b"), ai(325), ai(325) );
test( 'sjis-doti',   0x0FF2B5, '?',
      "\xf9\x90", "\xf9\x90", "\xf2\xb5", je("\x46\x45"), je("\x46\x45"),
      ae("\x78\x4b"), ae("\x78\x4b"), ai(325), ai(325) );

# -----------------------------------------------------------------------------
# bell
# �٥�,,F9B8,,,4F45,0030
# 
test( 'sjis-imode2', 0x0FF9B8, '?',
      '?', "\xf9\xb8", '?', '?', je("\x4f\x45"),
      ae("\x76\x6d"), ae("\x76\x6d"), ai(48), ai(48));
test( 'sjis-jsky2', 0x0FFBC5, '?',
      '?', "\xf9\xb8", '?', '?', je("\x4f\x45"),
      ae("\x76\x6d"), ae("\x76\x6d"), ai(48), ai(48));
test( 'jis-au1', 0x0FE030, '?',
      '?', "\xf9\xb8", '?', '?', je("\x4f\x45"),
      ae("\x76\x6d"), ae("\x76\x6d"), ai(48), ai(48));

# -----------------------------------------------------------------------------
# ���å�,F8D1,,F0B4,4765,,005D,
#
test( 'jis-au2', 0x0FE05D, '?',
      "\xf8\xd1", "\xf8\xd1", "\xf0\xb4", je("\x47\x65"), je("\x47\x65"),
      ae("\x78\x36"), ae("\x78\x36"), ai(93), ai(93));


# -----------------------------------------------------------------------------
# �� WHITE STAR
# U+2606, SJIS:8199
#
{
  my $xs = Unicode::Japanese->new();
  my $pp = Unicode::Japanese::PurePerl->new();
  #print STDERR "# white star (sjis)\n";
  my $s = "\x81\x99";
  my $j = Unicode::Japanese->new($s,'sjis')->jis();
  my $u = "\x26\x06";
  foreach my $code (qw(sjis sjis-imode1 sjis-imode2 sjis-doti sjis-jsky1 sjis-jsky2 sjis-icon-au1 sjis-icon-au2))
  {
    ok(escfull($xs->set($s,$code)->ucs2),escfull($u),"WHITE STAR: $code:ucs2");
    ok(escfull($xs->set($u,"ucs2")->conv($code)),escfull($s),"WHITE STAR: ucs2:$code");
  }
  #print STDERR "# white star (jis)\n";
  foreach my $code (qw(jis jis-jsky1 jis-jsky2 jis-au1 jis-au2 jis-icon-au1 jis-icon-au2))
  {
    ok(1);#ok(escfull($xs->set($j,$code)->ucs2),escfull($u),"WHITE STAR: $code:ucs2");
    ok(1);#ok(escfull($xs->set($u,"ucs2")->conv($code)),escfull($j),"WHITE STAR: ucs2:$code");
  }
}

# -----------------------------------------------------------------------------
# test method.
sub test
{
  my ($code,$ucs4,$sjis) = splice(@_,0,3);
  my ($imode1,$imode2,$doti,$jsky1,$jsky2,$au1,$au2,$au1i,$au2i) = splice(@_,0,9);
  
  $ucs4 = pack('N',$ucs4);
  
  if( $code !~ /^(sjis-imode[12]|sjis-doti|sjis-jsky[12]|jis-au[12]|sjis-au[12]i)$/ )
  {
    die "code invalid [$code]";
  }
  my $shortcode = $code;
  $shortcode =~ s/^s?jis\-//;
  $shortcode =~ s/^icon\-(.*)/$1i/;
  my $src = eval "\$$shortcode";
  $@ and die $@;
  my $str = Unicode::Japanese->new($src,$code);
  my $pp  = Unicode::Japanese::PurePerl->new($src,$code);
  if( $code =~ /jsky/ && $src =~ /^\e\$(.*)\x0f$/ )
  {
    $src = "$code#je(".uc(unpack('H*',$1)).')';
  }else
  {
    $src = "$code#".uc(unpack('H*',$src));
  }
  
  my ($pkg,$file,$line) = caller();
  my $caller = "$file at $line";
  
  foreach($ucs4,$sjis,$imode1,$imode2,$doti,$jsky1,$jsky2,$au1,$au2,$au1i,$au2i)
  {
    $_ = escfull($_);
  }
  
  # input value => ucs4
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
  ok(escfull($str->jis_au1()),    $au1,   "$src=>ucs4=>au1 (xs), $caller" );
  ok(escfull($pp ->jis_au1()),    $au1,   "$src=>ucs4=>au1 (pp), $caller" );
  ok(escfull($str->jis_au2()),    $au2,   "$src=>ucs4=>au2 (xs), $caller" );
  ok(escfull($pp ->jis_au2()),    $au2,   "$src=>ucs4=>au2 (pp), $caller" );
  ok(escfull($str->sjis_icon_au1()), $au1i, "$src=>ucs4=>au1i (xs), $caller" );
  ok(escfull($pp ->sjis_icon_au1()), $au1i, "$src=>ucs4=>au1i (pp), $caller" );
  ok(escfull($str->sjis_icon_au2()), $au2i, "$src=>ucs4=>au2i (xs), $caller" );
  ok(escfull($pp ->sjis_icon_au2()), $au2i, "$src=>ucs4=>au2i (pp), $caller" );
}
