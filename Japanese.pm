package Unicode::Japanese;
# $Id: Japanese_stub.pm,v 1.21 2002/04/03 14:50:06 hio Exp $

use strict;
use vars qw($VERSION $PurePerl $xs_loaderror);
$VERSION = '0.08';

sub DESTROY
{
}

sub load_xs
{
  #print STDERR "load_xs\n";
  if( $PurePerl )
  {
    #print STDERR "PurePerl mode\n";
    $xs_loaderror = 'disabled';
    return;
  }
  
  my $use_xs;
  LoadXS:
  {
    
    #print STDERR "* * bootstrap...\n";
    eval q
    {
      use strict;
      require DynaLoader;
      use vars qw(@ISA);
      @ISA = qw(DynaLoader);
      local($SIG{__DIE__}) = 'DEFAULT';
      Unicode::Japanese->bootstrap($VERSION);
    };
    #print STDERR "* * try done.\n";
    #undef @ISA;
    if( $@ )
    {
      #print STDERR "failed.\n";
      #print STDERR "$@\n";
      $use_xs = 0;
      $xs_loaderror = $@;
      undef $@;
      last LoadXS;
    }
    #print STDERR "succeeded.\n";
    $use_xs = 1;
    eval q
    {
      #print STDERR "over riding _s2u,_u2s\n";
      do_memmap();
      #print STDERR "memmap done\n";
      END{ do_memunmap(); }
      #print STDERR "binding xsubs done.\n";
    };
    if( $@ )
    {
      #print STDERR "error on last part of load XS.\n";
      $xs_loaderror = $@;
      CORE::die($@);
    }

    #print STDERR "done.\n";
  }

  if( $@ )
  {
    $xs_loaderror = $@;
    CORE::die("Cannot Load Unicode::Japanese either XS nor PurePerl\n$@");
  }
  if( !$use_xs )
  {
    #print STDERR "no xs.\n";
    eval q
    {
      sub do_memmap($){}
      sub do_memunmap($){}
    };
  }
  $xs_loaderror = '' if( !defined($xs_loaderror) );
  #print STDERR "load_xs done.\n";
}

use vars qw($FH $TABLE $HEADLEN $PROGLEN);

sub gensym {
  package Unicode::Japanese::Symbol;
  no strict;
  $genpkg = "Unicode::Japanese::Symbol::";
  $genseq = 0;
  my $name = "GEN" . $genseq++;
  my $ref = \*{$genpkg . $name};
  delete $$genpkg{$name};
  $ref;
}

sub _init_table {
  
  if(!defined($HEADLEN))
    {
      $FH = gensym;
      
      my $file = "Unicode/Japanese.pm";
    OPEN:
      {
	foreach my $path (@INC)
	  {
	    my $mypath = $path;
	    $mypath =~ s#/$##;
	    if (-f "$mypath/$file")
	      {
		open($FH,"$mypath/$file")	|| CORE::die;
		binmode($FH);
		last OPEN;
	      }
	  }
	CORE::die "Can't find Japanese.pm in \@INC\n";
      }

      local($/) = "\n";
      my $line;
      while($line = <$FH>)
	{
	  last if($line =~ m/^__DATA__/);
	}
      $PROGLEN = tell($FH);
      
      read($FH, $HEADLEN, 4)
	or die "Can't read table. [$!]\n";
      $HEADLEN = unpack('N', $HEADLEN);
      read($FH, $TABLE, $HEADLEN)
	or die "Can't seek table. [$!]\n";
      $TABLE = eval $TABLE;
      if($@)
	{
	  die "Internal Error. [$@]\n";
	}
      if(!defined($TABLE))
	{
	  die "Internal Error.\n";
	}
      $HEADLEN += 4;

      # load xs.
      load_xs();
    }
}

sub _getFile {
  my $this = shift;

  my $file = shift;

#  print STDERR "_getFile($file, $TABLE->{$file}{offset}, $TABLE->{$file}{length})\n";
  seek($FH, $PROGLEN + $HEADLEN + $TABLE->{$file}{offset}, 0)
    or die "Can't seek $file. [$!]\n";
  
  my $data;
  read($FH, $data, $TABLE->{$file}{length})
    or die "Can't read $file. [$!]\n";
  
  $data;
}

sub new
{
  my $pkg = shift;
  my $this = {};

  bless $this, $pkg;
  $this->_init_table;
  
  if(defined($_[0]))
    {
      $this->set(@_);
    }

  $this;
}



use vars qw(%CHARCODE %ESC %RE);
use vars qw(@J2S @S2J @S2E @E2S @U2T %T2U %S2U %U2S);

%CHARCODE = (
	     UNDEF_EUC  =>     "\xa2\xae",
	     UNDEF_SJIS =>     "\x81\xac",
	     UNDEF_JIS  =>     "\xa2\xf7",
	     UNDEF_UNICODE  => "\x20\x20",
	 );

%ESC =  (
	 JIS_0208      => "\e\$B",
	 JIS_0212      => "\e\$(D",
	 ASC           => "\e\(B",
	 KANA          => "\e\(I",
	 E_JSKY_START  => "\e\$",
	 E_JSKY_END    => "\x0f",
	 );

%RE =
    (
     ASCII     => '[\x00-\x7f]',
     EUC_0212  => '\x8f[\xa1-\xfe][\xa1-\xfe]',
     EUC_C     => '[\xa1-\xfe][\xa1-\xfe]',
     EUC_KANA  => '\x8e[\xa1-\xdf]',
     JIS_0208  => '\e\$\@|\e\$B|\e&\@\e\$B',
     JIS_0212  => "\e" . '\$\(D',
     JIS_ASC   => "\e" . '\([BJ]',
     JIS_KANA  => "\e" . '\(I',
     SJIS_C    => '[\x81-\x9f\xe0-\xef][\x40-\x7e\x80-\xfc]',
     SJIS_KANA => '[\xa1-\xdf]',
     UTF8      => '[\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}',
     BOM2_BE    => '\xfe\xff',
     BOM2_LE    => '\xff\xfe',
     BOM4_BE    => '\x00\x00\xfe\xff',
     BOM4_LE    => '\xff\xfe\x00\x00',
     UTF32_BE   => '\x00[\x00-\x10][\x00-\xff]{2}',
     UTF32_LE   => '[\x00-\xff]{2}[\x00-\x10]\x00',
     E_IMODE    => '\xf8[\x9f-\xfc]|\xf9[\x40-\x49\x72-\x7e\x80-\xb0]',
     E_JSKY1    => '[EFG]',
     E_JSKY2    => '[\!-z]',
     E_DOTI     => '\xf0[\x40-\x7e\x80-\xfc]|\xf1[\x40-\x7e\x80-\xd6]|\xf2[\x40-\x7e\x80-\xab\xb0-\xd5\xdf-\xfc]|\xf3[\x40-\x7e\x80-\xfa]|\xf4[\x40-\x4f\x80\x84-\x8a\x8c-\x8e\x90\x94-\x96\x98-\x9c\xa0-\xa4\xa8-\xaf\xb4\xb5\xbc-\xbe\xc4\xc5\xc8\xcc]',
     E_JSKY_START => quotemeta($ESC{E_JSKY_START}),
     E_JSKY_END   => quotemeta($ESC{E_JSKY_END}),
     );

$RE{E_JSKY}     =  $RE{E_JSKY_START}
  . $RE{E_JSKY1} . $RE{E_JSKY2} . '+'
  . $RE{E_JSKY_END};

use vars qw($s2u_table $u2s_table);
use vars qw($ei2u $ed2u $ej2u $eu2i $eu2d $eu2j);

# encode/decode

use vars qw(%_h2zNum %_z2hNum %_h2zAlpha %_z2hAlpha %_h2zSym %_z2hSym %_h2zKanaK %_z2hKanaK %_h2zKanaD %_z2hKanaD %_hira2kata %_kata2hira);



AUTOLOAD
{
  use strict;
  use vars qw($AUTOLOAD);

  #print STDERR "AUTOLOAD... $AUTOLOAD\n";
  
  my $save = $@;
  my @BAK = @_;
  
  my $subname = $AUTOLOAD;
  $subname =~ s/^Unicode\:\:Japanese\:\://;

  #print "subs..\n",join("\n",keys %$TABLE,'');
  
  # check
  if(!defined($TABLE->{$subname}{offset}))
    {
      if (substr($AUTOLOAD,-9) eq '::DESTROY')
	{
	  {
	    no strict;
	    *$AUTOLOAD = sub {};
	  }
	  $@ = $save;
	  @_ = @BAK;
	  goto &$AUTOLOAD;
	}
      
      CORE::die "Undefined subroutine \&$AUTOLOAD called.\n";
    }
  if($TABLE->{$subname}{offset} == -1)
    {
      CORE::die "Double loaded \&$AUTOLOAD. It has some error.\n";
    }
  
  seek($FH, $PROGLEN + $HEADLEN + $TABLE->{$subname}{offset}, 0)
    or die "Can't seek $subname. [$!]\n";
  
  my $sub;
  read($FH, $sub, $TABLE->{$subname}{length})
    or die "Can't read $subname. [$!]\n";

  CORE::eval($sub);
  if ($@)
    {
      CORE::die $@;
    }
  $DB::sub = $AUTOLOAD;	# Now debugger know where we are.
  
  # evaled
  $TABLE->{$subname}{offset} = -1;

  $@ = $save;
  @_ = @BAK;
  goto &$AUTOLOAD;
}


1;

=head1 NAME

Unicode::Japanese - Japanese Character Encoding Handler

=head1 SYNOPSIS

use Unicode::Japanese;

# convert utf8 -> sjis

print Unicode::Japanese->new($str)->sjis;

# convert sijs -> utf8

print Unicode::Japanese->new($str,'sjis')->get;

# convert sjis (imode_EMOJI) -> utf8

print Unicode::Japanese->new($str,'sjis-imode')->get;

# convert ZENKAKU (utf8) -> HANKAKU (utf8)

print Unicode::Japanese->new($str)->z2h->get;

=head1 DESCRIPTION

Module for conversion among Japanese character encodings.

=head2 FEATURES

=over 2

=item *

The instance stores internal strings in UTF-8.

=item *

Supports both XS and Non-XS.
Use XS for high performance,
or No-XS for ease to use (only by copying Japanese.pm).

=item *

Supports conversion between ZENKAKU and HANKAKU.

=item *

Safely handles "EMOJI" of the mobile phones (DoCoMo i-mode, ASTEL dot-i
and J-PHONE J-Sky) by mapping them on Unicode Private Use Area.

=item *

Supports conversion of the same image of EMOJI
between different mobile phone's standard mutually.

=item *

Considers Shift_JIS(SJIS) as MS-CP932.
(Shift_JIS on MS-Windows (MS-SJIS/MS-CP932) differ from
generic Shift_JIS encodings.)

=item *

On converting Unicode to SJIS (EUC/JIS), those encodings that cannot
be converted to SJIS (except "EMOJI") are escaped in "&#xxxxx;" format.

=back

=head1 METHODS

=over 4

=item $s = Unicode::Japanese->new($str [, $icode [, $encode]])

Creates a new instance of Unicode::Japanese.

If arguments are specified, passes through to set method.

=item $s->set($str [, $icode [, $encode]])

=over 2

=item $str: string

=item $icode: character encodings, may be omitted (default = 'utf8')

=item $encode: ASCII encoding, may be omitted.

=back

Set a string in the instance.
If '$icode' is omitted, string is considerd as UTF-8.

To specify a encodings, choose from the following;
'jis', 'sjis', 'euc', 'utf8',
'ucs2', 'ucs4', 'utf16', 'utf16-ge', 'utf16-le',
'utf32', 'utf32-ge', 'utf32-le', 'ascii', 'binary',
'sjis-imode', 'sjis-doti', 'sjis-jsky'.

'&#xxxxx' will be converted to "EMOJI", when specified 'sjis-imode' or 'sjis-doti'.

For auto encoding detection, you MUST specify 'auto'
so as to call getcode() method automatically.

For ASCII encoding, only 'base64' may be specified.
With it, the string will be decoded before storing.

To decode binary, specify 'binary' as the encoding.

=item $str = $s->get

=over 2

=item $str: string (UTF-8)

=back

Gets a string with UTF-8.

=item $code = $s->getcode($str)

=over 2

=item $str: string

=item $code: character encoding name

=back

Detects the character encodings of I<$str>.

Notice: The code of the string in the instance is B<NOT> detected.

Character encodings are distinguished by the following algorism:

=over 4

=item 1

If BOM of UTF-32 is found, the encoding is utf32.

=item 2

If BOM of UTF-16 is found, the encoding is utf16.

=item 3

If it is in proper UTF-32BE, the encoding is utf32-be.

=item 4

If it is in proper UTF-32LE, the encoding is utf32-le.

=item 5

Without NON-ASCII characters, the encoding is ascii.
(control codes except escape sequences has been included in ASCII)

=item 6

If it includes ISO-2022-JP(JIS) escape sequences, the encoding is jis.

=item 7

If it includes "J-PHONE EMOJI", the encoding is sjis-sky.

=item 8

If it is in proper EUC, the encoding is euc.

=item 9

If it is in proper SJIS, the encoding is sjis.

=item 10

If it is in proper SJIS and "EMOJI" of i-mode, the encoding is sjis-imode.

=item 11

If it is in proper SJIS and "EMOJI" of dot-i,the encoding is sjis-doti.

=item 12

If it is in proper UTF-8, the encoding is utf8.

=item 13

If none above is true, the encoding is unknown.

=back

Regarding the algorism, pay attention to the following:

=over 2

=item *

UTF-8 is occasionally detected as SJIS.

=item *

Can NOT detect UCS2 automatically.

=item *

Can detect UTF-16 only when the string has BOM.

=item *

Can detect "EMOJI" when it is stored in binary, not in "&#xxxxx;"
format. (If only stored in "&#xxxxx;" format, getcode() will
return incorrect result. In that case, "EMOJI" will be crashed.)

=back

=item $str = $s->conv($ocode, $encode)

=over 2

=item $ocode: output character encoding (Choose from 'jis', 'sjis', 'euc', 'utf8', 'ucs2', 'ucs4', 'utf16', 'binary')

=item $encode: ASCII encoding, may be omitted.

=item $str: string

=back

Gets a string converted to I<$ocode>.

For ASCII encoding, only 'base64' may be specified. With it, the string
encoded in base64 will be returned.

=item $s->tag2bin

Replaces the substrings "&#xxxxx;" in the string with the binary entity
they mean.

=item $s->z2h

Converts ZENKAKU to HANKAKU.

=item $s->h2z

Converts HANKAKU to ZENKAKU.

=item $s->hira2kata

Converts HIRAGANA to KATAKANA.

=item $s->kata2hira

Converts KATAKANA to HIRAGANA.

=item $str = $s->jis

$str: string (JIS)

Gets the string converted to ISO-2022-JP(JIS).

=item $str = $s->euc

$str: string (EUC)

Gets the string converted to EUC.

=item $str = $s->utf8

$str: string (UTF-8)

Gets the string converted to UTF-8.

=item $str = $s->ucs2

$str: string (UCS2)

Gets the string converted to UCS2.

=item $str = $s->ucs4

$str: string (UCS4)

Gets the string converted to UCS4.

=item $str = $s->utf16

$str: string (UTF-16)

Gets the string converted to UTF-16(big-endian).
BOM is not added.

=item $str = $s->sjis

$str: string (SJIS)

Gets the string converted to Shift_JIS(MS-SJIS/MS-CP932).

=item $str = $s->sjis_imode

$str: string (SJIS/imode_EMOJI)

Gets the string converted to SJIS for i-mode.

=item $str = $s->sjis_doti

$str: string (SJIS/dot-i_EMOJI)

Gets the string converted to SJIS for dot-i.

=item $str = $s->sjis_sky

$str: string (SJIS/J-SKY_EMOJI)

Gets the string converted to SJIS for j-sky.

=item @str = $s->strcut($len)

=over 2

=item $len: number of characters

=item @str: strings

=back

Splits the string by length(I<$len>).

=item $len = $s->strlen

$len: `visual width' of the string

Gets the length of the string. This method has been offered to
substitute for perl build-in length(). ZENKAKU characters are
assumed to have lengths of 2, regardless of the coding being
SJIS or UTF-8.

=item $s->join_csv(@values);

@values: data array

Converts the array to a string in CSV format, then stores into the instance.
In the meantime, adds a newline("\n") at the end of string.

=item @values = $s->split_csv;

@values: data array

Splits the string, accounting it is in CSV format.
Each newline("\n") is removed before split.

=back


=head1 DESCRIPTION OF UNICODE MAPPING

=over 2

=item SJIS

Mapped as MS-CP932. Mapping table in the following URL is used.

ftp://ftp.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP932.TXT

If a character cannot be mapped to SJIS from Unicode,
it will be converted to &#xxxxx; format.

Also, any unmapped character will be converted into "?" when converting
to SJIS for mobile phones.

=item EUC/JIS

Converted to SJIS and then mapped to Unicode. Any non-SJIS character
in the string will not be mapped correctly.

=item DoCoMo i-mode

Portion of involving "EMOJI" in F800 - F9FF is maapped
 to U+0FF800 - U+0FF9FF.

=item ASTEL dot-i

Portion of involving "EMOJI" in F000 - F4FF is maapped
 to U+0FF000 - U+0FF4FF.

=item J-PHONE J-SKY

"J-SKY EMOJI" are mapped down as follows: "\e\$"(\x1b\x24) escape
sequences, the first byte, the second byte and "\x0f".
With sequential "EMOJI"s of identical first bytes,
it may be compressed by arranging only the second bytes.

4500 - 47FF is mapped to U+0FFB00 - U+0FFDFF, accounting the first
and the second bytes make one EMOJI character.

Unicode::Japanese will compress "J-SKY_EMOJI" automatically when
the first bytes of a sequence of "EMOJI" are identical.

=back


=head1 BUGS

=over 2

=item *

EUC, JIS strings cannot be converted correctly when they include
non-SJIS characters because they are converted to SJIS before
being converted to UTF-8.

=item *

Some characters of CP932 they not in standard Shift_JIS
 (ex; not in Joyo Kanji) will not be detected and converted. 

When string include such non-standard Shift_JIS,
they will not detected as SJIS.
Also, getcode() and all convert method will not work correctly.

=item *

When useing XS, character encoding detection of EUC-JP and
SJIS(included all EMOJI) strings when they include "\e" will
fail. Also, getcode() and all convert method will not work.

=item *

The Japanese.pm file will collapse if sent via ASCII mode of FTP,
as it has a trailing binary data.

=back

=head1 AUTHOR INFORMATION

Copyright 2001-2002
SANO Taku (SAWATARI Mikage) and YAMASHINA Hio.
All right resreved.

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

Bug reports and comments to: mikage@cpan.org.
Thank you.

=head1 CREDITS

Thanks very much to:

NAKAYAMA Nao

SUGIURA Tatsuki & Debian JP Project

=cut


__DATA__
  #{'_loadConvTable'=>{'length'=>17905,'offset'=>'0'},'euc'=>{'length'=>60,'offset'=>'18079'},'h2zNum'=>{'length'=>174,'offset'=>'17905'},'z2hKana'=>{'length'=>89,'offset'=>'18139'},'splitCsv'=>{'length'=>349,'offset'=>'18228'},'jcode/emoji/ej2u.dat'=>{'length'=>3072,'offset'=>'184795'},'strlen'=>{'length'=>360,'offset'=>'18577'},'join_csv'=>{'length'=>60,'offset'=>'18937'},'utf16'=>{'length'=>70,'offset'=>'18997'},'_utf16_utf8'=>{'length'=>769,'offset'=>'19067'},'_u2s'=>{'length'=>1491,'offset'=>'19836'},'_j2s2'=>{'length'=>382,'offset'=>'21327'},'z2hKanaD'=>{'length'=>498,'offset'=>'21709'},'_j2s3'=>{'length'=>337,'offset'=>'22207'},'joinCsv'=>{'length'=>413,'offset'=>'22544'},'jcode/emoji/ed2u.dat'=>{'length'=>5120,'offset'=>'179675'},'jcode/emoji/eu2d.dat'=>{'length'=>8192,'offset'=>'196059'},'_utf32be_ucs4'=>{'length'=>70,'offset'=>'22957'},'_s2e2'=>{'length'=>446,'offset'=>'23027'},'z2hKanaK'=>{'length'=>979,'offset'=>'23473'},'h2zKana'=>{'length'=>87,'offset'=>'24452'},'_ucs2_utf8'=>{'length'=>444,'offset'=>'24539'},'z2hAlpha'=>{'length'=>836,'offset'=>'24983'},'_utf32le_ucs4'=>{'length'=>178,'offset'=>'25819'},'_utf8_utf16'=>{'length'=>950,'offset'=>'25997'},'getcode'=>{'length'=>1582,'offset'=>'26947'},'_decodeBase64'=>{'length'=>609,'offset'=>'28529'},'sjis_doti'=>{'length'=>68,'offset'=>'29138'},'jcode/u2s.dat'=>{'length'=>85504,'offset'=>'55838'},'sjis_jsky'=>{'length'=>68,'offset'=>'29206'},'tag2bin'=>{'length'=>236,'offset'=>'29274'},'strcut'=>{'length'=>771,'offset'=>'29510'},'h2zKanaD'=>{'length'=>810,'offset'=>'30281'},'_utf8_ucs2'=>{'length'=>644,'offset'=>'31091'},'sjis_imode'=>{'length'=>69,'offset'=>'31735'},'_utf8_ucs4'=>{'length'=>1388,'offset'=>'31804'},'_u2sd'=>{'length'=>1563,'offset'=>'33192'},'get'=>{'length'=>48,'offset'=>'34755'},'utf8'=>{'length'=>49,'offset'=>'34803'},'hira2kata'=>{'length'=>1242,'offset'=>'34852'},'z2h'=>{'length'=>114,'offset'=>'36094'},'_encodeBase64'=>{'length'=>645,'offset'=>'36208'},'h2zKanaK'=>{'length'=>979,'offset'=>'36853'},'jcode/emoji/eu2j.dat'=>{'length'=>20480,'offset'=>'204251'},'_u2si'=>{'length'=>1563,'offset'=>'37832'},'_u2sj'=>{'length'=>1716,'offset'=>'39395'},'h2zAlpha'=>{'length'=>264,'offset'=>'41111'},'_s2e'=>{'length'=>185,'offset'=>'41375'},'_e2s2'=>{'length'=>535,'offset'=>'41560'},'_utf16le_utf16'=>{'length'=>179,'offset'=>'42095'},'_sj2u'=>{'length'=>1132,'offset'=>'42274'},'_s2j'=>{'length'=>154,'offset'=>'43406'},'_s2j2'=>{'length'=>370,'offset'=>'43560'},'_s2j3'=>{'length'=>355,'offset'=>'43930'},'conv'=>{'length'=>1109,'offset'=>'44285'},'_s2u'=>{'length'=>880,'offset'=>'45394'},'_j2s'=>{'length'=>177,'offset'=>'46274'},'h2z'=>{'length'=>114,'offset'=>'46451'},'ucs2'=>{'length'=>68,'offset'=>'46565'},'z2hSym'=>{'length'=>557,'offset'=>'46633'},'set'=>{'length'=>2300,'offset'=>'47190'},'ucs4'=>{'length'=>68,'offset'=>'49490'},'jcode/emoji/ei2u.dat'=>{'length'=>2048,'offset'=>'177627'},'z2hNum'=>{'length'=>284,'offset'=>'49558'},'_si2u'=>{'length'=>1218,'offset'=>'49842'},'_e2s'=>{'length'=>202,'offset'=>'51060'},'jis'=>{'length'=>60,'offset'=>'51262'},'_utf32_ucs4'=>{'length'=>312,'offset'=>'51322'},'jcode/s2u.dat'=>{'length'=>36285,'offset'=>'141342'},'kata2hira'=>{'length'=>1242,'offset'=>'51634'},'_ucs4_utf8'=>{'length'=>936,'offset'=>'52876'},'split_csv'=>{'length'=>62,'offset'=>'53812'},'_utf16_utf16'=>{'length'=>300,'offset'=>'53874'},'_sd2u'=>{'length'=>1217,'offset'=>'54174'},'h2zSym'=>{'length'=>314,'offset'=>'55524'},'_utf16be_utf16'=>{'length'=>71,'offset'=>'55453'},'sjis'=>{'length'=>62,'offset'=>'55391'},'jcode/emoji/eu2i.dat'=>{'length'=>8192,'offset'=>'187867'}}sub _loadConvTable {


%_h2zNum = (
		"0" => "\xef\xbc\x90", "1" => "\xef\xbc\x91", 
		"2" => "\xef\xbc\x92", "3" => "\xef\xbc\x93", 
		"4" => "\xef\xbc\x94", "5" => "\xef\xbc\x95", 
		"6" => "\xef\xbc\x96", "7" => "\xef\xbc\x97", 
		"8" => "\xef\xbc\x98", "9" => "\xef\xbc\x99", 
		
);



%_z2hNum = (
		"\xef\xbc\x90" => "0", "\xef\xbc\x91" => "1", 
		"\xef\xbc\x92" => "2", "\xef\xbc\x93" => "3", 
		"\xef\xbc\x94" => "4", "\xef\xbc\x95" => "5", 
		"\xef\xbc\x96" => "6", "\xef\xbc\x97" => "7", 
		"\xef\xbc\x98" => "8", "\xef\xbc\x99" => "9", 
		
);



%_h2zAlpha = (
		"A" => "\xef\xbc\xa1", "B" => "\xef\xbc\xa2", 
		"C" => "\xef\xbc\xa3", "D" => "\xef\xbc\xa4", 
		"E" => "\xef\xbc\xa5", "F" => "\xef\xbc\xa6", 
		"G" => "\xef\xbc\xa7", "H" => "\xef\xbc\xa8", 
		"I" => "\xef\xbc\xa9", "J" => "\xef\xbc\xaa", 
		"K" => "\xef\xbc\xab", "L" => "\xef\xbc\xac", 
		"M" => "\xef\xbc\xad", "N" => "\xef\xbc\xae", 
		"O" => "\xef\xbc\xaf", "P" => "\xef\xbc\xb0", 
		"Q" => "\xef\xbc\xb1", "R" => "\xef\xbc\xb2", 
		"S" => "\xef\xbc\xb3", "T" => "\xef\xbc\xb4", 
		"U" => "\xef\xbc\xb5", "V" => "\xef\xbc\xb6", 
		"W" => "\xef\xbc\xb7", "X" => "\xef\xbc\xb8", 
		"Y" => "\xef\xbc\xb9", "Z" => "\xef\xbc\xba", 
		"a" => "\xef\xbd\x81", "b" => "\xef\xbd\x82", 
		"c" => "\xef\xbd\x83", "d" => "\xef\xbd\x84", 
		"e" => "\xef\xbd\x85", "f" => "\xef\xbd\x86", 
		"g" => "\xef\xbd\x87", "h" => "\xef\xbd\x88", 
		"i" => "\xef\xbd\x89", "j" => "\xef\xbd\x8a", 
		"k" => "\xef\xbd\x8b", "l" => "\xef\xbd\x8c", 
		"m" => "\xef\xbd\x8d", "n" => "\xef\xbd\x8e", 
		"o" => "\xef\xbd\x8f", "p" => "\xef\xbd\x90", 
		"q" => "\xef\xbd\x91", "r" => "\xef\xbd\x92", 
		"s" => "\xef\xbd\x93", "t" => "\xef\xbd\x94", 
		"u" => "\xef\xbd\x95", "v" => "\xef\xbd\x96", 
		"w" => "\xef\xbd\x97", "x" => "\xef\xbd\x98", 
		"y" => "\xef\xbd\x99", "z" => "\xef\xbd\x9a", 
		
);



%_z2hAlpha = (
		"\xef\xbc\xa1" => "A", "\xef\xbc\xa2" => "B", 
		"\xef\xbc\xa3" => "C", "\xef\xbc\xa4" => "D", 
		"\xef\xbc\xa5" => "E", "\xef\xbc\xa6" => "F", 
		"\xef\xbc\xa7" => "G", "\xef\xbc\xa8" => "H", 
		"\xef\xbc\xa9" => "I", "\xef\xbc\xaa" => "J", 
		"\xef\xbc\xab" => "K", "\xef\xbc\xac" => "L", 
		"\xef\xbc\xad" => "M", "\xef\xbc\xae" => "N", 
		"\xef\xbc\xaf" => "O", "\xef\xbc\xb0" => "P", 
		"\xef\xbc\xb1" => "Q", "\xef\xbc\xb2" => "R", 
		"\xef\xbc\xb3" => "S", "\xef\xbc\xb4" => "T", 
		"\xef\xbc\xb5" => "U", "\xef\xbc\xb6" => "V", 
		"\xef\xbc\xb7" => "W", "\xef\xbc\xb8" => "X", 
		"\xef\xbc\xb9" => "Y", "\xef\xbc\xba" => "Z", 
		"\xef\xbd\x81" => "a", "\xef\xbd\x82" => "b", 
		"\xef\xbd\x83" => "c", "\xef\xbd\x84" => "d", 
		"\xef\xbd\x85" => "e", "\xef\xbd\x86" => "f", 
		"\xef\xbd\x87" => "g", "\xef\xbd\x88" => "h", 
		"\xef\xbd\x89" => "i", "\xef\xbd\x8a" => "j", 
		"\xef\xbd\x8b" => "k", "\xef\xbd\x8c" => "l", 
		"\xef\xbd\x8d" => "m", "\xef\xbd\x8e" => "n", 
		"\xef\xbd\x8f" => "o", "\xef\xbd\x90" => "p", 
		"\xef\xbd\x91" => "q", "\xef\xbd\x92" => "r", 
		"\xef\xbd\x93" => "s", "\xef\xbd\x94" => "t", 
		"\xef\xbd\x95" => "u", "\xef\xbd\x96" => "v", 
		"\xef\xbd\x97" => "w", "\xef\xbd\x98" => "x", 
		"\xef\xbd\x99" => "y", "\xef\xbd\x9a" => "z", 
		
);



%_h2zSym = (
		"\x20" => "\xe3\x80\x80", "\x21" => "\xef\xbc\x81", 
		"\x22" => "\xe2\x80\x9d", "\x23" => "\xef\xbc\x83", 
		"\x24" => "\xef\xbc\x84", "\x25" => "\xef\xbc\x85", 
		"\x26" => "\xef\xbc\x86", "\x27" => "\xef\xbf\xa5", 
		"\x28" => "\xef\xbc\x88", "\x29" => "\xef\xbc\x89", 
		"\x2a" => "\xef\xbc\x8a", "\x2b" => "\xef\xbc\x8b", 
		"\x2c" => "\xef\xbc\x8c", "\x2d" => "\xe2\x88\x92", 
		"\x2e" => "\xef\xbc\x8e", "\x2f" => "\xef\xbc\x8f", 
		"\x3a" => "\xef\xbc\x9a", "\x3b" => "\xef\xbc\x9b", 
		"\x3c" => "\xef\xbc\x9c", "\x3d" => "\xef\xbc\x9d", 
		"\x3e" => "\xef\xbc\x9e", "\x3f" => "\xef\xbc\x9f", 
		"\x40" => "\xef\xbc\xa0", "\x5b" => "\xef\xbc\xbb", 
		"\x5c" => "\xef\xbf\xa5", "\x5d" => "\xef\xbc\xbd", 
		"\x5e" => "\xef\xbc\xbe", "\x60" => "\xef\xbd\x80", 
		"\x7b" => "\xef\xbd\x9b", "\x7c" => "\xef\xbd\x9c", 
		"\x7d" => "\xef\xbd\x9d", "\x7e" => "\xe3\x80\x9c", 
		
);



%_z2hSym = (
		"\xe3\x80\x80" => "\x20", "\xef\xbc\x8c" => "\x2c", 
		"\xef\xbc\x8e" => "\x2e", "\xef\xbc\x9a" => "\x3a", 
		"\xef\xbc\x9b" => "\x3b", "\xef\xbc\x9f" => "\x3f", 
		"\xef\xbc\x81" => "\x21", "\xef\xbd\x80" => "\x60", 
		"\xef\xbc\xbe" => "\x5e", "\xef\xbc\x8f" => "\x2f", 
		"\xe3\x80\x9c" => "\x7e", "\xef\xbd\x9c" => "\x7c", 
		"\xe2\x80\x9d" => "\x22", "\xef\xbc\x88" => "\x28", 
		"\xef\xbc\x89" => "\x29", "\xef\xbc\xbb" => "\x5b", 
		"\xef\xbc\xbd" => "\x5d", "\xef\xbd\x9b" => "\x7b", 
		"\xef\xbd\x9d" => "\x7d", "\xef\xbc\x8b" => "\x2b", 
		"\xe2\x88\x92" => "\x2d", "\xef\xbc\x9d" => "\x3d", 
		"\xef\xbc\x9c" => "\x3c", "\xef\xbc\x9e" => "\x3e", 
		"\xef\xbf\xa5" => "\x27", "\xef\xbc\x84" => "\x24", 
		"\xef\xbc\x85" => "\x25", "\xef\xbc\x83" => "\x23", 
		"\xef\xbc\x86" => "\x26", "\xef\xbc\x8a" => "\x2a", 
		"\xef\xbc\xa0" => "\x40", 
);



%_h2zKanaK = (
		"\xef\xbd\xa1" => "\xe3\x80\x82", "\xef\xbd\xa2" => "\xe3\x80\x8c", 
		"\xef\xbd\xa3" => "\xe3\x80\x8d", "\xef\xbd\xa4" => "\xe3\x80\x81", 
		"\xef\xbd\xa5" => "\xe3\x83\xbb", "\xef\xbd\xa6" => "\xe3\x83\xb2", 
		"\xef\xbd\xa7" => "\xe3\x82\xa1", "\xef\xbd\xa8" => "\xe3\x82\xa3", 
		"\xef\xbd\xa9" => "\xe3\x82\xa5", "\xef\xbd\xaa" => "\xe3\x82\xa7", 
		"\xef\xbd\xab" => "\xe3\x82\xa9", "\xef\xbd\xac" => "\xe3\x83\xa3", 
		"\xef\xbd\xad" => "\xe3\x83\xa5", "\xef\xbd\xae" => "\xe3\x83\xa7", 
		"\xef\xbd\xaf" => "\xe3\x83\x83", "\xef\xbd\xb0" => "\xe3\x83\xbc", 
		"\xef\xbd\xb1" => "\xe3\x82\xa2", "\xef\xbd\xb2" => "\xe3\x82\xa4", 
		"\xef\xbd\xb3" => "\xe3\x82\xa6", "\xef\xbd\xb4" => "\xe3\x82\xa8", 
		"\xef\xbd\xb5" => "\xe3\x82\xaa", "\xef\xbd\xb6" => "\xe3\x82\xab", 
		"\xef\xbd\xb7" => "\xe3\x82\xad", "\xef\xbd\xb8" => "\xe3\x82\xaf", 
		"\xef\xbd\xb9" => "\xe3\x82\xb1", "\xef\xbd\xba" => "\xe3\x82\xb3", 
		"\xef\xbd\xbb" => "\xe3\x82\xb5", "\xef\xbd\xbc" => "\xe3\x82\xb7", 
		"\xef\xbd\xbd" => "\xe3\x82\xb9", "\xef\xbd\xbe" => "\xe3\x82\xbb", 
		"\xef\xbd\xbf" => "\xe3\x82\xbd", "\xef\xbe\x80" => "\xe3\x82\xbf", 
		"\xef\xbe\x81" => "\xe3\x83\x81", "\xef\xbe\x82" => "\xe3\x83\x84", 
		"\xef\xbe\x83" => "\xe3\x83\x86", "\xef\xbe\x84" => "\xe3\x83\x88", 
		"\xef\xbe\x85" => "\xe3\x83\x8a", "\xef\xbe\x86" => "\xe3\x83\x8b", 
		"\xef\xbe\x87" => "\xe3\x83\x8c", "\xef\xbe\x88" => "\xe3\x83\x8d", 
		"\xef\xbe\x89" => "\xe3\x83\x8e", "\xef\xbe\x8a" => "\xe3\x83\x8f", 
		"\xef\xbe\x8b" => "\xe3\x83\x92", "\xef\xbe\x8c" => "\xe3\x83\x95", 
		"\xef\xbe\x8d" => "\xe3\x83\x98", "\xef\xbe\x8e" => "\xe3\x83\x9b", 
		"\xef\xbe\x8f" => "\xe3\x83\x9e", "\xef\xbe\x90" => "\xe3\x83\x9f", 
		"\xef\xbe\x91" => "\xe3\x83\xa0", "\xef\xbe\x92" => "\xe3\x83\xa1", 
		"\xef\xbe\x93" => "\xe3\x83\xa2", "\xef\xbe\x94" => "\xe3\x83\xa4", 
		"\xef\xbe\x95" => "\xe3\x83\xa6", "\xef\xbe\x96" => "\xe3\x83\xa8", 
		"\xef\xbe\x97" => "\xe3\x83\xa9", "\xef\xbe\x98" => "\xe3\x83\xaa", 
		"\xef\xbe\x99" => "\xe3\x83\xab", "\xef\xbe\x9a" => "\xe3\x83\xac", 
		"\xef\xbe\x9b" => "\xe3\x83\xad", "\xef\xbe\x9c" => "\xe3\x83\xaf", 
		"\xef\xbe\x9d" => "\xe3\x83\xb3", "\xef\xbe\x9e" => "\xe3\x82\x9b", 
		"\xef\xbe\x9f" => "\xe3\x82\x9c", 
);



%_z2hKanaK = (
		"\xe3\x80\x81" => "\xef\xbd\xa4", "\xe3\x80\x82" => "\xef\xbd\xa1", 
		"\xe3\x83\xbb" => "\xef\xbd\xa5", "\xe3\x82\x9b" => "\xef\xbe\x9e", 
		"\xe3\x82\x9c" => "\xef\xbe\x9f", "\xe3\x83\xbc" => "\xef\xbd\xb0", 
		"\xe3\x80\x8c" => "\xef\xbd\xa2", "\xe3\x80\x8d" => "\xef\xbd\xa3", 
		"\xe3\x82\xa1" => "\xef\xbd\xa7", "\xe3\x82\xa2" => "\xef\xbd\xb1", 
		"\xe3\x82\xa3" => "\xef\xbd\xa8", "\xe3\x82\xa4" => "\xef\xbd\xb2", 
		"\xe3\x82\xa5" => "\xef\xbd\xa9", "\xe3\x82\xa6" => "\xef\xbd\xb3", 
		"\xe3\x82\xa7" => "\xef\xbd\xaa", "\xe3\x82\xa8" => "\xef\xbd\xb4", 
		"\xe3\x82\xa9" => "\xef\xbd\xab", "\xe3\x82\xaa" => "\xef\xbd\xb5", 
		"\xe3\x82\xab" => "\xef\xbd\xb6", "\xe3\x82\xad" => "\xef\xbd\xb7", 
		"\xe3\x82\xaf" => "\xef\xbd\xb8", "\xe3\x82\xb1" => "\xef\xbd\xb9", 
		"\xe3\x82\xb3" => "\xef\xbd\xba", "\xe3\x82\xb5" => "\xef\xbd\xbb", 
		"\xe3\x82\xb7" => "\xef\xbd\xbc", "\xe3\x82\xb9" => "\xef\xbd\xbd", 
		"\xe3\x82\xbb" => "\xef\xbd\xbe", "\xe3\x82\xbd" => "\xef\xbd\xbf", 
		"\xe3\x82\xbf" => "\xef\xbe\x80", "\xe3\x83\x81" => "\xef\xbe\x81", 
		"\xe3\x83\x83" => "\xef\xbd\xaf", "\xe3\x83\x84" => "\xef\xbe\x82", 
		"\xe3\x83\x86" => "\xef\xbe\x83", "\xe3\x83\x88" => "\xef\xbe\x84", 
		"\xe3\x83\x8a" => "\xef\xbe\x85", "\xe3\x83\x8b" => "\xef\xbe\x86", 
		"\xe3\x83\x8c" => "\xef\xbe\x87", "\xe3\x83\x8d" => "\xef\xbe\x88", 
		"\xe3\x83\x8e" => "\xef\xbe\x89", "\xe3\x83\x8f" => "\xef\xbe\x8a", 
		"\xe3\x83\x92" => "\xef\xbe\x8b", "\xe3\x83\x95" => "\xef\xbe\x8c", 
		"\xe3\x83\x98" => "\xef\xbe\x8d", "\xe3\x83\x9b" => "\xef\xbe\x8e", 
		"\xe3\x83\x9e" => "\xef\xbe\x8f", "\xe3\x83\x9f" => "\xef\xbe\x90", 
		"\xe3\x83\xa0" => "\xef\xbe\x91", "\xe3\x83\xa1" => "\xef\xbe\x92", 
		"\xe3\x83\xa2" => "\xef\xbe\x93", "\xe3\x83\xa3" => "\xef\xbd\xac", 
		"\xe3\x83\xa4" => "\xef\xbe\x94", "\xe3\x83\xa5" => "\xef\xbd\xad", 
		"\xe3\x83\xa6" => "\xef\xbe\x95", "\xe3\x83\xa7" => "\xef\xbd\xae", 
		"\xe3\x83\xa8" => "\xef\xbe\x96", "\xe3\x83\xa9" => "\xef\xbe\x97", 
		"\xe3\x83\xaa" => "\xef\xbe\x98", "\xe3\x83\xab" => "\xef\xbe\x99", 
		"\xe3\x83\xac" => "\xef\xbe\x9a", "\xe3\x83\xad" => "\xef\xbe\x9b", 
		"\xe3\x83\xaf" => "\xef\xbe\x9c", "\xe3\x83\xb2" => "\xef\xbd\xa6", 
		"\xe3\x83\xb3" => "\xef\xbe\x9d", 
);



%_h2zKanaD = (
		"\xef\xbd\xb3\xef\xbe\x9e" => "\xe3\x83\xb4", "\xef\xbd\xb6\xef\xbe\x9e" => "\xe3\x82\xac", 
		"\xef\xbd\xb7\xef\xbe\x9e" => "\xe3\x82\xae", "\xef\xbd\xb8\xef\xbe\x9e" => "\xe3\x82\xb0", 
		"\xef\xbd\xb9\xef\xbe\x9e" => "\xe3\x82\xb2", "\xef\xbd\xba\xef\xbe\x9e" => "\xe3\x82\xb4", 
		"\xef\xbd\xbb\xef\xbe\x9e" => "\xe3\x82\xb6", "\xef\xbd\xbc\xef\xbe\x9e" => "\xe3\x82\xb8", 
		"\xef\xbd\xbd\xef\xbe\x9e" => "\xe3\x82\xba", "\xef\xbd\xbe\xef\xbe\x9e" => "\xe3\x82\xbc", 
		"\xef\xbd\xbf\xef\xbe\x9e" => "\xe3\x82\xbe", "\xef\xbe\x80\xef\xbe\x9e" => "\xe3\x83\x80", 
		"\xef\xbe\x81\xef\xbe\x9e" => "\xe3\x83\x82", "\xef\xbe\x82\xef\xbe\x9e" => "\xe3\x83\x85", 
		"\xef\xbe\x83\xef\xbe\x9e" => "\xe3\x83\x87", "\xef\xbe\x84\xef\xbe\x9e" => "\xe3\x83\x89", 
		"\xef\xbe\x8a\xef\xbe\x9e" => "\xe3\x83\x90", "\xef\xbe\x8a\xef\xbe\x9f" => "\xe3\x83\x91", 
		"\xef\xbe\x8b\xef\xbe\x9e" => "\xe3\x83\x93", "\xef\xbe\x8b\xef\xbe\x9f" => "\xe3\x83\x94", 
		"\xef\xbe\x8c\xef\xbe\x9e" => "\xe3\x83\x96", "\xef\xbe\x8c\xef\xbe\x9f" => "\xe3\x83\x97", 
		"\xef\xbe\x8d\xef\xbe\x9e" => "\xe3\x83\x99", "\xef\xbe\x8d\xef\xbe\x9f" => "\xe3\x83\x9a", 
		"\xef\xbe\x8e\xef\xbe\x9e" => "\xe3\x83\x9c", "\xef\xbe\x8e\xef\xbe\x9f" => "\xe3\x83\x9d", 
		
);



%_z2hKanaD = (
		"\xe3\x82\xac" => "\xef\xbd\xb6\xef\xbe\x9e", "\xe3\x82\xae" => "\xef\xbd\xb7\xef\xbe\x9e", 
		"\xe3\x82\xb0" => "\xef\xbd\xb8\xef\xbe\x9e", "\xe3\x82\xb2" => "\xef\xbd\xb9\xef\xbe\x9e", 
		"\xe3\x82\xb4" => "\xef\xbd\xba\xef\xbe\x9e", "\xe3\x82\xb6" => "\xef\xbd\xbb\xef\xbe\x9e", 
		"\xe3\x82\xb8" => "\xef\xbd\xbc\xef\xbe\x9e", "\xe3\x82\xba" => "\xef\xbd\xbd\xef\xbe\x9e", 
		"\xe3\x82\xbc" => "\xef\xbd\xbe\xef\xbe\x9e", "\xe3\x82\xbe" => "\xef\xbd\xbf\xef\xbe\x9e", 
		"\xe3\x83\x80" => "\xef\xbe\x80\xef\xbe\x9e", "\xe3\x83\x82" => "\xef\xbe\x81\xef\xbe\x9e", 
		"\xe3\x83\x85" => "\xef\xbe\x82\xef\xbe\x9e", "\xe3\x83\x87" => "\xef\xbe\x83\xef\xbe\x9e", 
		"\xe3\x83\x89" => "\xef\xbe\x84\xef\xbe\x9e", "\xe3\x83\x90" => "\xef\xbe\x8a\xef\xbe\x9e", 
		"\xe3\x83\x91" => "\xef\xbe\x8a\xef\xbe\x9f", "\xe3\x83\x93" => "\xef\xbe\x8b\xef\xbe\x9e", 
		"\xe3\x83\x94" => "\xef\xbe\x8b\xef\xbe\x9f", "\xe3\x83\x96" => "\xef\xbe\x8c\xef\xbe\x9e", 
		"\xe3\x83\x97" => "\xef\xbe\x8c\xef\xbe\x9f", "\xe3\x83\x99" => "\xef\xbe\x8d\xef\xbe\x9e", 
		"\xe3\x83\x9a" => "\xef\xbe\x8d\xef\xbe\x9f", "\xe3\x83\x9c" => "\xef\xbe\x8e\xef\xbe\x9e", 
		"\xe3\x83\x9d" => "\xef\xbe\x8e\xef\xbe\x9f", "\xe3\x83\xb4" => "\xef\xbd\xb3\xef\xbe\x9e", 
		
);



%_hira2kata = (
		"\xe3\x81\x81" => "\xe3\x82\xa1", "\xe3\x81\x82" => "\xe3\x82\xa2", 
		"\xe3\x81\x83" => "\xe3\x82\xa3", "\xe3\x81\x84" => "\xe3\x82\xa4", 
		"\xe3\x81\x85" => "\xe3\x82\xa5", "\xe3\x81\x86" => "\xe3\x82\xa6", 
		"\xe3\x81\x87" => "\xe3\x82\xa7", "\xe3\x81\x88" => "\xe3\x82\xa8", 
		"\xe3\x81\x89" => "\xe3\x82\xa9", "\xe3\x81\x8a" => "\xe3\x82\xaa", 
		"\xe3\x81\x8b" => "\xe3\x82\xab", "\xe3\x81\x8c" => "\xe3\x82\xac", 
		"\xe3\x81\x8d" => "\xe3\x82\xad", "\xe3\x81\x8e" => "\xe3\x82\xae", 
		"\xe3\x81\x8f" => "\xe3\x82\xaf", "\xe3\x81\x90" => "\xe3\x82\xb0", 
		"\xe3\x81\x91" => "\xe3\x82\xb1", "\xe3\x81\x92" => "\xe3\x82\xb2", 
		"\xe3\x81\x93" => "\xe3\x82\xb3", "\xe3\x81\x94" => "\xe3\x82\xb4", 
		"\xe3\x81\x95" => "\xe3\x82\xb5", "\xe3\x81\x96" => "\xe3\x82\xb6", 
		"\xe3\x81\x97" => "\xe3\x82\xb7", "\xe3\x81\x98" => "\xe3\x82\xb8", 
		"\xe3\x81\x99" => "\xe3\x82\xb9", "\xe3\x81\x9a" => "\xe3\x82\xba", 
		"\xe3\x81\x9b" => "\xe3\x82\xbb", "\xe3\x81\x9c" => "\xe3\x82\xbc", 
		"\xe3\x81\x9d" => "\xe3\x82\xbd", "\xe3\x81\x9e" => "\xe3\x82\xbe", 
		"\xe3\x81\x9f" => "\xe3\x82\xbf", "\xe3\x81\xa0" => "\xe3\x83\x80", 
		"\xe3\x81\xa1" => "\xe3\x83\x81", "\xe3\x81\xa2" => "\xe3\x83\x82", 
		"\xe3\x81\xa3" => "\xe3\x83\x83", "\xe3\x81\xa4" => "\xe3\x83\x84", 
		"\xe3\x81\xa5" => "\xe3\x83\x85", "\xe3\x81\xa6" => "\xe3\x83\x86", 
		"\xe3\x81\xa7" => "\xe3\x83\x87", "\xe3\x81\xa8" => "\xe3\x83\x88", 
		"\xe3\x81\xa9" => "\xe3\x83\x89", "\xe3\x81\xaa" => "\xe3\x83\x8a", 
		"\xe3\x81\xab" => "\xe3\x83\x8b", "\xe3\x81\xac" => "\xe3\x83\x8c", 
		"\xe3\x81\xad" => "\xe3\x83\x8d", "\xe3\x81\xae" => "\xe3\x83\x8e", 
		"\xe3\x81\xaf" => "\xe3\x83\x8f", "\xe3\x81\xb0" => "\xe3\x83\x90", 
		"\xe3\x81\xb1" => "\xe3\x83\x91", "\xe3\x81\xb2" => "\xe3\x83\x92", 
		"\xe3\x81\xb3" => "\xe3\x83\x93", "\xe3\x81\xb4" => "\xe3\x83\x94", 
		"\xe3\x81\xb5" => "\xe3\x83\x95", "\xe3\x81\xb6" => "\xe3\x83\x96", 
		"\xe3\x81\xb7" => "\xe3\x83\x97", "\xe3\x81\xb8" => "\xe3\x83\x98", 
		"\xe3\x81\xb9" => "\xe3\x83\x99", "\xe3\x81\xba" => "\xe3\x83\x9a", 
		"\xe3\x81\xbb" => "\xe3\x83\x9b", "\xe3\x81\xbc" => "\xe3\x83\x9c", 
		"\xe3\x81\xbd" => "\xe3\x83\x9d", "\xe3\x81\xbe" => "\xe3\x83\x9e", 
		"\xe3\x81\xbf" => "\xe3\x83\x9f", "\xe3\x82\x80" => "\xe3\x83\xa0", 
		"\xe3\x82\x81" => "\xe3\x83\xa1", "\xe3\x82\x82" => "\xe3\x83\xa2", 
		"\xe3\x82\x83" => "\xe3\x83\xa3", "\xe3\x82\x84" => "\xe3\x83\xa4", 
		"\xe3\x82\x85" => "\xe3\x83\xa5", "\xe3\x82\x86" => "\xe3\x83\xa6", 
		"\xe3\x82\x87" => "\xe3\x83\xa7", "\xe3\x82\x88" => "\xe3\x83\xa8", 
		"\xe3\x82\x89" => "\xe3\x83\xa9", "\xe3\x82\x8a" => "\xe3\x83\xaa", 
		"\xe3\x82\x8b" => "\xe3\x83\xab", "\xe3\x82\x8c" => "\xe3\x83\xac", 
		"\xe3\x82\x8d" => "\xe3\x83\xad", "\xe3\x82\x8e" => "\xe3\x83\xae", 
		"\xe3\x82\x8f" => "\xe3\x83\xaf", "\xe3\x82\x90" => "\xe3\x83\xb0", 
		"\xe3\x82\x91" => "\xe3\x83\xb1", "\xe3\x82\x92" => "\xe3\x83\xb2", 
		"\xe3\x82\x93" => "\xe3\x83\xb3", 
);



%_kata2hira = (
		"\xe3\x82\xa1" => "\xe3\x81\x81", "\xe3\x82\xa2" => "\xe3\x81\x82", 
		"\xe3\x82\xa3" => "\xe3\x81\x83", "\xe3\x82\xa4" => "\xe3\x81\x84", 
		"\xe3\x82\xa5" => "\xe3\x81\x85", "\xe3\x82\xa6" => "\xe3\x81\x86", 
		"\xe3\x82\xa7" => "\xe3\x81\x87", "\xe3\x82\xa8" => "\xe3\x81\x88", 
		"\xe3\x82\xa9" => "\xe3\x81\x89", "\xe3\x82\xaa" => "\xe3\x81\x8a", 
		"\xe3\x82\xab" => "\xe3\x81\x8b", "\xe3\x82\xac" => "\xe3\x81\x8c", 
		"\xe3\x82\xad" => "\xe3\x81\x8d", "\xe3\x82\xae" => "\xe3\x81\x8e", 
		"\xe3\x82\xaf" => "\xe3\x81\x8f", "\xe3\x82\xb0" => "\xe3\x81\x90", 
		"\xe3\x82\xb1" => "\xe3\x81\x91", "\xe3\x82\xb2" => "\xe3\x81\x92", 
		"\xe3\x82\xb3" => "\xe3\x81\x93", "\xe3\x82\xb4" => "\xe3\x81\x94", 
		"\xe3\x82\xb5" => "\xe3\x81\x95", "\xe3\x82\xb6" => "\xe3\x81\x96", 
		"\xe3\x82\xb7" => "\xe3\x81\x97", "\xe3\x82\xb8" => "\xe3\x81\x98", 
		"\xe3\x82\xb9" => "\xe3\x81\x99", "\xe3\x82\xba" => "\xe3\x81\x9a", 
		"\xe3\x82\xbb" => "\xe3\x81\x9b", "\xe3\x82\xbc" => "\xe3\x81\x9c", 
		"\xe3\x82\xbd" => "\xe3\x81\x9d", "\xe3\x82\xbe" => "\xe3\x81\x9e", 
		"\xe3\x82\xbf" => "\xe3\x81\x9f", "\xe3\x83\x80" => "\xe3\x81\xa0", 
		"\xe3\x83\x81" => "\xe3\x81\xa1", "\xe3\x83\x82" => "\xe3\x81\xa2", 
		"\xe3\x83\x83" => "\xe3\x81\xa3", "\xe3\x83\x84" => "\xe3\x81\xa4", 
		"\xe3\x83\x85" => "\xe3\x81\xa5", "\xe3\x83\x86" => "\xe3\x81\xa6", 
		"\xe3\x83\x87" => "\xe3\x81\xa7", "\xe3\x83\x88" => "\xe3\x81\xa8", 
		"\xe3\x83\x89" => "\xe3\x81\xa9", "\xe3\x83\x8a" => "\xe3\x81\xaa", 
		"\xe3\x83\x8b" => "\xe3\x81\xab", "\xe3\x83\x8c" => "\xe3\x81\xac", 
		"\xe3\x83\x8d" => "\xe3\x81\xad", "\xe3\x83\x8e" => "\xe3\x81\xae", 
		"\xe3\x83\x8f" => "\xe3\x81\xaf", "\xe3\x83\x90" => "\xe3\x81\xb0", 
		"\xe3\x83\x91" => "\xe3\x81\xb1", "\xe3\x83\x92" => "\xe3\x81\xb2", 
		"\xe3\x83\x93" => "\xe3\x81\xb3", "\xe3\x83\x94" => "\xe3\x81\xb4", 
		"\xe3\x83\x95" => "\xe3\x81\xb5", "\xe3\x83\x96" => "\xe3\x81\xb6", 
		"\xe3\x83\x97" => "\xe3\x81\xb7", "\xe3\x83\x98" => "\xe3\x81\xb8", 
		"\xe3\x83\x99" => "\xe3\x81\xb9", "\xe3\x83\x9a" => "\xe3\x81\xba", 
		"\xe3\x83\x9b" => "\xe3\x81\xbb", "\xe3\x83\x9c" => "\xe3\x81\xbc", 
		"\xe3\x83\x9d" => "\xe3\x81\xbd", "\xe3\x83\x9e" => "\xe3\x81\xbe", 
		"\xe3\x83\x9f" => "\xe3\x81\xbf", "\xe3\x83\xa0" => "\xe3\x82\x80", 
		"\xe3\x83\xa1" => "\xe3\x82\x81", "\xe3\x83\xa2" => "\xe3\x82\x82", 
		"\xe3\x83\xa3" => "\xe3\x82\x83", "\xe3\x83\xa4" => "\xe3\x82\x84", 
		"\xe3\x83\xa5" => "\xe3\x82\x85", "\xe3\x83\xa6" => "\xe3\x82\x86", 
		"\xe3\x83\xa7" => "\xe3\x82\x87", "\xe3\x83\xa8" => "\xe3\x82\x88", 
		"\xe3\x83\xa9" => "\xe3\x82\x89", "\xe3\x83\xaa" => "\xe3\x82\x8a", 
		"\xe3\x83\xab" => "\xe3\x82\x8b", "\xe3\x83\xac" => "\xe3\x82\x8c", 
		"\xe3\x83\xad" => "\xe3\x82\x8d", "\xe3\x83\xae" => "\xe3\x82\x8e", 
		"\xe3\x83\xaf" => "\xe3\x82\x8f", "\xe3\x83\xb0" => "\xe3\x82\x90", 
		"\xe3\x83\xb1" => "\xe3\x82\x91", "\xe3\x83\xb2" => "\xe3\x82\x92", 
		"\xe3\x83\xb3" => "\xe3\x82\x93", 
);


}
sub h2zNum {
  my $this = shift;

  if(!defined(%_h2zNum))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(0|1|2|3|4|5|6|7|8|9)/$_h2zNum{$1}/eg;
  
  $this;
}
sub euc
{
  my $this = shift;
  $this->_s2e($this->sjis);
}
sub z2hKana
{
  my $this = shift;
  
  $this->z2hKanaD;
  $this->z2hKanaK;
  
  $this;
}
sub splitCsv {
  my $this = shift;
  my $text = $this->{str};
  my @field;
  
  chomp($text);

  while ($text =~ m/"([^"\\]*(?:(?:\\.|\"\")[^"\\]*)*)",?|([^,]+),?|,/g) {
    my $field = defined($1) ? $1 : (defined($2) ? $2 : '');
    $field =~ s/["\\]"/"/g;
    push(@field, $field);
  }
  push(@field, '')        if($text =~ m/,$/);

  \@field;

}
sub strlen {
  my $this = shift;
  
  my $ch_re = '[\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}';
  my $length = 0;

  foreach my $c(split(/($ch_re)/,$this->{str})) {
    next if(length($c) == 0);
    $length += ((length($c) >= 3) ? 2 : 1);
  }

  return $length;
}
sub join_csv {
  my $this = shift;

  $this->joinCsv(@_);
}
sub utf16
{
  my $this = shift;
  $this->_utf8_utf16($this->{str});
}
sub _utf16_utf8 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }
  
  my $result = '';
  my $sa;
  foreach my $uc (unpack("n*", $str))
    {
      ($uc >= 0xd800 and $uc <= 0xdbff and $sa = $uc and next);
      
      ($uc >= 0xdc00 and $uc <= 0xdfff and ($uc = ((($sa - 0xd800) << 10)|($uc - 0xdc00))+0x10000));
      
      $result .= $U2T[$uc] ? $U2T[$uc] :
	($U2T[$uc] = ($uc < 0x80) ? chr($uc) :
	 ($uc < 0x800) ? chr(0xC0 | ($uc >> 6)) . chr(0x80 | ($uc & 0x3F)) :
	 ($uc < 0x10000) ? chr(0xE0 | ($uc >> 12)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)) :
	 chr(0xF0 | ($uc >> 18)) . chr(0x80 | (($uc >> 12) & 0x3F)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)));
    }
  
  $result;
}
sub _u2s {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})/
    $U2S{$1}
      or ($U2S{$1}
	  = ((length($1) == 1) ? $1 :
	     (length($1) == 2) ? (
				  ($c1,$c2) = unpack("C2", $1),
				  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
				  $c = substr($u2s_table, $ch * 2, 2),
				  ($c eq "\0\0") ? '&#' . $ch . ';' : $c
				 ) :
	     (length($1) == 3) ? (
				  ($c1,$c2,$c3) = unpack("C3", $1),
				  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
				  (
				   ($ch <= 0x9fff) ?
				   $c = substr($u2s_table, $ch * 2, 2) :
				   ($ch >= 0xf900 and $ch <= 0xffff) ?
				   (
				    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
				    $c =~ tr,\0,,d
				   ) :
				   (
				    $c = '&#' . $ch . ';'
				   )
				  ),
				  ($c eq "\0\0") ? '&#' . $ch . ';' : $c
				 ) :
	     (length($1) == 4) ? (
				  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
				  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
				  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
				  (
				   ($ch >= 0x0ff000 and $ch <= 0x0fffff) ?
				   '?'
				   : '&#' . $ch . ';'
				  )
				 ) :
	     '&#' . $ch . ';'
	    ))
	/eg;
  $str;
  
}
sub _j2s2 {
  my $this = shift;
  my $esc = shift;
  my $str = shift;

  if($esc eq $RE{JIS_0212})
    {
      $str =~ s/../$CHARCODE{UNDEF_SJIS}/g;
    }
  elsif($esc !~ m/^$RE{JIS_ASC}/)
    {
      $str =~ tr/\x21-\x7e/\xa1-\xfe/;
      if($esc =~ m/^$RE{JIS_0208}/)
	{
	  $str =~ s/($RE{EUC_C})/
	    $J2S[unpack('n', $1)] or $this->_j2s3($1)
	      /geo;
	}
    }
  
  $str;
}
sub z2hKanaD {
  my $this = shift;

  if(!defined(%_z2hKanaD))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x82\xac|\xe3\x82\xae|\xe3\x82\xb0|\xe3\x82\xb2|\xe3\x82\xb4|\xe3\x82\xb6|\xe3\x82\xb8|\xe3\x82\xba|\xe3\x82\xbc|\xe3\x82\xbe|\xe3\x83\x80|\xe3\x83\x82|\xe3\x83\x85|\xe3\x83\x87|\xe3\x83\x89|\xe3\x83\x90|\xe3\x83\x91|\xe3\x83\x93|\xe3\x83\x94|\xe3\x83\x96|\xe3\x83\x97|\xe3\x83\x99|\xe3\x83\x9a|\xe3\x83\x9c|\xe3\x83\x9d|\xe3\x83\xb4)/$_z2hKanaD{$1}/eg;
  
  $this;
}
sub _j2s3 {
  my $this = shift;
  my $c = shift;

  my ($c1, $c2) = unpack('CC', $c);
  if ($c1 % 2)
    {
      $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x31 : 0x71);
      $c2 -= 0x60 + ($c2 < 0xe0);
    }
  else
    {
      $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x30 : 0x70);
      $c2 -= 2;
    }
  
  $J2S[unpack('n', $c)] = pack('CC', $c1, $c2);
}
sub joinCsv {
  my $this = shift;
  my $list;
  
  if(ref($_[0]) eq 'ARRAY')
    {
      $list = shift;
    }
  elsif(!ref($_[0]))
    {
      $list = [ @_ ];
    }
  else
    {
      my $ref = ref($_[0]);
      die "String->joinCsv, Param[1] is not ARRAY/ARRRAY-ref. [$ref]\n";
    }
      
  my $text = join ',', map {(s/"/""/g or /[\r\n,]/) ? qq("$_") : $_} @$list;

  $this->{str} = $text . "\n";

  $this;
}
sub _utf32be_ucs4 {
  my $this = shift;
  my $str = shift;

  $str;
}
sub _s2e2 {
  my $this = shift;
  my $c = shift;
  
  my ($c1, $c2) = unpack('CC', $c);
  if (0xa1 <= $c1 && $c1 <= 0xdf)
    {
      $c2 = $c1;
      $c1 = 0x8e;
    }
  elsif (0x9f <= $c2)
    {
      $c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe0 : 0x60);
      $c2 += 2;
    }
  else
    {
      $c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe1 : 0x61);
      $c2 += 0x60 + ($c2 < 0x7f);
    }
  
  $S2E[unpack('n', $c) or unpack('C', $1)] = pack('CC', $c1, $c2);
}
sub z2hKanaK {
  my $this = shift;

  if(!defined(%_z2hKanaK))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x80\x81|\xe3\x80\x82|\xe3\x83\xbb|\xe3\x82\x9b|\xe3\x82\x9c|\xe3\x83\xbc|\xe3\x80\x8c|\xe3\x80\x8d|\xe3\x82\xa1|\xe3\x82\xa2|\xe3\x82\xa3|\xe3\x82\xa4|\xe3\x82\xa5|\xe3\x82\xa6|\xe3\x82\xa7|\xe3\x82\xa8|\xe3\x82\xa9|\xe3\x82\xaa|\xe3\x82\xab|\xe3\x82\xad|\xe3\x82\xaf|\xe3\x82\xb1|\xe3\x82\xb3|\xe3\x82\xb5|\xe3\x82\xb7|\xe3\x82\xb9|\xe3\x82\xbb|\xe3\x82\xbd|\xe3\x82\xbf|\xe3\x83\x81|\xe3\x83\x83|\xe3\x83\x84|\xe3\x83\x86|\xe3\x83\x88|\xe3\x83\x8a|\xe3\x83\x8b|\xe3\x83\x8c|\xe3\x83\x8d|\xe3\x83\x8e|\xe3\x83\x8f|\xe3\x83\x92|\xe3\x83\x95|\xe3\x83\x98|\xe3\x83\x9b|\xe3\x83\x9e|\xe3\x83\x9f|\xe3\x83\xa0|\xe3\x83\xa1|\xe3\x83\xa2|\xe3\x83\xa3|\xe3\x83\xa4|\xe3\x83\xa5|\xe3\x83\xa6|\xe3\x83\xa7|\xe3\x83\xa8|\xe3\x83\xa9|\xe3\x83\xaa|\xe3\x83\xab|\xe3\x83\xac|\xe3\x83\xad|\xe3\x83\xaf|\xe3\x83\xb2|\xe3\x83\xb3)/$_z2hKanaK{$1}/eg;
  
  $this;
}
sub h2zKana
{
  my $this = shift;

  $this->h2zKanaD;
  $this->h2zKanaK;
  
  $this;
}
sub _ucs2_utf8 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }
  
  my $result = '';
  for my $uc (unpack("n*", $str))
    {
      $result .= $U2T[$uc] ? $U2T[$uc] :
	($U2T[$uc] = ($uc < 0x80) ? chr($uc) :
	  ($uc < 0x800) ? chr(0xC0 | ($uc >> 6)) . chr(0x80 | ($uc & 0x3F)) :
	    chr(0xE0 | ($uc >> 12)) . chr(0x80 | (($uc >> 6) & 0x3F)) .
	      chr(0x80 | ($uc & 0x3F)));
    }
  
  $result;
}
sub z2hAlpha {
  my $this = shift;

  if(!defined(%_z2hAlpha))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbc\xa1|\xef\xbc\xa2|\xef\xbc\xa3|\xef\xbc\xa4|\xef\xbc\xa5|\xef\xbc\xa6|\xef\xbc\xa7|\xef\xbc\xa8|\xef\xbc\xa9|\xef\xbc\xaa|\xef\xbc\xab|\xef\xbc\xac|\xef\xbc\xad|\xef\xbc\xae|\xef\xbc\xaf|\xef\xbc\xb0|\xef\xbc\xb1|\xef\xbc\xb2|\xef\xbc\xb3|\xef\xbc\xb4|\xef\xbc\xb5|\xef\xbc\xb6|\xef\xbc\xb7|\xef\xbc\xb8|\xef\xbc\xb9|\xef\xbc\xba|\xef\xbd\x81|\xef\xbd\x82|\xef\xbd\x83|\xef\xbd\x84|\xef\xbd\x85|\xef\xbd\x86|\xef\xbd\x87|\xef\xbd\x88|\xef\xbd\x89|\xef\xbd\x8a|\xef\xbd\x8b|\xef\xbd\x8c|\xef\xbd\x8d|\xef\xbd\x8e|\xef\xbd\x8f|\xef\xbd\x90|\xef\xbd\x91|\xef\xbd\x92|\xef\xbd\x93|\xef\xbd\x94|\xef\xbd\x95|\xef\xbd\x96|\xef\xbd\x97|\xef\xbd\x98|\xef\xbd\x99|\xef\xbd\x9a)/$_z2hAlpha{$1}/eg;
  
  $this;
}
sub _utf32le_ucs4 {
  my $this = shift;
  my $str = shift;

  my $result = '';
  foreach my $ch (unpack('V*', $str))
    {
      $result .= pack('N', $ch);
    }
  
  $result;
}
sub _utf8_utf16 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $uc;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})/
    $T2U{$1}
      or ($T2U{$1}
	  = ((length($1) == 1) ? pack("n", unpack("C", $1)) :
	     (length($1) == 2) ? (($c1,$c2) = unpack("C2", $1),
				  pack("n", (($c1 & 0x1F)<<6)|($c2 & 0x3F))) :
	     (length($1) == 3) ? (($c1,$c2,$c3) = unpack("C3", $1),
				  pack("n", (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F))) :
	     (length($1) == 4) ? (($c1,$c2,$c3,$c4) = unpack("C4", $1),
				  ($uc = ((($c1 & 0x07) << 18)|(($c2 & 0x3F) << 12)|
					  (($c3 & 0x3f) << 6)|($c4 & 0x3F)) - 0x10000),
				  (($uc < 0x100000) ? pack("nn", (($uc >> 10) | 0xd800), (($uc & 0x3ff) | 0xdc00)) : "\0?")) :
	     "\0?")
	 );
  /eg;
  $str;
}
sub getcode {
  my $this = shift;
  my $str = shift;

  my $l = length($str);
  
  if((($l % 4) == 0)
     and ($str =~ m/^(?:$RE{BOM4_BE}|$RE{BOM4_LE})/o))
    {
      return 'utf32';
    }
  if((($l % 2) == 0)
     and ($str =~ m/^(?:$RE{BOM2_BE}|$RE{BOM2_LE})/o))
    {
      return 'utf16';
    }

  my $str2;
  
  if(($l % 4) == 0)
    {
      $str2 = $str;
      1 while($str2 =~ s/^(?:$RE{UTF32_BE})//o);
      if($str2 eq '')
	{
	  return 'utf32-be';
	}
      
      $str2 = $str;
      1 while($str2 =~ s/^(?:$RE{UTF32_LE})//o);
      if($str2 eq '')
	{
	  return 'utf32-le';
	}
    }
  
  if($str !~ m/[\e\x80-\xff]/)
    {
      return 'ascii';
    }

  if($str =~ m/$RE{JIS_0208}|$RE{JIS_0212}|$RE{JIS_ASC}|$RE{JIS_KANA}/o)
    {
      return 'jis';
    }

  if($str =~ m/(?:$RE{E_JSKY})/o)
    {
      return 'sjis-jsky';
    }

  $str2 = $str;
  1 while($str2 =~ s/^(?:$RE{ASCII}|$RE{EUC_0212}|$RE{EUC_KANA}|$RE{EUC_C})//o);
  if($str2 eq '')
    {
      return 'euc';
    }

  $str2 = $str;
  1 while($str2 =~ s/^(?:$RE{ASCII}|$RE{SJIS_C}|$RE{SJIS_KANA})//o);
  if($str2 eq '')
    {
      return 'sjis';
    }

  my $str3;
  $str3 = $str2;
  1 while($str3 =~ s/^(?:$RE{ASCII}|$RE{SJIS_C}|$RE{SJIS_KANA}|$RE{E_IMODE})//o);
  if($str3 eq '')
    {
      return 'sjis-imode';
    }

  $str3 = $str2;
  1 while($str3 =~ s/^(?:$RE{ASCII}|$RE{SJIS_C}|$RE{SJIS_KANA}|$RE{E_DOTI})//o);
  if($str3 eq '')
    {
      return 'sjis-doti';
    }

  $str2 = $str;
  1 while($str2 =~ s/^(?:$RE{UTF8})//o);
  if($str2 eq '')
    {
      return 'utf8';
    }

  return 'unknown';
}
sub _decodeBase64
{
  local($^W) = 0; # unpack("u",...) gives bogus warning in 5.00[123]

  my $this = shift;
  my $str = shift;
  my $res = "";

  $str =~ tr|A-Za-z0-9+=/||cd;            # remove non-base64 chars
  if (length($str) % 4)
    {
      warn("Length of base64 data not a multiple of 4");
    }
  $str =~ s/=+$//;                        # remove padding
  $str =~ tr|A-Za-z0-9+/| -_|;            # convert to uuencoded format
  while ($str =~ /(.{1,60})/gs)
    {
      my $len = chr(32 + length($1)*3/4); # compute length byte
      $res .= unpack("u", $len . $1 );    # uudecode
    }
  $res;
}
sub sjis_doti
{
  my $this = shift;
  $this->_u2sd($this->{str});
}
sub sjis_jsky
{
  my $this = shift;
  $this->_u2sj($this->{str});
}
sub tag2bin {
  my $this = shift;

  $this->{str} =~ s/\&(\#\d+|\#x[a-f0-9A-F]+);/
    (substr($1, 1, 1) eq 'x') ? $this->_ucs4_utf8(pack('N', hex(substr($1, 2)))) :
      $this->_ucs4_utf8(pack('N', substr($1, 1)))
	/eg;
  
  $this;
}
sub strcut
{
  my $this = shift;
  my $cutlen = shift;
  
  if(ref($cutlen))
    {
      die "String->strcut, Param[1] is Ref.\n";
    }
  if($cutlen =~ m/\D/)
    {
      die "String->strcut, Param[1] must be NUMERIC.\n";
    }
  
  my $ch_re = '[\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}';
  
  my $result;
  my $line = '';
  my $linelength = 0;
  foreach my $c (split(/($ch_re)/, $this->{str}))
    {
      next if(length($c) == 0);
      if($linelength + (length($c) >= 3 ? 2 : 1) > $cutlen)
	{
	  push(@$result, $line);
	  $line = '';
	  $linelength = 0;
	}
      $linelength += (length($c) >= 3 ? 2 : 1);
      $line .= $c;
    }
  push(@$result, $line);

  $result;
}
sub h2zKanaD {
  my $this = shift;

  if(!defined(%_h2zKanaD))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbd\xb3\xef\xbe\x9e|\xef\xbd\xb6\xef\xbe\x9e|\xef\xbd\xb7\xef\xbe\x9e|\xef\xbd\xb8\xef\xbe\x9e|\xef\xbd\xb9\xef\xbe\x9e|\xef\xbd\xba\xef\xbe\x9e|\xef\xbd\xbb\xef\xbe\x9e|\xef\xbd\xbc\xef\xbe\x9e|\xef\xbd\xbd\xef\xbe\x9e|\xef\xbd\xbe\xef\xbe\x9e|\xef\xbd\xbf\xef\xbe\x9e|\xef\xbe\x80\xef\xbe\x9e|\xef\xbe\x81\xef\xbe\x9e|\xef\xbe\x82\xef\xbe\x9e|\xef\xbe\x83\xef\xbe\x9e|\xef\xbe\x84\xef\xbe\x9e|\xef\xbe\x8a\xef\xbe\x9e|\xef\xbe\x8a\xef\xbe\x9f|\xef\xbe\x8b\xef\xbe\x9e|\xef\xbe\x8b\xef\xbe\x9f|\xef\xbe\x8c\xef\xbe\x9e|\xef\xbe\x8c\xef\xbe\x9f|\xef\xbe\x8d\xef\xbe\x9e|\xef\xbe\x8d\xef\xbe\x9f|\xef\xbe\x8e\xef\xbe\x9e|\xef\xbe\x8e\xef\xbe\x9f)/$_h2zKanaD{$1}/eg;
  
  $this;
}
sub _utf8_ucs2 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }

  my $c1;
  my $c2;
  my $c3;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})/
    $T2U{$1}
      or ($T2U{$1}
	  = ((length($1) == 1) ? pack("n", unpack("C", $1)) :
	     (length($1) == 2) ? (($c1,$c2) = unpack("C2", $1),
				  pack("n", (($c1 & 0x1F)<<6)|($c2 & 0x3F))) :
	     (length($1) == 3) ? (($c1,$c2,$c3) = unpack("C3", $1),
				  pack("n", (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F))) : "\0?"))
	/eg;
  $str;
}
sub sjis_imode
{
  my $this = shift;
  $this->_u2si($this->{str});
}
sub _utf8_ucs4 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})/
    (length($1) == 1) ? pack("N", unpack("C", $1)) :
    (length($1) == 2) ? (($c1,$c2) = unpack("C2", $1),
	                pack("N", (($c1 & 0x1F) << 6)|($c2 & 0x3F))) :
    (length($1) == 3) ? (($c1,$c2,$c3) = unpack("C3", $1),
	                pack("N", (($c1 & 0x0F) << 12)|(($c2 & 0x3F) << 6)|
                           ($c3 & 0x3F))) :
    (length($1) == 4) ? (($c1,$c2,$c3,$c4) = unpack("C4", $1),
	                pack("N", (($c1 & 0x07) << 18)|(($c2 & 0x3F) << 12)|
                           (($c3 & 0x3f) << 6)|($c4 & 0x3F))) :
    (length($1) == 5) ? (($c1,$c2,$c3,$c4,$c5) = unpack("C5", $1),
	                pack("N", (($c1 & 0x03) << 24)|(($c2 & 0x3F) << 18)|
                           (($c3 & 0x3f) << 12)|(($c4 & 0x3f) << 6)|
                           ($c5 & 0x3F))) :
    (($c1,$c2,$c3,$c4,$c5,$c6) = unpack("C6", $1),
	                pack("N", (($c1 & 0x03) << 30)|(($c2 & 0x3F) << 24)|
                           (($c3 & 0x3f) << 18)|(($c4 & 0x3f) << 12)|
                           (($c5 & 0x3f) << 6)|($c6 & 0x3F)))
    /eg;

  $str;
}
sub _u2sd {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  if(!defined($eu2d))
    {
      $eu2d = $this->_getFile('jcode/emoji/eu2d.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})/
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? (
			  ($c1,$c2) = unpack("C2", $1),
			  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
			  $c = substr($u2s_table, $ch * 2, 2),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 3) ? (
			  ($c1,$c2,$c3) = unpack("C3", $1),
			  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
			  (
			   ($ch <= 0x9fff) ?
			   $c = substr($u2s_table, $ch * 2, 2) :
			   ($ch >= 0xf900 and $ch <= 0xffff) ?
			   (
			    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
			    $c =~ tr,\0,,d
			   ) :
			   (
			    $c = '?'
			   )
			  ),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0ff000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2d, ($ch - 0x0ff000) * 2, 2),
			    $c =~ tr,\0,,d,
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;
  $str;
  
}
sub get {
  my $this = shift;
  $this->{str};
}
sub utf8
{
  my $this = shift;
  $this->{str};
}
sub hira2kata {
  my $this = shift;

  if(!defined(%_hira2kata))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x81\x81|\xe3\x81\x82|\xe3\x81\x83|\xe3\x81\x84|\xe3\x81\x85|\xe3\x81\x86|\xe3\x81\x87|\xe3\x81\x88|\xe3\x81\x89|\xe3\x81\x8a|\xe3\x81\x8b|\xe3\x81\x8c|\xe3\x81\x8d|\xe3\x81\x8e|\xe3\x81\x8f|\xe3\x81\x90|\xe3\x81\x91|\xe3\x81\x92|\xe3\x81\x93|\xe3\x81\x94|\xe3\x81\x95|\xe3\x81\x96|\xe3\x81\x97|\xe3\x81\x98|\xe3\x81\x99|\xe3\x81\x9a|\xe3\x81\x9b|\xe3\x81\x9c|\xe3\x81\x9d|\xe3\x81\x9e|\xe3\x81\x9f|\xe3\x81\xa0|\xe3\x81\xa1|\xe3\x81\xa2|\xe3\x81\xa3|\xe3\x81\xa4|\xe3\x81\xa5|\xe3\x81\xa6|\xe3\x81\xa7|\xe3\x81\xa8|\xe3\x81\xa9|\xe3\x81\xaa|\xe3\x81\xab|\xe3\x81\xac|\xe3\x81\xad|\xe3\x81\xae|\xe3\x81\xaf|\xe3\x81\xb0|\xe3\x81\xb1|\xe3\x81\xb2|\xe3\x81\xb3|\xe3\x81\xb4|\xe3\x81\xb5|\xe3\x81\xb6|\xe3\x81\xb7|\xe3\x81\xb8|\xe3\x81\xb9|\xe3\x81\xba|\xe3\x81\xbb|\xe3\x81\xbc|\xe3\x81\xbd|\xe3\x81\xbe|\xe3\x81\xbf|\xe3\x82\x80|\xe3\x82\x81|\xe3\x82\x82|\xe3\x82\x83|\xe3\x82\x84|\xe3\x82\x85|\xe3\x82\x86|\xe3\x82\x87|\xe3\x82\x88|\xe3\x82\x89|\xe3\x82\x8a|\xe3\x82\x8b|\xe3\x82\x8c|\xe3\x82\x8d|\xe3\x82\x8e|\xe3\x82\x8f|\xe3\x82\x90|\xe3\x82\x91|\xe3\x82\x92|\xe3\x82\x93)/$_hira2kata{$1}/eg;
  
  $this;
}
sub z2h {
  my $this = shift;

  $this->z2hKana;
  $this->z2hNum;
  $this->z2hAlpha;
  $this->z2hSym;

  $this;
}
sub _encodeBase64
{
  my $this = shift;
  my $str = shift;
  my $eol = shift;
  my $res = "";
  
  $eol = "\n" unless defined $eol;
  pos($str) = 0;                          # ensure start at the beginning
  while ($str =~ /(.{1,45})/gs)
    {
      $res .= substr(pack('u', $1), 1);
      chop($res);
    }
  $res =~ tr|` -_|AA-Za-z0-9+/|;               # `# help emacs
  # fix padding at the end
  my $padding = (3 - length($str) % 3) % 3;
  $res =~ s/.{$padding}$/'=' x $padding/e if $padding;
  # break encoded string into lines of no more than 76 characters each
  if (length $eol)
    {
      $res =~ s/(.{1,76})/$1$eol/g;
    }
  $res;
}
sub h2zKanaK {
  my $this = shift;

  if(!defined(%_h2zKanaK))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbd\xa1|\xef\xbd\xa2|\xef\xbd\xa3|\xef\xbd\xa4|\xef\xbd\xa5|\xef\xbd\xa6|\xef\xbd\xa7|\xef\xbd\xa8|\xef\xbd\xa9|\xef\xbd\xaa|\xef\xbd\xab|\xef\xbd\xac|\xef\xbd\xad|\xef\xbd\xae|\xef\xbd\xaf|\xef\xbd\xb0|\xef\xbd\xb1|\xef\xbd\xb2|\xef\xbd\xb3|\xef\xbd\xb4|\xef\xbd\xb5|\xef\xbd\xb6|\xef\xbd\xb7|\xef\xbd\xb8|\xef\xbd\xb9|\xef\xbd\xba|\xef\xbd\xbb|\xef\xbd\xbc|\xef\xbd\xbd|\xef\xbd\xbe|\xef\xbd\xbf|\xef\xbe\x80|\xef\xbe\x81|\xef\xbe\x82|\xef\xbe\x83|\xef\xbe\x84|\xef\xbe\x85|\xef\xbe\x86|\xef\xbe\x87|\xef\xbe\x88|\xef\xbe\x89|\xef\xbe\x8a|\xef\xbe\x8b|\xef\xbe\x8c|\xef\xbe\x8d|\xef\xbe\x8e|\xef\xbe\x8f|\xef\xbe\x90|\xef\xbe\x91|\xef\xbe\x92|\xef\xbe\x93|\xef\xbe\x94|\xef\xbe\x95|\xef\xbe\x96|\xef\xbe\x97|\xef\xbe\x98|\xef\xbe\x99|\xef\xbe\x9a|\xef\xbe\x9b|\xef\xbe\x9c|\xef\xbe\x9d|\xef\xbe\x9e|\xef\xbe\x9f)/$_h2zKanaK{$1}/eg;
  
  $this;
}
sub _u2si {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  if(!defined($eu2i))
    {
      $eu2i = $this->_getFile('jcode/emoji/eu2i.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})/
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? (
			  ($c1,$c2) = unpack("C2", $1),
			  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
			  $c = substr($u2s_table, $ch * 2, 2),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 3) ? (
			  ($c1,$c2,$c3) = unpack("C3", $1),
			  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
			  (
			   ($ch <= 0x9fff) ?
			   $c = substr($u2s_table, $ch * 2, 2) :
			   ($ch >= 0xf900 and $ch <= 0xffff) ?
			   (
			    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
			    $c =~ tr,\0,,d
			   ) :
			   (
			    $c = '?'
			   )
			  ),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0ff000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2i, ($ch - 0x0ff000) * 2, 2),
			    $c =~ tr,\0,,d,
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;
  $str;
  
}
sub _u2sj {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($u2s_table))
    {
      $u2s_table = $this->_getFile('jcode/u2s.dat');
    }

  if(!defined($eu2j))
    {
      $eu2j = $this->_getFile('jcode/emoji/eu2j.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})/
    ((length($1) == 1) ? $1 :
     (length($1) == 2) ? (
			  ($c1,$c2) = unpack("C2", $1),
			  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
			  $c = substr($u2s_table, $ch * 2, 2),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 3) ? (
			  ($c1,$c2,$c3) = unpack("C3", $1),
			  $ch = (($c1 & 0x0F)<<12)|(($c2 & 0x3F)<<6)|($c3 & 0x3F),
			  (
			   ($ch <= 0x9fff) ?
			   $c = substr($u2s_table, $ch * 2, 2) :
			   ($ch >= 0xf900 and $ch <= 0xffff) ?
			   (
			    $c = substr($u2s_table, ($ch - 0xf900 + 0xa000) * 2, 2),
			    $c =~ tr,\0,,d
			   ) :
			   (
			    $c = '?'
			   )
			  ),
			  ($c eq "\0\0") ? '?' : $c
			 ) :
     (length($1) == 4) ? (
			  ($c1,$c2,$c3,$c4) = unpack("C4", $1),
			  $ch = (($c1 & 0x07)<<18)|(($c2 & 0x3F)<<12)|
			  (($c3 & 0x3f) << 6)|($c4 & 0x3F),
			  (
			   ($ch >= 0x0ff000 and $ch <= 0x0fffff) ?
			   (
			    $c = substr($eu2j, ($ch - 0x0ff000) * 5, 5),
			    $c =~ tr,\0,,d,
			    ($c eq '') ? '?' : $c
			   ) :
			   '?'
			  )
			 ) :
     '?'
    )
      /eg;

  1 while($str =~ s/($RE{E_JSKY_START})($RE{E_JSKY1})($RE{E_JSKY2}+)$RE{E_JSKY_END}$RE{E_JSKY_START}\2($RE{E_JSKY2})($RE{E_JSKY_END})/$1$2$3$4$5/o);
  
  $str;
  
}
sub h2zAlpha {
  my $this = shift;

  if(!defined(%_h2zAlpha))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z)/$_h2zAlpha{$1}/eg;
  
  $this;
}
sub _s2e {
  my $this = shift;
  my $str = shift;
  
  $str =~ s/($RE{SJIS_C}|$RE{SJIS_KANA})/
    $S2E[unpack('n', $1) or unpack('C', $1)] or $this->_s2e2($1)
      /geo;
  
  $str;
}
sub _e2s2 {
  my $this = shift;
  my $c = shift;

  my ($c1, $c2) = unpack('CC', $c);
  if ($c1 == 0x8e)
    {		# SS2
      $E2S[unpack('n', $c)] = chr($c2);
    }
  elsif ($c1 == 0x8f)
    {	# SS3
      $E2S[unpack('N', "\0" . $c)] = $CHARCODE{UNDEF_SJIS};
    }
  else
    {			#SS1 or X0208
      if ($c1 % 2)
	{
	  $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x31 : 0x71);
	  $c2 -= 0x60 + ($c2 < 0xe0);
	}
      else
	{
	  $c1 = ($c1>>1) + ($c1 < 0xdf ? 0x30 : 0x70);
	  $c2 -= 2;
	}
      $E2S[unpack('n', $c)] = pack('CC', $c1, $c2);
    }
}
sub _utf16le_utf16 {
  my $this = shift;
  my $str = shift;

  my $result = '';
  foreach my $ch (unpack('v*', $str))
    {
      $result .= pack('n', $ch);
    }
  
  $result;
}
sub _sj2u {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  if(!defined($ej2u))
    {
      $ej2u = $this->_getFile('jcode/emoji/ej2u.dat');
    }

  my $l;
  my $j1;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_C}|$RE{E_JSKY}|[\x00-\xff])/
    (length($1) <= 2) ? 
      (
       $l = (unpack('n', $1) or unpack('C', $1)),
       (
	($l >= 0xa1 and $l <= 0xdf)     ?
	(
	 $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	 $uc =~ tr,\0,,d,
	 $uc
	) :
	($l >= 0x8100 and $l <= 0x9fff) ?
	(
	 $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	 $uc =~ tr,\0,,d,
	 $uc
	) :
	($l >= 0xe000 and $l <= 0xefff) ?
	(
	 $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	 $uc =~ tr,\0,,d,
	 $uc
	) :
	($l < 0x80) ?
	chr($l) :
	'?'
       )
      ) :
	(
         $l = $1,
	 $l =~ s,^$RE{E_JSKY_START}($RE{E_JSKY1}),,o,
	 $j1 = $1,
	 $uc = '',
	 $l =~ s!($RE{E_JSKY2})!$uc .= substr($ej2u, (unpack('n', $j1 . $1) - 0x4500) * 4, 4), ''!ego,
	 $uc =~ tr,\0,,d,
	 $uc
	)
  /eg;
  
  $str;
  
}
sub _s2j {
  my $this = shift;
  my $str = shift;

  $str =~ s/((?:$RE{SJIS_C}|$RE{SJIS_KANA})+)/
    $this->_s2j2($1) . $ESC{ASC}
      /geo;

  $str;
}
sub _s2j2 {
  my $this = shift;
  my $str = shift;

  $str =~ s/((?:$RE{SJIS_C})+|(?:$RE{SJIS_KANA})+)/
    my $s = $1;
  if($s =~ m,^$RE{SJIS_KANA},)
    {
      $s =~ tr,\xa1-\xdf,\x21-\x5f,;
      $ESC{KANA} . $s
    }
  else
    {
      $s =~ s!($RE{SJIS_C})!
	$S2J[unpack('n', $1)] or $this->_s2j3($1)
	  !geo;
      $ESC{JIS_0208} . $s;
    }
  /geo;
  
  $str;
}
sub _s2j3 {
  my $this = shift;
  my $c = shift;

  my ($c1, $c2) = unpack('CC', $c);
  if (0x9f <= $c2)
    {
      $c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe0 : 0x60);
      $c2 += 2;
    }
  else
    {
      $c1 = $c1 * 2 - ($c1 >= 0xe0 ? 0xe1 : 0x61);
      $c2 += 0x60 + ($c2 < 0x7f);
    }
  
  $S2J[unpack('n', $c)] = pack('CC', $c1 - 0x80, $c2 - 0x80);
}
sub conv {
  my $this = shift;
  my $ocode = shift;
  my $encode = shift;
  my (@option) = @_;

  my $res;
  if($ocode eq 'utf8')
    {
      $res = $this->utf8;
    }
  elsif($ocode eq 'euc')
    {
      $res = $this->euc;
    }
  elsif($ocode eq 'jis')
    {
      $res = $this->jis;
    }
  elsif($ocode eq 'sjis')
    {
      $res = $this->sjis;
    }
  elsif($ocode eq 'sjis-imode')
    {
      $res = $this->sjis_imode;
    }
  elsif($ocode eq 'sjis-doti')
    {
      $res = $this->sjis_doti;
    }
  elsif($ocode eq 'sjis-jsky')
    {
      $res = $this->sjis_jsky;
    }
  elsif($ocode eq 'ucs2')
    {
      $res = $this->ucs2;
    }
  elsif($ocode eq 'ucs4')
    {
      $res = $this->ucs4;
    }
  elsif($ocode eq 'utf16')
    {
      $res = $this->utf16;
    }
  elsif($ocode eq 'binary')
    {
      $res = $this->{str};
    }
  else
    {
      die "String->conv, Param[1] is error.\n";
    }

  if(defined($encode))
    {
      if($encode eq 'base64')
	{
	  $res = $this->_encodeBase64($res, @option);
	}
      else
	{
	  die "String->conv, Param[2] encode name error.\n";
	}
    }

  $res;
}
sub _s2u {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_C}|[\x00-\xff])/
    $S2U{$1}
      or ($S2U{$1} =
	  (
	   $l = (unpack('n', $1) or unpack('C', $1)),
	   (
	    ($l >= 0xa1 and $l <= 0xdf)     ?
	    (
	     $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0x8100 and $l <= 0x9fff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xfcff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l < 0x80) ?
	    chr($l) :
	    '?'
	   )
	  )
	 )/eg;
  
  $str;
  
}
sub _j2s {
  my $this = shift;
  my $str = shift;

  $str =~ s/($RE{JIS_0208}|$RE{JIS_0212}|$RE{JIS_ASC}|$RE{JIS_KANA})([^\e]*)/
    $this->_j2s2($1, $2)
      /geo;

  $str;
}
sub h2z {
  my $this = shift;

  $this->h2zKana;
  $this->h2zNum;
  $this->h2zAlpha;
  $this->h2zSym;

  $this;
}
sub ucs2
{
  my $this = shift;
  $this->_utf8_ucs2($this->{str});
}
sub z2hSym {
  my $this = shift;

  if(!defined(%_z2hSym))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x80\x80|\xef\xbc\x8c|\xef\xbc\x8e|\xef\xbc\x9a|\xef\xbc\x9b|\xef\xbc\x9f|\xef\xbc\x81|\xef\xbd\x80|\xef\xbc\xbe|\xef\xbc\x8f|\xe3\x80\x9c|\xef\xbd\x9c|\xe2\x80\x9d|\xef\xbc\x88|\xef\xbc\x89|\xef\xbc\xbb|\xef\xbc\xbd|\xef\xbd\x9b|\xef\xbd\x9d|\xef\xbc\x8b|\xe2\x88\x92|\xef\xbc\x9d|\xef\xbc\x9c|\xef\xbc\x9e|\xef\xbf\xa5|\xef\xbc\x84|\xef\xbc\x85|\xef\xbc\x83|\xef\xbc\x86|\xef\xbc\x8a|\xef\xbc\xa0)/$_z2hSym{$1}/eg;
  
  $this;
}
sub set
{
  my $this = shift;
  my $str = shift;
  my $icode = shift;
  my $encode = shift;

  if(ref($str))
    {
      die "String->set, Param[1] is Ref.\n";
    }
  if(ref($icode))
    {
      die "String->set, Param[2] is Ref.\n";
    }
  if(ref($encode))
    {
      die "String->set, Param[3] is Ref.\n";
    }

  if(defined($encode))
    {
      if($encode eq 'base64')
	{
	  $str = $this->_decodeBase64($str);
	}
      else
	{
	  die "String->set, Param[3] encode name error.\n";
	}
    }
  
  if(!defined($icode))
    {
      $this->{str} = $str;
    }
  else
    {
      $icode = lc($icode);
      if($icode eq 'auto')
	{
	  $icode = $this->getcode($str);
	}
      if($icode eq 'utf8')
	{
	  $this->{str} = $str;
	}
      elsif($icode eq 'ucs2')
	{
	  $this->{str} = $this->_ucs2_utf8($str);
	}
      elsif($icode eq 'ucs4')
	{
	  $this->{str} = $this->_ucs4_utf8($str);
	}
      elsif($icode eq 'utf16-be')
	{
	  $this->{str} = $this->_utf16_utf8($this->_utf16be_utf16($str));
	}
      elsif($icode eq 'utf16-le')
	{
	  $this->{str} = $this->_utf16_utf8($this->_utf16le_utf16($str));
	}
      elsif($icode eq 'utf16')
	{
	  $this->{str} = $this->_utf16_utf8($this->_utf16_utf16($str));
	}
      elsif($icode eq 'utf32-be')
	{
	  $this->{str} = $this->_ucs4_utf8($this->_utf32be_ucs4($str));
	}
      elsif($icode eq 'utf32-le')
	{
	  $this->{str} = $this->_ucs4_utf8($this->_utf32le_ucs4($str));
	}
      elsif($icode eq 'utf32')
	{
	  $this->{str} = $this->_ucs4_utf8($this->_utf32_ucs4($str));
	}
      elsif($icode eq 'jis')
	{
	  $this->{str} = $this->_j2s($str);
	  $this->{str} = $this->_s2u($this->{str});
	}
      elsif($icode eq 'euc')
	{
	  $this->{str} = $this->_e2s($str);
	  $this->{str} = $this->_s2u($this->{str});
	}
      elsif($icode eq 'sjis')
	{
	  $this->{str} = $this->_s2u($str);
	}
      elsif($icode eq 'sjis-imode')
	{
	  $this->{str} = $this->_si2u($str);
	}
      elsif($icode eq 'sjis-doti')
	{
	  $this->{str} = $this->_sd2u($str);
	}
      elsif($icode eq 'sjis-jsky')
	{
	  $this->{str} = $this->_sj2u($str);
	}
      elsif($icode eq 'ascii')
	{
	  $this->{str} = $str;
	}
      elsif($icode eq 'unknown')
	{
	  $this->{str} = $str;
	}
      elsif($icode eq 'binary')
	{
	  $this->{str} = $str;
	}
      else
	{
	  die "icode error\n";
	}
    }

  $this;
}
sub ucs4
{
  my $this = shift;
  $this->_utf8_ucs4($this->{str});
}
sub z2hNum {
  my $this = shift;

  if(!defined(%_z2hNum))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbc\x90|\xef\xbc\x91|\xef\xbc\x92|\xef\xbc\x93|\xef\xbc\x94|\xef\xbc\x95|\xef\xbc\x96|\xef\xbc\x97|\xef\xbc\x98|\xef\xbc\x99)/$_z2hNum{$1}/eg;
  
  $this;
}
sub _si2u {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  if(!defined($ei2u))
    {
      $ei2u = $this->_getFile('jcode/emoji/ei2u.dat');
    }

  $str =~ s/(\&\#(\d+);)/
    ($2 >= 0xf800 and $2 <= 0xf9ff) ? pack('n', $2) : $1
      /eg;
  
  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_C}|$RE{E_IMODE}|[\x00-\xff])/
    $S2U{$1}
      or ($S2U{$1} =
	  (
	   $l = (unpack('n', $1) or unpack('C', $1)),
	   (
	    ($l >= 0xa1 and $l <= 0xdf)     ?
	    (
	     $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0x8100 and $l <= 0x9fff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xefff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xf800 and $l <= 0xf9ff) ?
	    (
	     $uc = substr($ei2u, ($l - 0xf800) * 4, 4),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l < 0x80) ?
	    chr($l) :
	    '?'
	   )
	  )
	 )/eg;
  
  $str;
  
}
sub _e2s {
  my $this = shift;
  my $str = shift;

  $str =~ s/($RE{EUC_KANA}|$RE{EUC_0212}|$RE{EUC_C})/
    $E2S[unpack('n', $1) or unpack('N', "\0" . $1)] or $this->_e2s2($1)
      /geo;
  
  $str;
}
sub jis
{
  my $this = shift;
  $this->_s2j($this->sjis);
}
sub _utf32_ucs4 {
  my $this = shift;
  my $str = shift;

  if($str =~ s/^\x00\x00\xfe\xff//)
    {
      $str = $this->_utf32be_ucs4($str);
    }
  elsif($str =~ s/^\xff\xfe\x00\x00//)
    {
      $str = $this->_utf32le_ucs4($str);
    }
  else
    {
      $str = $this->_utf32be_ucs4($str);
    }
  
  $str;
}
sub kata2hira {
  my $this = shift;

  if(!defined(%_kata2hira))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x82\xa1|\xe3\x82\xa2|\xe3\x82\xa3|\xe3\x82\xa4|\xe3\x82\xa5|\xe3\x82\xa6|\xe3\x82\xa7|\xe3\x82\xa8|\xe3\x82\xa9|\xe3\x82\xaa|\xe3\x82\xab|\xe3\x82\xac|\xe3\x82\xad|\xe3\x82\xae|\xe3\x82\xaf|\xe3\x82\xb0|\xe3\x82\xb1|\xe3\x82\xb2|\xe3\x82\xb3|\xe3\x82\xb4|\xe3\x82\xb5|\xe3\x82\xb6|\xe3\x82\xb7|\xe3\x82\xb8|\xe3\x82\xb9|\xe3\x82\xba|\xe3\x82\xbb|\xe3\x82\xbc|\xe3\x82\xbd|\xe3\x82\xbe|\xe3\x82\xbf|\xe3\x83\x80|\xe3\x83\x81|\xe3\x83\x82|\xe3\x83\x83|\xe3\x83\x84|\xe3\x83\x85|\xe3\x83\x86|\xe3\x83\x87|\xe3\x83\x88|\xe3\x83\x89|\xe3\x83\x8a|\xe3\x83\x8b|\xe3\x83\x8c|\xe3\x83\x8d|\xe3\x83\x8e|\xe3\x83\x8f|\xe3\x83\x90|\xe3\x83\x91|\xe3\x83\x92|\xe3\x83\x93|\xe3\x83\x94|\xe3\x83\x95|\xe3\x83\x96|\xe3\x83\x97|\xe3\x83\x98|\xe3\x83\x99|\xe3\x83\x9a|\xe3\x83\x9b|\xe3\x83\x9c|\xe3\x83\x9d|\xe3\x83\x9e|\xe3\x83\x9f|\xe3\x83\xa0|\xe3\x83\xa1|\xe3\x83\xa2|\xe3\x83\xa3|\xe3\x83\xa4|\xe3\x83\xa5|\xe3\x83\xa6|\xe3\x83\xa7|\xe3\x83\xa8|\xe3\x83\xa9|\xe3\x83\xaa|\xe3\x83\xab|\xe3\x83\xac|\xe3\x83\xad|\xe3\x83\xae|\xe3\x83\xaf|\xe3\x83\xb0|\xe3\x83\xb1|\xe3\x83\xb2|\xe3\x83\xb3)/$_kata2hira{$1}/eg;
  
  $this;
}
sub _ucs4_utf8 {
  my $this = shift;
  my $str = shift;
  
  if(!defined($str))
    {
      return '';
    }
  
  my $result = '';
  for my $uc (unpack("N*", $str))
    {
      $result .= ($uc < 0x80) ? chr($uc) :
	($uc < 0x800) ? chr(0xC0 | ($uc >> 6)) . chr(0x80 | ($uc & 0x3F)) :
	  ($uc < 0x10000) ? chr(0xE0 | ($uc >> 12)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)) :
	    ($uc < 0x200000) ? chr(0xF0 | ($uc >> 18)) . chr(0x80 | (($uc >> 12) & 0x3F)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)) :
	      ($uc < 0x4000000) ? chr(0xF8 | ($uc >> 24)) . chr(0x80 | (($uc >> 18) & 0x3F)) . chr(0x80 | (($uc >> 12) & 0x3F)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F)) :
		chr(0xFC | ($uc >> 30)) . chr(0x80 | (($uc >> 24) & 0x3F)) . chr(0x80 | (($uc >> 18) & 0x3F)) . chr(0x80 | (($uc >> 12) & 0x3F)) . chr(0x80 | (($uc >> 6) & 0x3F)) . chr(0x80 | ($uc & 0x3F));
    }
  
  $result;
}
sub split_csv {
  my $this = shift;

  $this->splitCsv(@_);
}
sub _utf16_utf16 {
  my $this = shift;
  my $str = shift;

  if($str =~ s/^\xfe\xff//)
    {
      $str = $this->_utf16be_utf16($str);
    }
  elsif($str =~ s/^\xff\xfe//)
    {
      $str = $this->_utf16le_utf16($str);
    }
  else
    {
      $str = $this->_utf16be_utf16($str);
    }
  
  $str;
}
sub _sd2u {
  my $this = shift;
  my $str = shift;

  if(!defined($str))
    {
      return '';
    }
  
  if(!defined($s2u_table))
    {
      $s2u_table = $this->_getFile('jcode/s2u.dat');
    }

  if(!defined($ed2u))
    {
      $ed2u = $this->_getFile('jcode/emoji/ed2u.dat');
    }

  $str =~ s/(\&\#(\d+);)/
    ($2 >= 0xf000 and $2 <= 0xf4ff) ? pack('n', $2) : $1
      /eg;
  
  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_C}|$RE{E_DOTI}|[\x00-\xff])/
    $S2U{$1}
      or ($S2U{$1} =
	  (
	   $l = (unpack('n', $1) or unpack('C', $1)),
	   (
	    ($l >= 0xa1 and $l <= 0xdf)     ?
	    (
	     $uc = substr($s2u_table, ($l - 0xa1) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0x8100 and $l <= 0x9fff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0x8100 + 0x3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xefff) ?
	    (
	     $uc = substr($s2u_table, ($l - 0xe000 + 0x1f3f) * 3, 3),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xf000 and $l <= 0xf4ff) ?
	    (
	     $uc = substr($ed2u, ($l - 0xf000) * 4, 4),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l < 0x80) ?
	    chr($l) :
	    '?'
	   )
	  )
	 )/eg;
  
  $str;
  
}
sub sjis
{
  my $this = shift;
  $this->_u2s($this->{str});
}
sub _utf16be_utf16 {
  my $this = shift;
  my $str = shift;

  $str;
}
sub h2zSym {
  my $this = shift;

  if(!defined(%_h2zSym))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\x20|\x21|\x22|\x23|\x24|\x25|\x26|\x27|\x28|\x29|\x2a|\x2b|\x2c|\x2d|\x2e|\x2f|\x3a|\x3b|\x3c|\x3d|\x3e|\x3f|\x40|\x5b|\x5c|\x5d|\x5e|\x60|\x7b|\x7c|\x7d|\x7e)/$_h2zSym{$1}/eg;
  
  $this;
}
          	 
                        ! " # $ % & ' ( ) * + , - . / 0 1 2 3 4 5 6 7 8 9 : ; < = > ? @ A B C D E F G H I J K L M N O P Q R S T U V W X Y Z [ \ ] ^ _ ` a b c d e f g h i j k l m n o p q r s t u v w x y z { | } ~                                                                                ���N              ���}    �L  ��                                                                �~                                                              ��                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  ����������������������������������  ��������������              �������ÃăŃƃǃȃɃʃ˃̃̓΃�  �Ѓу҃ӃԃՃ�                                                                                                              �F                            �@�A�B�C�D�E�G�H�I�J�K�L�M�N�O�P�Q�R�S�T�U�V�W�X�Y�Z�[�\�]�^�_�`�p�q�r�s�t�u�w�x�y�z�{�|�}�~������������������������������������  �v                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            �]        �\    �e�f    �g�h    ����      �d�c                  ��  ����              ��                                                                                                                                                                                                                                                                                                                                                                                                              ��                                    ��                    ��                  ��                                                                                                        �T�U�V�W�X�Y�Z�[�\�]            ��������������������                                            ��������                                                                                                                            ��  ��                                                                                      ��  �݁�      �ށ�    ��          ��                ��    �假����        �a  �ȁɁ������  ��          ����              ��                                        ��                          ����        ����    ���                                            ����    ����                                                          ��                                                  ��                                                                                                                                                                    ��                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          �@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O�P�Q�R�S                                                                                                                                                                                                                                                                                        ��������                ��    ����    ����    ����    ������    ��    ������    ��    ����    ����    ����    ����    ����    ��    ��                ��                                                                                                                                                                        ����                                ����                ����                ����      ��    ����                                                              ��                                          ����                                                                                                                  ��  ��                                                                              ��    ��  ��                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                �@�A�B�V  �X�Y�Z�q�r�s�t�u�v�w�x�y�z�����k�l              ��  ��                                                                  �����������������������������������������������������������������������ÂĂłƂǂȂɂʂ˂̂͂΂ςЂт҂ӂԂՂւׂ؂قڂۂ܂݂ނ߂��������������������              �J�K�T�U    �@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O�P�Q�R�S�T�U�V�W�X�Y�Z�[�\�]�^�_�`�a�b�c�d�e�f�g�h�i�j�k�l�m�n�o�p�q�r�s�t�u�v�w�x�y�z�{�|�}�~����������������������������������������������        �E�[�R�S                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    ����            ��                                                                                                                                                                                                                    ����������                                                                                                                                                                                    �e                  �i            �`      �c                  �a�k    �j�d      �l                    �f        �n                          �_�m    �b      �g          �h                                                                      �~������                              �r�s                        �o�p�q    �u                                                                    �t                ��                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    �꒚  ��      ����O�㉺  �s�^  ���N    ���������u��        ��    ��        ��  �L  ��    ��      ����      ��  �ےO  �嘥    ��    ���T  �v          �V  ����R          �h���昩��      ����    ��                            ��  ��                    ��  �T  ��    ����  �\��������  ��    �]��  �܈�    �j�i  ����  �������S��  ���喒  ��    ��������  ��    ��    ��      �l          �Y�m��  ��  ���w    ����  ������        �e�d�����t��      �W����  �M  ��߈�              ����  ��  ��      ����      �C�N      �O��  �P          ��    �ފꕚ���x                ��  ��`                                  ����      ��  ��  �L�Q�f  ����          ��    �A��          �ʒ�Z���C  ��  ���R��  �]�Øō�ƛC                    ��          �ј�    ��  ����        �͌�    �g      ��    ��  ��  �T��  ��  ��  ���S  �V  ��  ��  �U��  ��    ����                  �D  ������          �N��                ��    �W����        �E�r    �W��  �ܘ�    ��    ����  �ۘ�  ��  ��  �M  ���ݘ�                �C��      �o  �U��  ��  ��      ���Z          ���    �q  ��  �{  ��  ��|  ��  ��    ���      �[��  ���Y��l�㌑  �����Ϙ�`                ��    ��            �X  �^��    �\����          �Θ�        ���      ��  ��                ��            ��      �]  ��  �����  ��        �U    ��        ��              �T      ��    �_      �P����                                  �×b        ���B����  ��            �X      �C    ��      �@�A    ��  ��  ��      �l�D  �a  ��      �E        �H  �F  �m          �G�I          �`�K      �J  ��        �V�M�N  ��        �L                ��  �Q�P�O  ��  �R        ��  �S                �D              ��        �U    �T�W�V    �X�Y��  ���Z�[��������b���[�Ɠe  ��  �Z  �\          �}  ��          �]  �c��    �S�_�`�����Z�a    ��      ������T      ��      �b  �c    ���~    �f��  �e��  �g��h�`�i  �j�k��  ��      �d    ��  �n  �l���m  �y�o�p�q�~      �u�s�t�r��v���          �w�e          ���x�y    �y  ������                ��        �z꣋�    �{�}        ����  �}��  �f�~    ���M      ����  �ʉ��o    ����  ��    �n��  ���؊�  ����    ��    �Y    ���g  ��          ��            ����  ��  ����      ��  ��    ��    ���������h��              �䙍    ��    �홎���O  ��        ��  �U        ��    ��        ���ܔ�      ����        ���虛�������n              ��  ��      �c      ������      ��      ����  ��            ���h    ����    ��    �i    ���w������  �[  ��    �J��      ��    ��  �N  �j��  �u  ��  �E  ��      ��        ��    ��  ������  �k  �����噫  ������  ����                    �M��  ��    ������      �����l���    ��m��        ��  ����        �����k  ����    �x    ����  ���n          ��        ��  ��  ��        ���C���      �����\  ��  �������ߙ���    ��      �ڑ��싦    ��P  ��  �m  ��  ��          �T    ��        �ƉK����o���p��  �ɉ�    ��      ��    ��  ��                            �p    ��  ��  ��        ����        �Ι�  �~�X      �}��  ��  �q��    ��        ��            �Q��        �����y�F�o����          �f  ���  ��  ��  �r  ��  �b�p���Ë�    �ْ@�������ڙ؉䎶�j�E    �����i  ��            ��  �h�e      ���g�݉D�����@���f��                  �N  ��  ��i          ��    ��  �ܙߙ���              ��  �z��  ����݌�  ��  �C      ��  �����      ��    ��                          ��                ��  ��          ���  ��  ����      ��Ė�    ��      ��  ��      �u��a  ����  ��                  �t          ��  �B��    ���v  �@��    �]    ��P        ��      �D���C  ���i�A  ��    ������                            �E                ���N    �F�G  ����      �L�K      �N              �M    �J  �w        �S  ���O              �H��      �I  ��                                              �S�B  ��  �Y        �X�O        ��  �P      ��U��          �R    ��      �[    �V�W        �T�Z          �Q                                              �`�e  �a  �\    �f�P  �x�h  �A�^��                        �b�[��  �슅�c�_              ���i�g�r�i��  �d  ��          �c                          �m�k  ��                        �p          �j  �n    �l      �k�o                                    �r  �w      �u�t              �Q    ��                    �q  �s���R    �v                          ��          ��  ���}  �{  �|  �~                  �\                  �X  �x  �y                    ��                ��      ��  ������              ��      ��  ��          ��          ���d    ��        ��        ��                      ��  �X    ��                ��          ��  ��          ��      ��������        ��          ��    ��  ��      ���d  ���l    ��  ��    �c                    ��  ��  �͐}          ����    ��  ����    �ޚ�      ����  ��  ��  ��    ����    ��  ��      ��    �y            ������        �\    �n            ����    ��        ��  ��        ��    �V      �������B              �y              ��    ���z�R    ����                                        ��    ��          ����  �^              ��                        ��  �C�_��          ��  �{      ��    ��                        ��    ��    ���}�|    ��    ��      ������  ��          �W    ��u    ��                                ��    ��  �|��  ��      �x  ��    ����      ����                  ��      ��      ��      ��    ��          ��        Ꟊ���    ��g        ��    ��    ����                ���          �Y��  ��    �h������      ��      ��            ��  �U        ��  ��    �o      ��        �m        ��  ��                          ��      ��        ��  큚�                �n    ��    ��      킕�        �՚ϚҚ�    ��    ��      ��  �d    ��  ��        ��  ��  ��  �ښܚ�    ��  �Ӛ�        �ߚ�          �m�p  �s�ᐺ�딄        ��  ������        ��            �Ϛ��      �Ě�        �[�O  �Ǐg�����          ��    ��  ��  �V���v��    ����        �Κ�          ��          ��    ��ޕ�        ���t��_  턖z��  ����  ���  �    ��  ���  ��  �������D  ��  ��        ���z      �@        �D      �A�@�ܖ�          �D    �J          �W    �d    ��  ��  �B          �E툑�    �W      �i          �F            ��퉍�    ��              �G    �o  �n        ����  ����        �K�L  �I                �W��  �H  �ÕP                    ��        ��      �p  ��  ��          �Q              �O            ��  �R  �P    �N�P        �M      ��          ��          �V�W          ��      �S�K        �k    �U                                ��              �X      �w      �Y  �T                                    ��                                    �}              �Z�Q                                                                �[�_�\    �ś^            ��  �]��      �k          �d�a                  ��  �`    �b    �c                                �e�f                          ��  �h�g                  �i                      ��              �l  ��      �d  �j      �m              �n  �q    �o  �p                    �q�r    �E�s튎���  �t�u�y�F  ��      �G�Ǜv�w    �w  ��        �x��  �y  �z    �{  �}          �~    ��  ��  �F���  �v����  �G          ��  �@�����舶�X��  ��    �q�鎺�G��              �{  ��    �Q������  ���e          �h�  �⛃��Ж���  ��    �x      ��  ������      �    ��  �Q���@  �Ǜ�  �������J�ːR  ���  ��  ��    ��  ����  ��  ��      �Ύ�  ����  �˛��������ё��q  ������  ��  ��    ��      ��      �  ��  ��  ��      ��        ��      �A            �����ڐK��s���A�Ǜ�      ����  ��  �͉�  �r��������  ��  �W                ��  �j��    �w��            ��  ����  �R        ��    ��                                    ��      ��    ��                        ��        �  �Z��  ����        ��  �x    ������  푛���  ��            ��  ��                                  ��            ����            �㛴��    ��  ����        풓�      ���s  ��                  ��      ��    ��    ��    �����R���śěÛ�      ��    ��        �  ��                                                �                �ɛ�  ��  ��  ���                ��                        ��    ���  ��      ��    ��                      ��  ��    ��      ����      ��                        ��        ��                  ��  ��                ���홗�  �כ�                      ��    �ޛ�    �  �ۛ�    ��        ��  ��B    ��  ��  �H���I��    ��    ��    �țߖ��b��  �J      ��  �F��      �s�z    ��        ���        ��        ��    ����  ��              ��          �t  ��  �ыA    ��    ����        �X    ��    ��蕝  ��        �y  ��          �햋  ��              ��  �����                          �����N���  �K���􌶗c�H����  ��  �L��    ��    ��        ��          ����X    �M  �{      ��          �x��      ��  ��              �����N�f                �����p        �����L        ����    �f    �@      �C�D  �B  �_���F�E�A        �G�H    �I      �L�J  �K�M  ����N  �����U  �O��  ��  �P�M        �Q���T����  ����U  �|�����V���O    �o      ��  �      �팷��  �W      �X  �^  ��    휒�  ���Y      �J  �e    �Z      �K    �[  ��  �\  �]    �_  ��    �`�a  �b    �S�R      �c�`      �F�  �ʕV���j�d    ���e  �e      �f  ��    ��    �i�����h�g�a��  �m�k  �j����      ���l�k�]      ���p�o        �n  �q��            �r���z    �s��        ����    �  �O    �t�J          �S  �K            ���E                �u�u�Y�Z    ���z�  ��      �w            ��        ���y      �O    �x    �v  ��  �|                            ������  �{    ���|    ��  ����v    �Ӝ}      �}������������      ��  ��                ��            ������    ��      ����  ��    ��  �P    ��      ����    ��  ���~  �������p    ������������  ����        �b  ��                  ��  ������      �������        ��  ��  ����    ����      ��I    ��    �x��  �Y��              �ߜ{������  ��      ����              ���                  �f  ��  ��    ��  ��  ��  ���Ҝ���  �y      ���S              �Ĝ����z��  ����  �䜷��        ���D  ��    ��  ����      ������  ��      ��        ����      ������          ����      ��      ��      ��    ��        �Ĝǜ���    ��  ��    ����  �ԍQ���T        ��  ��    �̜͜�    ��  ��    ����  ��  �d�S    ��    ���шԜ�  �ʜМ׌c��            �|      �J        ��    ��      ��  ����    ��  ��  ���؜�                  ��    ��  �e  ����  ��      ��      ��      ��      ��        ��    �荧�������    ��                                    ��    ��                      ��  ��  ��匜  ��  ��������              ������  �����^  ���������  ��      �ʜ�  ���@��  �A        ��      �B      �C�Y�D  �E�F��      ��    ��      �[���G          ��绔�  ��  �˝H        ��  ��    ��    �K    �I  �L    �J        �M          ��    ��        �}    ��    �N  �Q���Z  �O�V��        �P�c            �}�R�S�W���T�R��    �e��  ��              ��        �❫        ��      ��      ��  �Z����        �c    �S�]�d�_�f�b  �a��  �[���Y����U    �X�S��  ���`�q    ���g                    ���@�h�m  �i  ��  �n�A��            �E�\  ���k        �w�l��    �g        ��              ��          ��              �j��    ��      �U                    ��    �ҝp�}                  ��    �J�q  �s�o        ��  ��        �{                    ���̝�  �~    ��      ��      �x��    ��P        �v    �|        ���{    ��  �u�z    �r      �t  �@    �|      �|���̒T�y  ��  �T�����[�w�d          �f  �͝}          �~    ��  ��    ����  ��    ��          �`��  ��      �K      �g��          ��  ��          ��        ��          ������      �h                      ��            ��  ��      ��    ����        �r                  ��  ��      ����            ��  ��      �g      ��      ��                      ��                  �E              ��            ��  ��          ��            ��  ��  ��                ��        ��                  �T��  ��        �Q    ����          �P��      ��  ��  �d�B  ��  �o            �h  ����        �i��    ��  ��          ����      ��  �^      ��  ��          �����F��    �C��        �[    ��  ����  ��  ��      ��    ����  ��        ��                                    ��      ����          ����          ������    �x        ������������  �U    ����          ��    ��        �����q  �~      �Ýs�ŋ�      �ǝ�      ���U    ��          �h      ��  ��  ���G  �~��                  �ʝ�      ���|��    �k  ��  ���          �l  ��  �͎�    ��  ��    �Ґ�  ��      �ώa�f  �z�V            ��  ��    ���{      ��  �ѝԗ���        ����    ��    ��        ��  ��  ��        �ٝڊ�    ���U���|��    �{��      ��                ����        ��  �V��    ����  ����  ��  ����      �Ր���            ��  �����f      ���t  ����        ������  �G    ����        ����    �E  �莞�W��        ��  �W      ��    �N        ��  ��      ����    ��  �����A����        ���i��    ����  ��      �q            ��  ���    �ɝ��        ��    ��        �g�Ý���      ��    ��  ��      ��        �b    ��      ��  �\      �A��    ��  ����  ��    �@    ��  ��                        �B    ���C  �j��    �D          �F    �G            �H  �ȉg�X�I  �J�������J�֑]�\�֍�    ��        ���L  ��  ���ÞK        �񒽞L�N      �]  ���M��            �N�O��  �����{�D�Q    ��    �p  �S�V�U  ��    ��  �R  �T        �W    ��        ���Ǎޑ�  ��    ��    �Z    �m  �X���Y��۞[�\����      �a    �Y  �t�^���ܝ�  �n  �f        �`  ����          �f  ��  �]  �c�b      ��        ��  ��    ��  �ʎ}    �g�e��      �d    �_          ��      �k�i  �˞g�m�s  ��        �ȑ�    ��  �u      �A      �t���^��  ���_      ��  �M    �p�o      �q  �n    �v  �l    �j  �r�h  ��  ���č�          ��    ���`  �ɒ̓ȉh                            ��    ���I            �x    �Z��            �z����            �}  ��      �j��    �i��    �{���j����  �y  ��        �|�~  �ˌK�Ǌ��j        ��    ����  �V      ��      �O                        ��  ����            ����  ��  ��  �~              ��  ��      ����    �[      ��  ��  ����  ��      ��旜        ��  ��B��  ��  ����    ����  ��              ��  ��  �H�Ǟ���  ��  ��    �_  ����  ����  �I        ������  ��      ��            �X��    ��            ����          �o��    ����    ��    �����A�Ş�    ��            ��������        ������  ����  ��  ��          ��      ��  ��    ��      ��  ��                    �k                ������      ���^  ������  �ힾ��          ��  ��  �ƞ��|      ������  ������    �O�y��    ���T              ��      �|    ��    �P��    ��    �Y��      ��            ��            ��    ���  ��            ��    �ɞ�  ��  ��      �    �̍\�Ƒ���  ��    ��        �l��      �͞�      ��        �ߞ�    ��  ��        ��            ��  ��  ��  ��    ��    ��        ����          ����    ��  �W  ��    �⏾  �͞���          �����~    ��  ��        ����  ������    �M            ��  �Ӟ��    ��                        �k��          �@  �ɞ�      ��        ��            ����        ��          �Պ��h      ��                ����  ��            �@        �w      ��  ����            �K  �G  ��        �F        �E    �B          ��D�C                          �I  �E            �L��    �H�J    ��  ��      ��  �M                              �Q�N                ���O        ��              �R      �S            �T  �U����  ��      ��                    �~        �W�V�Y�\    �Ԋ�        �\      �[  �]    ��  �V  �^    ���`        �_  �a      �b  �c�~����  ��    ���c        ��      �Η�      �d�e  ��      �f�g    �i�h  �w    �}��c  �j              �l�B  �k          �m          �n          �o�p      �q  �s�r�t���i  �u    �E�k�v    �a��        �B�w        �x  �ꖈ      �şy��  ��  ��    ��      �z                      �|�{    �~      �}                                        ��            ��  ��  ����    �C      ��              ����                              ��    �X�i          ���ْ�`��                      ��  ��        ��  ��    ��  �ړ🇍]�r  ��          ��  ��        �ܑ�  ����            ��    �D��    ������    ��  ��      �ן�    ��  ���B    ��    ������          �v��                ��    ��    ��  ��        ����������������  ��    ����      ��  ��            ��  �@  ��  ���ݟ�  ��      �A�g��  �D    ��  ��        ���ן�  �j                                ��            �m��          ��        ��  ��  ��    ����          ��      �k�^��            �F��  ����  ��    ��  ���h    ��    ���                                      ����  �l            ����  �Y    �_�Q  �\  ����        ��    �C�Z��                      ��  �ߏ�      �O  ��        ��  ���@    ��  ����                              �A    �U    �t    ��    ��      ��      ��        �Ɵ���      �ҟ�    �B  �i��    ��    ����        ��    �W    ��  ��  ��  �ˈ���  ��    �[�D�~  ��  ���C���ǓY�E                ��  ���Ϗ��a              �k  ��      �Џ���  ��  �ً��n  �ԟ݈��Q�H  ��  �֑��͟ύ`                ���F��  �I  ��        ��            ��    �؟�              ��  ��    �X�G    ��              �N      ��    �Γ�    ��      ��              �p����  ��                  ��    �팹          ��  ��      ���a  ��    ��    ��        ��        ��    ��      �n��    �M    ��  �J    ��  ���      ��  ����        ��  ����              ���                          ��    ��    ��  �H    �B��          ����  ���Y      ��    ��          �R  ��  �A����                    ��  ����              ����        ����          �Q          �@��  ��      ��                            ��      �N    �I��    ��        ��  �R            �K���H��      �k      �E  �D  �M      �G�F�L  ��  �C  �K          �O    �P          ��                  �U  �T�V          �Y            �b  �S  �L      �W            �����Q�Z    �X                          �]�[    �^    �a      �Z���G    ��            ���\  �`��  �_  �J  �M�      �d      �h    �f      �N  �O  �b  �c      �g  �e      �m    �m  �j�i  �l���n            �����P      ��      �o  �q                      �p                          ��        �r            ��                    �s              ��      ���D              ��      �܍�              �Q      �F��      ��      �u            �t                                  �R�x�Y�{�v      �z        �y�_���F                        ��    �}      �G                  ��      �~  �|                                  �w              �B      ��            �T        ��          �S        ��        ����  ��        ��        ��                              �R          ��                  �V�W  ��    ��  ��            ����    ��    �U          ��  ��������  ��    ��  ��                            ��            ��      ��  �F        ��        �o��      �          �n                ��      ��        �M              ��        ��    �Y  �R        ����        ��  ��  ��  ����  ��              �z��        ���W��        ���C��            ��      ��  ����  �Z�            ��            �    �                    �                        �  ��  ��    �  �    �ݕ�      ���ઑu����          ୕Д�    ஔv          ��          ௉�  ��  ��  ��  ���S        �q  ��                ��  �        ��      ���  ����        �                    �      �                  �]  �        �        ��    ��  �[�      ��    �        �\      ����  �              �  ��  �        ��  �_  ��        ������            ��    �Ƌ�                  �ĒK��    �T��                        ��                      ����      ������  ��        �]��      �͒��L    ����        ��  �P�Q            �ω�        ����                ����              ��                      �b        ��  ��          ��  �l    ��  �_��  ����                ��    ��  ��  ��                    ��                                    ��                ����              ��  �`    ��  ��          ���a�X    ����      �H      �b              ��  ��    �c  ��        �]    ����    ��      �J    ��          ��        ��  �䗝�I  ��                                                ��    ���K    �M�L      �N      ��ԋՔ��i      ��        ��  ��                                      ��      ���l��  �����  �O���        ����        ����    ��    ��              ��        ��          �P  ��                                    ���Q    ��        ��                ��                        ��                        ��        ��        ��              �Z      �@  �Z�A    ���B  �C        �D  �F�G�E      �r�I�H                �R  �K�J�L            �M�O�N    ��  �Q  �P    ��  �r  �[  �R��      �Y  ���S  �p    ���T    팓c�R�b�\      �j��  �����U              �V  �[    �Y�X���E�W  ��  ��    ��        ���\�Z�{��    ��  �L  �^���l�_  �]���`  �a  �S��    ���f  �c���b            �E    �i      �d�e  �h�g�D    �a�`  �^    �j          �k    �l          �n  �m          �u          �v���p  �r    �t�]    �u�s��      �o�q  �a  ��    �x    �w        �y  ����    ���z  ��    �|      ���{          ��            �  �ᅒs          �  �  �}�~  �              �  �  �                                  ����  �    �                �      �            �            ��      ���      ��          ��      ��  �      �        ��        ����  �      �  �      �  �  ���oᢔ��S  �  �TᤓI  �F�c�    �    �  �H    �    �    ���W�U  �V              �X              ��  �      �    ����        �M    ᱔u    �~  �m  �v    �        �      ᳓�      ���X  ᵖ�  �  �Ĕ��  �    �      ��      ��  ��      ��    �    ��    ��    �    �ἔ�  �Ō�                            ��    ���^��      ������    �                          ����  ��  ��      ��          �Z��                                    ����          ��  ��  �̖r  ��    ��                          ��        ����                      ��    ��    ��                        ��  ��        ��            �u��    ��    ��    ��    ��  ������  ��              ��          ��                  ��    �ߖ���          ����  �m  ��  ��      �Z�⋸      ��                ��          ��                  ��          ��  ����                    ���\      �u�ԋm                    �C  �j          �v        �{          ��                �]                            ��            �^            ���d    ��    ��  ��          �_  ��        ��        ���        ��V��    ��  �O  ��  �q    ��                ��      ��  ����        ��          ��        �m  ��  ��    ��      ����      ����        ����    ��          �A                        �@��      ��    ��        �C                �B      ��          �D            �b    �F�E            �G                        ��      ���I�H      �`                  ��  ��  ��  �J�V          �_�F��            �S    �P  �O�c�L    �N    �j�_�M�K  �I    ��    �[        ��                  ��    �Q        �R�h��    �\�T        �S    �В���        �d            �f  �T                ���U    �W      �X  �H    �Y          �Z�[    �׉ѓÏG��              �\  �H          �ȕb    �]    ��            �d  �`  �a��  �`�^  ��    �_      ��                    ��        �H              �b    ��  �c��          ��    �B�d�e�t  ��    �g�f                          ��    �i��        �l      �j�Ҍm�k�e��  ���m    �s    �o      �ωn����            �n                  �p�q��          �r  �n        �t      ��  ��    �u��    �v  ��  ��  �ލ�      �w                  ����  �y�{�x�z            �A                  �|�E      ���q�~          �      �M        �      ����  ��}  ↗�  �  �  �g���  �      ��  ���  ����⏏v  ����h    �G�j  �  �[�          ��  �^�|��        ��    �  �  �  ��  ��      �  ��            ��  �J    �  �}        �y��  �      ��            �  ��    ��                      ⤕M  ����  ����  ��➒}��  ��  ��            �              �  �        �  �  ��    ��        �                      �͉�      �  �  �    �  ����  �Z���  ���k�  ��                �\    ��      ��    �      ��              ���    ��  ⽕�  �z  ��    �                          �    ��      ������    �      �U          ��    ����                ��            ��          ��      ��������    ��              ��  ��  ��      ��    ����                      �є�        �ӗ�����    ��                �Ԑ�  ����      ��  ��  ��            ����      ����            ��            ��  ��                ��    �̌H��          ��  ��  ��    ��  ��    ��  �e�S    �l      ��  ����  �㊟  ����    ��  ����    ������          ��      �  ��  ��    ��        ��      �W      ��      ��  ��      ��  �����f  ��        ��              ��    ��  ��  ��  ��  ���n    ��  �I  �@  ��g��      �C��  �[    �R      ���B  �эh�������A      �f�a��                ����  �F�ݍ�  �G�a  �I      �Ѝ�        �H    �I���g�D�J  �m    �E�o  �M�Q��          �L        �U�n  �i    �����R    ��  �O          �P    ���N�K  �G��    ��      �W                      �T          �V      �S          �p���X��    �e�p  �a�[              �_�����Z�b�f�j��  ���\  �o�d  �Y�]  �^����              �]    �ٔ�      ��  �Ώ�    ��q  �g  ��  �c�h�j  ���m    �i      �Ҋ�    ��    ��    �l  ��            �k          ��    ���n      �u�o�v            �r                ��    ���t  �q�w�p    �c        �D    �k    �s�    �{  �~  �|��z  �`��    ��  �}    �x      �@�q  �J        �r  �D�U�    ��    ��              �y�  ��    ��    �J                �  ���  �    �[�        ���@  �  㚓Z�  ���  �        ��                                                                                                                                                                                                                                                                                                                  ��  �  �                    �  �s        ���  ��    ��    �            ��            ��㫍ߌr    �u  ��  ��    �l  ��㭜�                ��  �����  �r  �  ��          �          �    ��    �t  㸌Q      �A�`        ��    �      �  ��      �H      ��      ����      ��  ��          �K  ����                    ����        ��    ��  ��        ��    ��          ��  �|��      �s�V  �l�̎���        �͎�      ��  ��    �k  ������    ��        ��            ��                    ��    ��        ��  �^  ��            ��      ��              ��      ��  ��  ��      ����  ����          ��            ����  ���ޒ�  ��E  ��      ��W��        �����攣  ��  �]��            ��    ��  �I  ����  ��      �Ҏ�    ��      ���b  ����  �m  �n��  ��          �x                ����  �_          �w  ��              ��    ������  ��E    ��    ����                  ��  ��    ��      ��      �E�\        ��    ���Ƙe������                              �r��              ��          ��          ��  �E  �]          ��        �B              �A        ��    �t  ���D  �C�o�r                  �T          �H�I        ��    �G  ���F    �J      �����B        ���N  �O�K        �L  �M        �p      �U  �Q        ��  ���G    �P    �S�R      �c�V            �W    �V  �X    �Z  �^    �[�Y�^�\  �]      ��  �d�_      �`      �a  ��        �c�b�e        �f�g    �b  ��  �h��  ��    �L          ���v          �i�j�P  �k    �l�m    �n  �o�����p  ���q��  �r  ��      �s�܊�    �C�w  ���M                  �t�q�u��  �        �w  �ǔ����v�D            �x            ��                                �z�y�|    �{  �}    �  �~  ��  �  ��    ����  䅐F      ����          �                        ��  �        �            ��      ��  �          �H��        �䎔m  �c  ��  �F        �|��  �  ��              ��                      ��䒗��    �c  �  ���  ��  �  �  ��꒗      ��          �p  ��        ���          �v��䗉֊��    �        �s              ���      ��            �        ��    �      �  ��  �䟒�  ���            �        �      ���t        �`�  �r          ��                  �w                                �  �  ��      ���    �x          �  �  ��      �        �    �      �      ����  �          �  䮔�          ��      �              ��      ��      ��  �y    �e  ��  ��        ��    ��  ��      ��    �p��                ��  �      �،ԕH��  �  �z��      ��  ��          ��    ��      �ĖG�ʈ�        �                        ��  ��            ����  ��        ��      ��    ��      �ӗ�                ��  �{�t        ��                ��      ��          ���ⓟ    ��    ��  �ב�������  �K      ��  ��  �ߕ�              ��  ��            ��        �N      ��        ��    �f    ��  ��                      ��        ��  �|      ����  �葓    ��  ��    �~  ��    �u��W  ��    �ꖪ        ��    ����  �D                              �H  �@          ��              ��    ����          ��                    ��  ������  ����  �U        ��  ��        ��          ���              ��              ��    ���@  ��        ���Ԏ��B    ��        �}  �C  �����~��                ��        �n�����  �J                  �P            �Q  �D      ��    �N�F  �H          �R�G    �K    ��  ��  �L�O              �E  �E  �I�F�d�O��  �����                �V�T            �m              �S      ��  �U�W        �X            �[�Y            ���Z      ���M                        ��  �\�a��    �`      �A      �b�h    �]�_              �^    �P�A    �d              �c                    ��  ��e                            �f                          �g��  �s      �i�|        ��  ��  ���j              �k      ��          �l              ��  ��                            ���q�r            �m  �\                          �n�a        �o�p�z      �t�w          �s                          �u  �v��  �x  �`  �u�a          �{        �^  �    �|�        ��        �}    �~�g���                ���  �    ��  �  �I�    �  ���    �      ��          �w  �  ��                �      �                    �    �      �      �                  ��  �X�  �        �  �I  �  �          ��    �    ��  �  �      �          �  ��  �            ��    �                    �Z                                  �    �                �      �      �            ���  �    �      �  ��      �        �  �                          �                            �    �      ��  �I  �a    �            �  �          ���  �      ��                    ����y      ��                  ��        ��    ��  ��        ��  ��  ��  �O          �s��        �ȏp      �X  ��  �q  ����    �t�ˈ�        �\    ��        ��  ��    ��  ��          ���΋�  ����          �U    ��  ��        ��      ����  ��        ��      ��  ��            ��    ��  ����    ����  ��              ��  �ٗ�������                  ��        ��T    ����    ����  ��  ��            ��                  ������    ����    �琻��      ��  ��    ��    ��  ��      ��  �J��                �A����            ��        ����                    ��  ��    ��          ��  ����              ���                ��              ������      �A  �@      �C    �B  �D    �P  �E    �F            �G��  �v  �H    ���e�I  �J��      �K      �K    ���`�L  �o            �M        �O��  �N�e  �P    �Q    �R��            �S    �T  �U�V                                  �p              �W  �X�Y          ��    �G�Z                        �[      �\              ��  ���]        �v  �u  �`  ��  �_  P    �^���L    �a  �b  ��      ��  �c        �K    ��      ��  ��i  �d�    �f����        �e        �h  �i              �����g  �ٕ]          �f    ��  �r  �m�w    ��    ��  �l�l�k�F  �l�b�Y��          �    �j          �o  �p�n  ��  �_    ���F      �s  ��  �a    �U  �v      ��  ���r  �w���t�u��q      ����    �N  ��            ��    �b  �    �z  �x    �k      �����y  �z    ��      �_      �{懒�  �����  �  ���~      �|  �@��    �  �}    �慏�  ��      ��  �d�y��  ��    �        �  ��  �      �  ��  ��抍u  ��    揗w        �  �    擕T            �          ��        �    �              �    �  ��      �    �  ��  �朕�    �            �x        ��    桋c㿏�  �    ��          �  ��    �]            ��  �  �  �Q  ��    �    ��                                                                                                                                                                                                                                                                                                                        �J    �        �  �        ��  �  �L  �  �  �        �        ��            ���              �����                      涕^�  �          �    �      ��  �e��          �      ��        �L��  �����v        �n�ݔ��Êѐ����ǒ���  ���ƋM  �Ȕ���    ��\��  �f���ʘG���d    ����  ��    �ڑG    ��  �o            �͎^��  ��  ��  ������  ��      ��    �q    �      �          ���Ѝw��            ����  �ԑ�  �ӊ�  ��  ����  �����  ��                                                                                                                                                          ��  ����      �q  ��    ����  ����  N                  ��      ��        �z                            ��                  ��        ��                    ��            ��      ��      ��                ����    ��            ��      ����  ��  ��  ��  ��        ��  ����      �H      ��  �H            ��    ��                ����x        ����                        ������                    �H          ��      ����                        ��  ��    �@�D�A��  �B      �C        �J      �E          ���G    �I�F                          �L  �R  �K          �M        �N    �Q�P  �O    �S�R  ��      �U  �T�V        �W              �Y                �X�g�Z    ���[�]                        �^            �_�\  �`  ���a�O�R  �    ��                �b      ��    �]�c              �f                        ��    �e�d�y�g        �r  �i      ���h  �q          �k�m���j      �l  �p�n�P  �o            �r    �y��        �S      �s        �A�u  �t    �x�`    �w  ���v�{    �z    �y�Q�|                �}        �~    ��  �D���                                                                                                            �h�  ���      �      ����        ��燒C�J�_        �    �Ӓҍ�    �H    �I  ���v                �}    ��    ��          �              �    犉�    ��猔�  �R  獏q      �    �����    ��    �ޑ�  ��  琋t        �  �磓����  ���r�瘐�  ����    ��痑���畈��A      �            ��    �T�i    ��  ���    �N  �    �ِ�    �x  ��  礗V�^  �Չ����碓��B���  ��    ��  �  ���k  ��  �y  �穓K      �����    �    ��竑J�I  ��  ���  �����ℊ�    �  ��        �  �W                                  ��    �M  �  ��        �  �      �    �@                ��                �x      �Y                        �    �    �S�  �      ��        �s              �X  ��          �s        �                              �    �      �                          �          �A    ��  ��                                            ���U�ޔz��      ��  ��  ��  ��                  �|��  ��      �Ǘ�  �V          ����  �y  ���_                  ��        ��  ��  ��  ��    ��  ��        ��        �X          ��  ��          ����      ��        ����    ��  ��          ����        �΍ю���  �ח��d����؋�        ��B  ��܊��j���  ��  ���t��          ��            ����          ��    ��            �      �    �݊b  ���    ����                ��                    �n    ��              ��    ��  ��  �    ���      �S��    ����  ��    �  ���          ��  ���    ��      ��  ��  ���                  �z          ��          �g  ��    �e  ��    �C                �L  ��  ����  ��  ������                    �          �K                  ��  ��                                          ���  �N�  �  �  �            �      ��    �  ����    �s        �e��        ���I��|    ��    ��      �K                ����              ���@�B    ���  ����A�C  �  �d    ���B  ����    �^    �E        �D�F                ��      �B    ��  �t            ��  �K��      �b�G      �H                      �L  �J  ��        ��            �I  ��                          ��              �O  ����    ��                  ��    �Z        �M�N��  �L                �P                  �V    ��  �Y              �X�L        �Q�R�U        �W��    ��    �Z�T    �S                              ��                    �^      �_                �`    �]�\      �����[            �d                  �b          ��      �c�a  ��  �e            �f    �h��    ��                ���g��            �s�i    �l  �j  �k              �m          �o        �p  �q        �t�r�u�w  �v                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          ��                ��  �x�M      �y  ���z�J      �[  ���̊��{  �|  �}�~            �  �֊t�}��  ��        �        �{            �  ��  �        �      ��    �  ��            ���  ��      �        ��    �                                                                                                            ��        �            �  ��      ��    �h                �j      ����  �  ��            �虍~  蚌�                    ������    �@�w�����      ��  �      �A  袒�  �˓�蜗�  ��    �z              ����  �G  ���@  褊K��        �u�  �襌�  �ۏ���    �B    ��      ��  �        �����  �  讗���  �ǔ�      ����    �Y��W��  �  貎���    �G      ��    ��  ���          ����        �J  �Ꮄ        ��  �_      �뗋  �  �d        ��      �  軐k�  ��    ����  �  �    ��    ��    ��  ��          ��    ��    ��          ��  �I��        �P��  ��  ����      ������  ��  ����      ��  ��  �֐�    �ז�    ��    ��  ��  ���r��  ��  ��  �Ҋv  ��  �x      ��    �C        ����  ��        ��    ������        ��  ��  ����              ��      ��      �f    ��    ��  ��    �  ��          ����                            ��    ��  ��    ��              ��                ��                                ��B      �쉹  ����        �C      ��  �Œ���  ����  �{      ��    ��a��Г�      ����  �z            ��    ��              �j��            �o    ����    �p����                ��        ����z�{��        �猰  �؊�    �^    ��            ��  ��      ��      �����@  �B�A                                                                                                      ��  �C        �D  �E        �F                        �H�G  �I                                        ����    �H    �Q            �J  �K  ���Z��    ��  ��              ���O��        �L  ��      �M�{  �a      �`  �N���O      �P        �R�S  �U�Q    �T    �܊�      �V  �W                            �X�Y      �Z    �\      �[  �^�a      �]�_�`    �b  ��                                                                                                                            ���c�d��        ��            �e    �]      �n�f�g        �y��              �h        ��    �ʉw��  ��              ���m��    ��    �l    �j  �k  �i    �w                    �n�o    �p�q          �s    �r      �x  �t      �v                �R�u    ����          �x                            ��    �y        ��            �z            �  �}  �|�~  �{              ���            �  �    ���      �    �  ��      ���                                                                                                                        ��        �    �              �[      �      �      ��                    �  �  ��      ����    ��  ��    ��    �      ���  �E��  �    �    �      �                    �                                  �  �        �    ��  �  ����      ��  �T�                ���S        �@���鮖�              ���  �    ��      �  ��                                        �D    ��  ���                          �                    ����  鸕��    ��              ��              �  ���L  ���N    ��    �        ��  ��        �          ��    ����        ��  ����  ��  �I        ��          ��������      �~              ������    ��                    ��      ��  ��  ������  �ӊ�    �k  ��������          ��          ��    ����              �h�و���  ��            ���ˉV    ��              ���ߒL                  ��        ��    ��          ��            ��                            ��  ��                                                                                                                                                                                                                        ��  ��  ��  ����      ��    �P��  ��                        ��    �����        ��      ��    ��          ��      ��      ��    ��  ��  ������                            ��    ����  ��    ��  ��  ��              �D�C              �E    �L�@�A  ����    �B            ��Q    �J��  �F              �K                        �H  �G          �{                    �L                  �M        �N  �I      ��    �O  ��      �S  �T�R          �Q�W  �P  �U                �V      �Y          �X                        �[            �\  �]    �h          �Z���    �^                                                      ���_�`    �a                                                                                                                                                                            �b    ���c      �d  ��  �e            �f    �g�h        �k�i�[  �j  ��          �l  ��          �m��    �n�p    �q                    �o���˖���  ����        ��              �s�o�t�u�v�썕  �w      �Җ�  ���x�z�y  �{        �|    �}            �~        �  ��  �  ���                  ��          �C        ��  �                    �l�                    �                            �@    �                      ��V    ����    �  �                    ��ꔗ��    ��    �  �          �      ��                                          ��              �            ��s    �                                                                                                                                                                                                                                                                                ��                                                                                                                                                                                                                                                                                                                                                                    ��                                                                                                  �s�~���������X�^�Y�a�b�c�e�i�l�u��������������������                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      �I�������������i�j���{�C�|�D�^�O�P�Q�R�S�T�U�V�W�X�F�G�������H���`�a�b�c�d�e�f�g�h�i�j�k�l�m�n�o�p�q�r�s�t�u�v�w�x�y�m�_�n�O�Q�M�����������������������������������������������������o�b�p�`    � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � �                                                                                                                                 �������P����                                                    ｡｢｣､･ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝﾞﾟ††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††　、。，．・：；？！゛゜´ ｀¨ ＾￣＿ヽヾゝゞ〃仝々〆〇ー―‐／＼～∥｜…‥‘’“”（）〔〕［］｛｝〈〉《》「」『』【】＋－± × †÷ ＝≠＜＞≦≧∞∴♂♀° ′″℃￥＄￠￡％＃＆＊＠§ ☆★○●◎◇◆□■△▲▽▼※〒→←↑↓〓†††††††††††∈∋⊆⊇⊂⊃∪∩††††††††∧∨￢⇒⇔∀∃†††††††††††∠⊥⌒∂∇≡≒≪≫√∽∝∵∫∬†††††††Å‰♯♭♪†‡¶ ††††◯††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††０１２３４５６７８９†††††††ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ†††††††ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ††††ぁあぃいぅうぇえぉおかがきぎくぐけげこごさざしじすずせぜそぞただちぢっつづてでとどなにぬねのはばぱひびぴふぶぷへべぺほぼぽまみむめもゃやゅゆょよらりるれろゎわゐゑをん††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††ァアィイゥウェエォオカガキギクグケゲコゴサザシジスズセゼソゾタダチヂッツヅテデトドナニヌネノハバパヒビピフブプヘベペホボポマミ†ムメモャヤュユョヨラリルレロヮワヰヱヲンヴヵヶ††††††††Α Β Γ Δ Ε Ζ Η Θ Ι Κ Λ Μ Ν Ξ Ο Π Ρ Σ Τ Υ Φ Χ Ψ Ω ††††††††α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ σ τ υ φ χ ψ ω †††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††А Б В Г Д Е Ё Ж З И Й К Л М Н О П Р С Т У Ф Х Ц Ч Ш Щ Ъ Ы Ь Э Ю Я †††††††††††††††а б в г д е ё ж з и й к л м н †о п р с т у ф х ц ч ш щ ъ ы ь э ю я †††††††††††††─│┌┐┘└├┬┤┴┼━┃┏┓┛┗┣┳┫┻╋┠┯┨┷┿┝┰┥┸╂†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩ†㍉㌔㌢㍍㌘㌧㌃㌶㍑㍗㌍㌦㌣㌫㍊㌻㎜㎝㎞㎎㎏㏄㎡††††††††㍻†〝〟№㏍℡㊤㊥㊦㊧㊨㈱㈲㈹㍾㍽㍼≒≡∫∮∑√⊥∠∟⊿∵∩∪††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††亜唖娃阿哀愛挨姶逢葵茜穐悪握渥旭葦芦鯵梓圧斡扱宛姐虻飴絢綾鮎或粟袷安庵按暗案闇鞍杏以伊位依偉囲夷委威尉惟意慰易椅為畏異移維緯胃萎衣謂違遺医井亥域育郁磯一壱溢逸稲茨芋鰯允印咽員因姻引飲淫胤蔭†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††院陰隠韻吋右宇烏羽迂雨卯鵜窺丑碓臼渦嘘唄欝蔚鰻姥厩浦瓜閏噂云運雲荏餌叡営嬰影映曳栄永泳洩瑛盈穎頴英衛詠鋭液疫益駅悦謁越閲榎厭円†園堰奄宴延怨掩援沿演炎焔煙燕猿縁艶苑薗遠鉛鴛塩於汚甥凹央奥往応押旺横欧殴王翁襖鴬鴎黄岡沖荻億屋憶臆桶牡乙俺卸恩温穏音下化仮何伽価佳加可嘉夏嫁家寡科暇果架歌河火珂禍禾稼箇花苛茄荷華菓蝦課嘩貨迦過霞蚊俄峨我牙画臥芽蛾賀雅餓駕介会解回塊壊廻快怪悔恢懐戒拐改†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††魁晦械海灰界皆絵芥蟹開階貝凱劾外咳害崖慨概涯碍蓋街該鎧骸浬馨蛙垣柿蛎鈎劃嚇各廓拡撹格核殻獲確穫覚角赫較郭閣隔革学岳楽額顎掛笠樫†橿梶鰍潟割喝恰括活渇滑葛褐轄且鰹叶椛樺鞄株兜竃蒲釜鎌噛鴨栢茅萱粥刈苅瓦乾侃冠寒刊勘勧巻喚堪姦完官寛干幹患感慣憾換敢柑桓棺款歓汗漢澗潅環甘監看竿管簡緩缶翰肝艦莞観諌貫還鑑間閑関陥韓館舘丸含岸巌玩癌眼岩翫贋雁頑顔願企伎危喜器基奇嬉寄岐希幾忌揮机旗既期棋棄†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††機帰毅気汽畿祈季稀紀徽規記貴起軌輝飢騎鬼亀偽儀妓宜戯技擬欺犠疑祇義蟻誼議掬菊鞠吉吃喫桔橘詰砧杵黍却客脚虐逆丘久仇休及吸宮弓急救†朽求汲泣灸球究窮笈級糾給旧牛去居巨拒拠挙渠虚許距鋸漁禦魚亨享京供侠僑兇競共凶協匡卿叫喬境峡強彊怯恐恭挟教橋況狂狭矯胸脅興蕎郷鏡響饗驚仰凝尭暁業局曲極玉桐粁僅勤均巾錦斤欣欽琴禁禽筋緊芹菌衿襟謹近金吟銀九倶句区狗玖矩苦躯駆駈駒具愚虞喰空偶寓遇隅串櫛釧屑屈†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††掘窟沓靴轡窪熊隈粂栗繰桑鍬勲君薫訓群軍郡卦袈祁係傾刑兄啓圭珪型契形径恵慶慧憩掲携敬景桂渓畦稽系経継繋罫茎荊蛍計詣警軽頚鶏芸迎鯨†劇戟撃激隙桁傑欠決潔穴結血訣月件倹倦健兼券剣喧圏堅嫌建憲懸拳捲検権牽犬献研硯絹県肩見謙賢軒遣鍵険顕験鹸元原厳幻弦減源玄現絃舷言諺限乎個古呼固姑孤己庫弧戸故枯湖狐糊袴股胡菰虎誇跨鈷雇顧鼓五互伍午呉吾娯後御悟梧檎瑚碁語誤護醐乞鯉交佼侯候倖光公功効勾厚口向†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††后喉坑垢好孔孝宏工巧巷幸広庚康弘恒慌抗拘控攻昂晃更杭校梗構江洪浩港溝甲皇硬稿糠紅紘絞綱耕考肯肱腔膏航荒行衡講貢購郊酵鉱砿鋼閤降†項香高鴻剛劫号合壕拷濠豪轟麹克刻告国穀酷鵠黒獄漉腰甑忽惚骨狛込此頃今困坤墾婚恨懇昏昆根梱混痕紺艮魂些佐叉唆嵯左差査沙瑳砂詐鎖裟坐座挫債催再最哉塞妻宰彩才採栽歳済災采犀砕砦祭斎細菜裁載際剤在材罪財冴坂阪堺榊肴咲崎埼碕鷺作削咋搾昨朔柵窄策索錯桜鮭笹匙冊刷†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††察拶撮擦札殺薩雑皐鯖捌錆鮫皿晒三傘参山惨撒散桟燦珊産算纂蚕讃賛酸餐斬暫残仕仔伺使刺司史嗣四士始姉姿子屍市師志思指支孜斯施旨枝止†死氏獅祉私糸紙紫肢脂至視詞詩試誌諮資賜雌飼歯事似侍児字寺慈持時次滋治爾璽痔磁示而耳自蒔辞汐鹿式識鴫竺軸宍雫七叱執失嫉室悉湿漆疾質実蔀篠偲柴芝屡蕊縞舎写射捨赦斜煮社紗者謝車遮蛇邪借勺尺杓灼爵酌釈錫若寂弱惹主取守手朱殊狩珠種腫趣酒首儒受呪寿授樹綬需囚収周†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††宗就州修愁拾洲秀秋終繍習臭舟蒐衆襲讐蹴輯週酋酬集醜什住充十従戎柔汁渋獣縦重銃叔夙宿淑祝縮粛塾熟出術述俊峻春瞬竣舜駿准循旬楯殉淳†準潤盾純巡遵醇順処初所暑曙渚庶緒署書薯藷諸助叙女序徐恕鋤除傷償勝匠升召哨商唱嘗奨妾娼宵将小少尚庄床廠彰承抄招掌捷昇昌昭晶松梢樟樵沼消渉湘焼焦照症省硝礁祥称章笑粧紹肖菖蒋蕉衝裳訟証詔詳象賞醤鉦鍾鐘障鞘上丈丞乗冗剰城場壌嬢常情擾条杖浄状畳穣蒸譲醸錠嘱埴飾†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††拭植殖燭織職色触食蝕辱尻伸信侵唇娠寝審心慎振新晋森榛浸深申疹真神秦紳臣芯薪親診身辛進針震人仁刃塵壬尋甚尽腎訊迅陣靭笥諏須酢図厨†逗吹垂帥推水炊睡粋翠衰遂酔錐錘随瑞髄崇嵩数枢趨雛据杉椙菅頗雀裾澄摺寸世瀬畝是凄制勢姓征性成政整星晴棲栖正清牲生盛精聖声製西誠誓請逝醒青静斉税脆隻席惜戚斥昔析石積籍績脊責赤跡蹟碩切拙接摂折設窃節説雪絶舌蝉仙先千占宣専尖川戦扇撰栓栴泉浅洗染潜煎煽旋穿箭線†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††繊羨腺舛船薦詮賎践選遷銭銑閃鮮前善漸然全禅繕膳糎噌塑岨措曾曽楚狙疏疎礎祖租粗素組蘇訴阻遡鼠僧創双叢倉喪壮奏爽宋層匝惣想捜掃挿掻†操早曹巣槍槽漕燥争痩相窓糟総綜聡草荘葬蒼藻装走送遭鎗霜騒像増憎臓蔵贈造促側則即息捉束測足速俗属賊族続卒袖其揃存孫尊損村遜他多太汰詑唾堕妥惰打柁舵楕陀駄騨体堆対耐岱帯待怠態戴替泰滞胎腿苔袋貸退逮隊黛鯛代台大第醍題鷹滝瀧卓啄宅托択拓沢濯琢託鐸濁諾茸凧蛸只†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††叩但達辰奪脱巽竪辿棚谷狸鱈樽誰丹単嘆坦担探旦歎淡湛炭短端箪綻耽胆蛋誕鍛団壇弾断暖檀段男談値知地弛恥智池痴稚置致蜘遅馳築畜竹筑蓄†逐秩窒茶嫡着中仲宙忠抽昼柱注虫衷註酎鋳駐樗瀦猪苧著貯丁兆凋喋寵帖帳庁弔張彫徴懲挑暢朝潮牒町眺聴脹腸蝶調諜超跳銚長頂鳥勅捗直朕沈珍賃鎮陳津墜椎槌追鎚痛通塚栂掴槻佃漬柘辻蔦綴鍔椿潰坪壷嬬紬爪吊釣鶴亭低停偵剃貞呈堤定帝底庭廷弟悌抵挺提梯汀碇禎程締艇訂諦蹄逓†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††邸鄭釘鼎泥摘擢敵滴的笛適鏑溺哲徹撤轍迭鉄典填天展店添纏甜貼転顛点伝殿澱田電兎吐堵塗妬屠徒斗杜渡登菟賭途都鍍砥砺努度土奴怒倒党冬†凍刀唐塔塘套宕島嶋悼投搭東桃梼棟盗淘湯涛灯燈当痘祷等答筒糖統到董蕩藤討謄豆踏逃透鐙陶頭騰闘働動同堂導憧撞洞瞳童胴萄道銅峠鴇匿得徳涜特督禿篤毒独読栃橡凸突椴届鳶苫寅酉瀞噸屯惇敦沌豚遁頓呑曇鈍奈那内乍凪薙謎灘捺鍋楢馴縄畷南楠軟難汝二尼弐迩匂賑肉虹廿日乳入†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††如尿韮任妊忍認濡禰祢寧葱猫熱年念捻撚燃粘乃廼之埜嚢悩濃納能脳膿農覗蚤巴把播覇杷波派琶破婆罵芭馬俳廃拝排敗杯盃牌背肺輩配倍培媒梅†楳煤狽買売賠陪這蝿秤矧萩伯剥博拍柏泊白箔粕舶薄迫曝漠爆縛莫駁麦函箱硲箸肇筈櫨幡肌畑畠八鉢溌発醗髪伐罰抜筏閥鳩噺塙蛤隼伴判半反叛帆搬斑板氾汎版犯班畔繁般藩販範釆煩頒飯挽晩番盤磐蕃蛮匪卑否妃庇彼悲扉批披斐比泌疲皮碑秘緋罷肥被誹費避非飛樋簸備尾微枇毘琵眉美†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††鼻柊稗匹疋髭彦膝菱肘弼必畢筆逼桧姫媛紐百謬俵彪標氷漂瓢票表評豹廟描病秒苗錨鋲蒜蛭鰭品彬斌浜瀕貧賓頻敏瓶不付埠夫婦富冨布府怖扶敷†斧普浮父符腐膚芙譜負賦赴阜附侮撫武舞葡蕪部封楓風葺蕗伏副復幅服福腹複覆淵弗払沸仏物鮒分吻噴墳憤扮焚奮粉糞紛雰文聞丙併兵塀幣平弊柄並蔽閉陛米頁僻壁癖碧別瞥蔑箆偏変片篇編辺返遍便勉娩弁鞭保舗鋪圃捕歩甫補輔穂募墓慕戊暮母簿菩倣俸包呆報奉宝峰峯崩庖抱捧放方朋†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††法泡烹砲縫胞芳萌蓬蜂褒訪豊邦鋒飽鳳鵬乏亡傍剖坊妨帽忘忙房暴望某棒冒紡肪膨謀貌貿鉾防吠頬北僕卜墨撲朴牧睦穆釦勃没殆堀幌奔本翻凡盆†摩磨魔麻埋妹昧枚毎哩槙幕膜枕鮪柾鱒桝亦俣又抹末沫迄侭繭麿万慢満漫蔓味未魅巳箕岬密蜜湊蓑稔脈妙粍民眠務夢無牟矛霧鵡椋婿娘冥名命明盟迷銘鳴姪牝滅免棉綿緬面麺摸模茂妄孟毛猛盲網耗蒙儲木黙目杢勿餅尤戻籾貰問悶紋門匁也冶夜爺耶野弥矢厄役約薬訳躍靖柳薮鑓愉愈油癒†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††諭輸唯佑優勇友宥幽悠憂揖有柚湧涌猶猷由祐裕誘遊邑郵雄融夕予余与誉輿預傭幼妖容庸揚揺擁曜楊様洋溶熔用窯羊耀葉蓉要謡踊遥陽養慾抑欲†沃浴翌翼淀羅螺裸来莱頼雷洛絡落酪乱卵嵐欄濫藍蘭覧利吏履李梨理璃痢裏裡里離陸律率立葎掠略劉流溜琉留硫粒隆竜龍侶慮旅虜了亮僚両凌寮料梁涼猟療瞭稜糧良諒遼量陵領力緑倫厘林淋燐琳臨輪隣鱗麟瑠塁涙累類令伶例冷励嶺怜玲礼苓鈴隷零霊麗齢暦歴列劣烈裂廉恋憐漣煉簾練聯†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††蓮連錬呂魯櫓炉賂路露労婁廊弄朗楼榔浪漏牢狼篭老聾蝋郎六麓禄肋録論倭和話歪賄脇惑枠鷲亙亘鰐詫藁蕨椀湾碗腕††††††††††††††††††††††††††††††††††††††††††††弌丐丕个丱丶丼丿乂乖乘亂亅豫亊舒弍于亞亟亠亢亰亳亶从仍仄仆仂仗仞仭仟价伉佚估佛佝佗佇佶侈侏侘佻佩佰侑佯來侖儘俔俟俎俘俛俑俚俐俤俥倚倨倔倪倥倅伜俶倡倩倬俾俯們倆偃假會偕偐偈做偖偬偸傀傚傅傴傲†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††僉僊傳僂僖僞僥僭僣僮價僵儉儁儂儖儕儔儚儡儺儷儼儻儿兀兒兌兔兢竸兩兪兮冀冂囘册冉冏冑冓冕冖冤冦冢冩冪冫决冱冲冰况冽凅凉凛几處凩凭†凰凵凾刄刋刔刎刧刪刮刳刹剏剄剋剌剞剔剪剴剩剳剿剽劍劔劒剱劈劑辨辧劬劭劼劵勁勍勗勞勣勦飭勠勳勵勸勹匆匈甸匍匐匏匕匚匣匯匱匳匸區卆卅丗卉卍凖卞卩卮夘卻卷厂厖厠厦厥厮厰厶參簒雙叟曼燮叮叨叭叺吁吽呀听吭吼吮吶吩吝呎咏呵咎呟呱呷呰咒呻咀呶咄咐咆哇咢咸咥咬哄哈咨†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††咫哂咤咾咼哘哥哦唏唔哽哮哭哺哢唹啀啣啌售啜啅啖啗唸唳啝喙喀咯喊喟啻啾喘喞單啼喃喩喇喨嗚嗅嗟嗄嗜嗤嗔嘔嗷嘖嗾嗽嘛嗹噎噐營嘴嘶嘲嘸†噫噤嘯噬噪嚆嚀嚊嚠嚔嚏嚥嚮嚶嚴囂嚼囁囃囀囈囎囑囓囗囮囹圀囿圄圉圈國圍圓團圖嗇圜圦圷圸坎圻址坏坩埀垈坡坿垉垓垠垳垤垪垰埃埆埔埒埓堊埖埣堋堙堝塲堡塢塋塰毀塒堽塹墅墹墟墫墺壞墻墸墮壅壓壑壗壙壘壥壜壤壟壯壺壹壻壼壽夂夊夐夛梦夥夬夭夲夸夾竒奕奐奎奚奘奢奠奧奬奩†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††奸妁妝佞侫妣妲姆姨姜妍姙姚娥娟娑娜娉娚婀婬婉娵娶婢婪媚媼媾嫋嫂媽嫣嫗嫦嫩嫖嫺嫻嬌嬋嬖嬲嫐嬪嬶嬾孃孅孀孑孕孚孛孥孩孰孳孵學斈孺宀†它宦宸寃寇寉寔寐寤實寢寞寥寫寰寶寳尅將專對尓尠尢尨尸尹屁屆屎屓屐屏孱屬屮乢屶屹岌岑岔妛岫岻岶岼岷峅岾峇峙峩峽峺峭嶌峪崋崕崗嵜崟崛崑崔崢崚崙崘嵌嵒嵎嵋嵬嵳嵶嶇嶄嶂嶢嶝嶬嶮嶽嶐嶷嶼巉巍巓巒巖巛巫已巵帋帚帙帑帛帶帷幄幃幀幎幗幔幟幢幤幇幵并幺麼广庠廁廂廈廐廏†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††廖廣廝廚廛廢廡廨廩廬廱廳廰廴廸廾弃弉彝彜弋弑弖弩弭弸彁彈彌彎弯彑彖彗彙彡彭彳彷徃徂彿徊很徑徇從徙徘徠徨徭徼忖忻忤忸忱忝悳忿怡恠†怙怐怩怎怱怛怕怫怦怏怺恚恁恪恷恟恊恆恍恣恃恤恂恬恫恙悁悍惧悃悚悄悛悖悗悒悧悋惡悸惠惓悴忰悽惆悵惘慍愕愆惶惷愀惴惺愃愡惻惱愍愎慇愾愨愧慊愿愼愬愴愽慂慄慳慷慘慙慚慫慴慯慥慱慟慝慓慵憙憖憇憬憔憚憊憑憫憮懌懊應懷懈懃懆憺懋罹懍懦懣懶懺懴懿懽懼懾戀戈戉戍戌戔戛†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††戞戡截戮戰戲戳扁扎扞扣扛扠扨扼抂抉找抒抓抖拔抃抔拗拑抻拏拿拆擔拈拜拌拊拂拇抛拉挌拮拱挧挂挈拯拵捐挾捍搜捏掖掎掀掫捶掣掏掉掟掵捫†捩掾揩揀揆揣揉插揶揄搖搴搆搓搦搶攝搗搨搏摧摯摶摎攪撕撓撥撩撈撼據擒擅擇撻擘擂擱擧舉擠擡抬擣擯攬擶擴擲擺攀擽攘攜攅攤攣攫攴攵攷收攸畋效敖敕敍敘敞敝敲數斂斃變斛斟斫斷旃旆旁旄旌旒旛旙无旡旱杲昊昃旻杳昵昶昴昜晏晄晉晁晞晝晤晧晨晟晢晰暃暈暎暉暄暘暝曁暹曉暾暼†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††曄暸曖曚曠昿曦曩曰曵曷朏朖朞朦朧霸朮朿朶杁朸朷杆杞杠杙杣杤枉杰枩杼杪枌枋枦枡枅枷柯枴柬枳柩枸柤柞柝柢柮枹柎柆柧檜栞框栩桀桍栲桎†梳栫桙档桷桿梟梏梭梔條梛梃檮梹桴梵梠梺椏梍桾椁棊椈棘椢椦棡椌棍棔棧棕椶椒椄棗棣椥棹棠棯椨椪椚椣椡棆楹楷楜楸楫楔楾楮椹楴椽楙椰楡楞楝榁楪榲榮槐榿槁槓榾槎寨槊槝榻槃榧樮榑榠榜榕榴槞槨樂樛槿權槹槲槧樅榱樞槭樔槫樊樒櫁樣樓橄樌橲樶橸橇橢橙橦橈樸樢檐檍檠檄檢檣†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††檗蘗檻櫃櫂檸檳檬櫞櫑櫟檪櫚櫪櫻欅蘖櫺欒欖鬱欟欸欷盜欹飮歇歃歉歐歙歔歛歟歡歸歹歿殀殄殃殍殘殕殞殤殪殫殯殲殱殳殷殼毆毋毓毟毬毫毳毯†麾氈氓气氛氤氣汞汕汢汪沂沍沚沁沛汾汨汳沒沐泄泱泓沽泗泅泝沮沱沾沺泛泯泙泪洟衍洶洫洽洸洙洵洳洒洌浣涓浤浚浹浙涎涕濤涅淹渕渊涵淇淦涸淆淬淞淌淨淒淅淺淙淤淕淪淮渭湮渮渙湲湟渾渣湫渫湶湍渟湃渺湎渤滿渝游溂溪溘滉溷滓溽溯滄溲滔滕溏溥滂溟潁漑灌滬滸滾漿滲漱滯漲滌†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††漾漓滷澆潺潸澁澀潯潛濳潭澂潼潘澎澑濂潦澳澣澡澤澹濆澪濟濕濬濔濘濱濮濛瀉瀋濺瀑瀁瀏濾瀛瀚潴瀝瀘瀟瀰瀾瀲灑灣炙炒炯烱炬炸炳炮烟烋烝†烙焉烽焜焙煥煕熈煦煢煌煖煬熏燻熄熕熨熬燗熹熾燒燉燔燎燠燬燧燵燼燹燿爍爐爛爨爭爬爰爲爻爼爿牀牆牋牘牴牾犂犁犇犒犖犢犧犹犲狃狆狄狎狒狢狠狡狹狷倏猗猊猜猖猝猴猯猩猥猾獎獏默獗獪獨獰獸獵獻獺珈玳珎玻珀珥珮珞璢琅瑯琥珸琲琺瑕琿瑟瑙瑁瑜瑩瑰瑣瑪瑶瑾璋璞璧瓊瓏瓔珱†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††瓠瓣瓧瓩瓮瓲瓰瓱瓸瓷甄甃甅甌甎甍甕甓甞甦甬甼畄畍畊畉畛畆畚畩畤畧畫畭畸當疆疇畴疊疉疂疔疚疝疥疣痂疳痃疵疽疸疼疱痍痊痒痙痣痞痾痿†痼瘁痰痺痲痳瘋瘍瘉瘟瘧瘠瘡瘢瘤瘴瘰瘻癇癈癆癜癘癡癢癨癩癪癧癬癰癲癶癸發皀皃皈皋皎皖皓皙皚皰皴皸皹皺盂盍盖盒盞盡盥盧盪蘯盻眈眇眄眩眤眞眥眦眛眷眸睇睚睨睫睛睥睿睾睹瞎瞋瞑瞠瞞瞰瞶瞹瞿瞼瞽瞻矇矍矗矚矜矣矮矼砌砒礦砠礪硅碎硴碆硼碚碌碣碵碪碯磑磆磋磔碾碼磅磊磬†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††磧磚磽磴礇礒礑礙礬礫祀祠祗祟祚祕祓祺祿禊禝禧齋禪禮禳禹禺秉秕秧秬秡秣稈稍稘稙稠稟禀稱稻稾稷穃穗穉穡穢穩龝穰穹穽窈窗窕窘窖窩竈窰†窶竅竄窿邃竇竊竍竏竕竓站竚竝竡竢竦竭竰笂笏笊笆笳笘笙笞笵笨笶筐筺笄筍笋筌筅筵筥筴筧筰筱筬筮箝箘箟箍箜箚箋箒箏筝箙篋篁篌篏箴篆篝篩簑簔篦篥籠簀簇簓篳篷簗簍篶簣簧簪簟簷簫簽籌籃籔籏籀籐籘籟籤籖籥籬籵粃粐粤粭粢粫粡粨粳粲粱粮粹粽糀糅糂糘糒糜糢鬻糯糲糴糶糺紆†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††紂紜紕紊絅絋紮紲紿紵絆絳絖絎絲絨絮絏絣經綉絛綏絽綛綺綮綣綵緇綽綫總綢綯緜綸綟綰緘緝緤緞緻緲緡縅縊縣縡縒縱縟縉縋縢繆繦縻縵縹繃縷†縲縺繧繝繖繞繙繚繹繪繩繼繻纃緕繽辮繿纈纉續纒纐纓纔纖纎纛纜缸缺罅罌罍罎罐网罕罔罘罟罠罨罩罧罸羂羆羃羈羇羌羔羞羝羚羣羯羲羹羮羶羸譱翅翆翊翕翔翡翦翩翳翹飜耆耄耋耒耘耙耜耡耨耿耻聊聆聒聘聚聟聢聨聳聲聰聶聹聽聿肄肆肅肛肓肚肭冐肬胛胥胙胝胄胚胖脉胯胱脛脩脣脯腋†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††隋腆脾腓腑胼腱腮腥腦腴膃膈膊膀膂膠膕膤膣腟膓膩膰膵膾膸膽臀臂膺臉臍臑臙臘臈臚臟臠臧臺臻臾舁舂舅與舊舍舐舖舩舫舸舳艀艙艘艝艚艟艤†艢艨艪艫舮艱艷艸艾芍芒芫芟芻芬苡苣苟苒苴苳苺莓范苻苹苞茆苜茉苙茵茴茖茲茱荀茹荐荅茯茫茗茘莅莚莪莟莢莖茣莎莇莊荼莵荳荵莠莉莨菴萓菫菎菽萃菘萋菁菷萇菠菲萍萢萠莽萸蔆菻葭萪萼蕚蒄葷葫蒭葮蒂葩葆萬葯葹萵蓊葢蒹蒿蒟蓙蓍蒻蓚蓐蓁蓆蓖蒡蔡蓿蓴蔗蔘蔬蔟蔕蔔蓼蕀蕣蕘蕈†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††蕁蘂蕋蕕薀薤薈薑薊薨蕭薔薛藪薇薜蕷蕾薐藉薺藏薹藐藕藝藥藜藹蘊蘓蘋藾藺蘆蘢蘚蘰蘿虍乕虔號虧虱蚓蚣蚩蚪蚋蚌蚶蚯蛄蛆蚰蛉蠣蚫蛔蛞蛩蛬†蛟蛛蛯蜒蜆蜈蜀蜃蛻蜑蜉蜍蛹蜊蜴蜿蜷蜻蜥蜩蜚蝠蝟蝸蝌蝎蝴蝗蝨蝮蝙蝓蝣蝪蠅螢螟螂螯蟋螽蟀蟐雖螫蟄螳蟇蟆螻蟯蟲蟠蠏蠍蟾蟶蟷蠎蟒蠑蠖蠕蠢蠡蠱蠶蠹蠧蠻衄衂衒衙衞衢衫袁衾袞衵衽袵衲袂袗袒袮袙袢袍袤袰袿袱裃裄裔裘裙裝裹褂裼裴裨裲褄褌褊褓襃褞褥褪褫襁襄褻褶褸襌褝襠襞†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††襦襤襭襪襯襴襷襾覃覈覊覓覘覡覩覦覬覯覲覺覽覿觀觚觜觝觧觴觸訃訖訐訌訛訝訥訶詁詛詒詆詈詼詭詬詢誅誂誄誨誡誑誥誦誚誣諄諍諂諚諫諳諧†諤諱謔諠諢諷諞諛謌謇謚諡謖謐謗謠謳鞫謦謫謾謨譁譌譏譎證譖譛譚譫譟譬譯譴譽讀讌讎讒讓讖讙讚谺豁谿豈豌豎豐豕豢豬豸豺貂貉貅貊貍貎貔豼貘戝貭貪貽貲貳貮貶賈賁賤賣賚賽賺賻贄贅贊贇贏贍贐齎贓賍贔贖赧赭赱赳趁趙跂趾趺跏跚跖跌跛跋跪跫跟跣跼踈踉跿踝踞踐踟蹂踵踰踴蹊†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††蹇蹉蹌蹐蹈蹙蹤蹠踪蹣蹕蹶蹲蹼躁躇躅躄躋躊躓躑躔躙躪躡躬躰軆躱躾軅軈軋軛軣軼軻軫軾輊輅輕輒輙輓輜輟輛輌輦輳輻輹轅轂輾轌轉轆轎轗轜†轢轣轤辜辟辣辭辯辷迚迥迢迪迯邇迴逅迹迺逑逕逡逍逞逖逋逧逶逵逹迸遏遐遑遒逎遉逾遖遘遞遨遯遶隨遲邂遽邁邀邊邉邏邨邯邱邵郢郤扈郛鄂鄒鄙鄲鄰酊酖酘酣酥酩酳酲醋醉醂醢醫醯醪醵醴醺釀釁釉釋釐釖釟釡釛釼釵釶鈞釿鈔鈬鈕鈑鉞鉗鉅鉉鉤鉈銕鈿鉋鉐銜銖銓銛鉚鋏銹銷鋩錏鋺鍄錮†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††錙錢錚錣錺錵錻鍜鍠鍼鍮鍖鎰鎬鎭鎔鎹鏖鏗鏨鏥鏘鏃鏝鏐鏈鏤鐚鐔鐓鐃鐇鐐鐶鐫鐵鐡鐺鑁鑒鑄鑛鑠鑢鑞鑪鈩鑰鑵鑷鑽鑚鑼鑾钁鑿閂閇閊閔閖閘閙†閠閨閧閭閼閻閹閾闊濶闃闍闌闕闔闖關闡闥闢阡阨阮阯陂陌陏陋陷陜陞陝陟陦陲陬隍隘隕隗險隧隱隲隰隴隶隸隹雎雋雉雍襍雜霍雕雹霄霆霈霓霎霑霏霖霙霤霪霰霹霽霾靄靆靈靂靉靜靠靤靦靨勒靫靱靹鞅靼鞁靺鞆鞋鞏鞐鞜鞨鞦鞣鞳鞴韃韆韈韋韜韭齏韲竟韶韵頏頌頸頤頡頷頽顆顏顋顫顯顰†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††顱顴顳颪颯颱颶飄飃飆飩飫餃餉餒餔餘餡餝餞餤餠餬餮餽餾饂饉饅饐饋饑饒饌饕馗馘馥馭馮馼駟駛駝駘駑駭駮駱駲駻駸騁騏騅駢騙騫騷驅驂驀驃†騾驕驍驛驗驟驢驥驤驩驫驪骭骰骼髀髏髑髓體髞髟髢髣髦髯髫髮髴髱髷髻鬆鬘鬚鬟鬢鬣鬥鬧鬨鬩鬪鬮鬯鬲魄魃魏魍魎魑魘魴鮓鮃鮑鮖鮗鮟鮠鮨鮴鯀鯊鮹鯆鯏鯑鯒鯣鯢鯤鯔鯡鰺鯲鯱鯰鰕鰔鰉鰓鰌鰆鰈鰒鰊鰄鰮鰛鰥鰤鰡鰰鱇鰲鱆鰾鱚鱠鱧鱶鱸鳧鳬鳰鴉鴈鳫鴃鴆鴪鴦鶯鴣鴟鵄鴕鴒鵁鴿鴾鵆鵈†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††鵝鵞鵤鵑鵐鵙鵲鶉鶇鶫鵯鵺鶚鶤鶩鶲鷄鷁鶻鶸鶺鷆鷏鷂鷙鷓鷸鷦鷭鷯鷽鸚鸛鸞鹵鹹鹽麁麈麋麌麒麕麑麝麥麩麸麪麭靡黌黎黏黐黔黜點黝黠黥黨黯†黴黶黷黹黻黼黽鼇鼈皷鼕鼡鼬鼾齊齒齔齣齟齠齡齦齧齬齪齷齲齶龕龜龠堯槇遙瑤凜熙†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††纊褜鍈銈蓜俉炻昱棈鋹曻彅丨仡仼伀伃伹佖侒侊侚侔俍偀倢俿倞偆偰偂傔僴僘兊兤冝冾凬刕劜劦勀勛匀匇匤卲厓厲叝﨎咜咊咩哿喆坙坥垬埈埇﨏†塚增墲夋奓奛奝奣妤妺孖寀甯寘寬尞岦岺峵崧嵓﨑嵂嵭嶸嶹巐弡弴彧德忞恝悅悊惞惕愠惲愑愷愰憘戓抦揵摠撝擎敎昀昕昻昉昮昞昤晥晗晙晴晳暙暠暲暿曺朎朗杦枻桒柀栁桄棏﨓楨﨔榘槢樰橫橆橳橾櫢櫤毖氿汜沆汯泚洄涇浯涖涬淏淸淲淼渹湜渧渼溿澈澵濵瀅瀇瀨炅炫焏焄煜煆煇凞燁燾犱†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††犾猤猪獷玽珉珖珣珒琇珵琦琪琩琮瑢璉璟甁畯皂皜皞皛皦益睆劯砡硎硤硺礰礼神祥禔福禛竑竧靖竫箞精絈絜綷綠緖繒罇羡羽茁荢荿菇菶葈蒴蕓蕙†蕫﨟薰蘒﨡蠇裵訒訷詹誧誾諟諸諶譓譿賰賴贒赶﨣軏﨤逸遧郞都鄕鄧釚釗釞釭釮釤釥鈆鈐鈊鈺鉀鈼鉎鉙鉑鈹鉧銧鉷鉸鋧鋗鋙鋐﨧鋕鋠鋓錥錡鋻﨨錞鋿錝錂鍰鍗鎤鏆鏞鏸鐱鑅鑈閒隆﨩隝隯霳霻靃靍靏靑靕顗顥飯飼餧館馞驎髙髜魵魲鮏鮱鮻鰀鵰鵫鶴鸙黑††ⅰⅱⅲⅳⅴⅵⅶⅷⅸⅹ￢￤＇＂†††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††††?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   󿢟󿢠󿢡󿢢󿢣󿢤󿢥󿢦󿢧󿢨󿢩󿢪󿢫󿢬󿢭󿢮󿢯󿢰󿢱󿢲󿢳󿢴󿢵󿢶󿢷󿢸󿢹󿢺󿢻󿢼󿢽󿢾󿢿󿣀󿣁󿣂󿣃󿣄󿣅󿣆󿣇󿣈󿣉󿣊󿣋󿣌󿣍󿣎󿣏󿣐󿣑󿣒󿣓󿣔󿣕󿣖󿣗󿣘󿣙󿣚󿣛󿣜󿣝󿣞󿣟󿣠󿣡󿣢󿣣󿣤󿣥󿣦󿣧󿣨󿣩󿣪󿣫󿣬󿣭󿣮󿣯󿣰󿣱󿣲󿣳󿣴󿣵󿣶󿣷󿣸󿣹󿣺󿣻󿣼?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   󿥀󿥁󿥂󿥃󿥄󿥅󿥆󿥇󿥈󿥉?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   󿥲󿥳󿥴󿥵󿥶󿥷󿥸󿥹󿥺󿥻󿥼󿥽󿥾?   󿦀󿦁󿦂󿦃󿦄󿦅󿦆󿦇󿦈󿦉󿦊󿦋󿦌󿦍󿦎󿦏󿦐󿦑󿦒󿦓󿦔󿦕󿦖󿦗󿦘󿦙󿦚󿦛󿦜󿦝󿦞󿦟󿦠󿦡󿦢󿦣󿦤󿦥󿦦󿦧󿦨󿦩󿦪󿦫󿦬󿦭󿦮󿦯󿦰?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   󿁀󿁁󿁂󿁃󿁄󿁅󿁆󿁇󿁈󿁉󿁊󿁋󿁌󿁍󿁎󿁏󿁐󿁑󿁒󿁓󿁔󿁕󿁖󿁗󿁘󿁙󿁚󿁛󿁜󿁝󿁞󿁟󿁠󿁡󿁢󿁣󿁤󿁥󿁦󿁧󿁨󿁩󿁪󿁫󿁬󿁭󿁮󿁯󿁰󿁱󿁲󿁳󿁴󿁵󿁶󿁷󿁸󿁹󿁺󿁻󿁼󿁽󿁾?   󿂀󿂁󿂂󿂃󿂄󿂅󿂆󿂇󿂈󿂉󿂊󿂋󿂌󿂍󿂎󿂏󿂐󿂑󿂒󿂓󿂔󿂕󿂖󿂗󿂘󿂙󿂚󿂛󿂜󿂝󿂞󿂟󿂠󿂡󿂢󿂣󿂤󿂥󿂦󿂧󿂨󿂩󿂪󿂫󿂬󿂭󿂮󿂯󿂰󿂱󿂲󿂳󿂴󿂵󿂶󿂷󿂸󿂹󿂺󿂻󿂼󿂽󿂾󿂿󿃀󿃁󿃂󿃃󿃄󿃅󿃆󿃇󿃈󿃉󿃊󿃋󿃌󿃍󿃎󿃏󿃐󿃑󿃒󿃓󿃔󿃕󿃖󿃗󿃘󿃙󿃚󿃛󿃜󿃝󿃞󿃟󿃠󿃡󿃢󿃣󿃤󿃥󿃦󿃧󿃨󿃩󿃪󿃫󿃬󿃭󿃮󿃯󿃰󿃱󿃲󿃳󿃴󿃵󿃶󿃷󿃸󿃹󿃺󿃻󿃼?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   󿅀󿅁󿅂󿅃󿅄󿅅󿅆󿅇󿅈󿅉󿅊󿅋󿅌󿅍󿅎󿅏󿅐󿅑󿅒󿅓󿅔󿅕󿅖󿅗󿅘󿅙󿅚󿅛󿅜󿅝󿅞󿅟󿅠󿅡󿅢󿅣󿅤󿅥󿅦󿅧󿅨󿅩󿅪󿅫󿅬󿅭󿅮󿅯󿅰󿅱󿅲󿅳󿅴󿅵󿅶󿅷󿅸󿅹󿅺󿅻󿅼󿅽󿅾?   󿆀󿆁󿆂󿆃󿆄󿆅󿆆󿆇󿆈󿆉󿆊󿆋󿆌󿆍󿆎󿆏󿆐󿆑󿆒󿆓󿆔󿆕󿆖󿆗󿆘󿆙󿆚󿆛󿆜󿆝󿆞󿆟󿆠󿆡󿆢󿆣󿆤󿆥󿆦󿆧󿆨󿆩󿆪󿆫󿆬󿆭󿆮󿆯󿆰󿆱󿆲󿆳󿆴󿆵󿆶󿆷󿆸󿆹󿆺󿆻󿆼󿆽󿆾󿆿󿇀󿇁󿇂󿇃󿇄󿇅󿇆󿇇󿇈󿇉󿇊󿇋󿇌󿇍󿇎󿇏󿇐󿇑󿇒󿇓󿇔󿇕󿇖?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   󿉀󿉁󿉂󿉃󿉄󿉅󿉆󿉇󿉈󿉉󿉊󿉋󿉌󿉍󿉎󿉏󿉐󿉑󿉒󿉓󿉔󿉕󿉖󿉗󿉘󿉙󿉚󿉛󿉜󿉝󿉞󿉟󿉠󿉡󿉢󿉣󿉤󿉥󿉦󿉧󿉨󿉩󿉪󿉫󿉬󿉭󿉮󿉯󿉰󿉱󿉲󿉳󿉴󿉵󿉶󿉷󿉸󿉹󿉺󿉻󿉼󿉽󿉾?   󿊀󿊁󿊂󿊃󿊄󿊅󿊆󿊇󿊈󿊉󿊊󿊋󿊌󿊍󿊎󿊏󿊐󿊑󿊒󿊓󿊔󿊕󿊖󿊗󿊘󿊙󿊚󿊛󿊜󿊝󿊞󿊟󿊠󿊡󿊢󿊣󿊤󿊥󿊦󿊧󿊨󿊩󿊪󿊫?   ?   ?   ?   󿊰󿊱󿊲󿊳󿊴󿊵󿊶󿊷󿊸󿊹󿊺󿊻󿊼󿊽󿊾󿊿󿋀󿋁󿋂󿋃󿋄󿋅󿋆󿋇󿋈󿋉󿋊󿋋󿋌󿋍󿋎󿋏󿋐󿋑󿋒󿋓󿋔󿋕?   ?   ?   ?   ?   ?   ?   ?   ?   󿋟󿋠󿋡󿋢󿋣󿋤󿋥󿋦󿋧󿋨󿋩󿋪󿋫󿋬󿋭󿋮󿋯󿋰󿋱󿋲󿋳󿋴󿋵󿋶󿋷󿋸󿋹󿋺󿋻󿋼?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   󿍀󿍁󿍂󿍃󿍄󿍅󿍆󿍇󿍈󿍉󿍊󿍋󿍌󿍍󿍎󿍏󿍐󿍑󿍒󿍓󿍔󿍕󿍖󿍗󿍘󿍙󿍚󿍛󿍜󿍝󿍞󿍟󿍠󿍡󿍢󿍣󿍤󿍥󿍦󿍧󿍨󿍩󿍪󿍫󿍬󿍭󿍮󿍯󿍰󿍱󿍲󿍳󿍴󿍵󿍶󿍷󿍸󿍹󿍺󿍻󿍼󿍽󿍾?   󿎀󿎁󿎂󿎃󿎄󿎅󿎆󿎇󿎈󿎉󿎊󿎋󿎌󿎍󿎎󿎏󿎐󿎑󿎒󿎓󿎔󿎕󿎖󿎗󿎘󿎙󿎚󿎛󿎜󿎝󿎞󿎟󿎠󿎡󿎢󿎣󿎤󿎥󿎦󿎧󿎨󿎩󿎪󿎫󿎬󿎭󿎮󿎯󿎰󿎱󿎲󿎳󿎴󿎵󿎶󿎷󿎸󿎹󿎺󿎻󿎼󿎽󿎾󿎿󿏀󿏁󿏂󿏃󿏄󿏅󿏆󿏇󿏈󿏉󿏊󿏋󿏌󿏍󿏎󿏏󿏐󿏑󿏒󿏓󿏔󿏕󿏖󿏗󿏘󿏙󿏚󿏛󿏜󿏝󿏞󿏟󿏠󿏡󿏢󿏣󿏤󿏥󿏦󿏧󿏨󿏩󿏪󿏫󿏬󿏭󿏮󿏯󿏰󿏱󿏲󿏳󿏴󿏵󿏶󿏷󿏸󿏹󿏺?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   󿑀󿑁󿑂󿑃󿑄󿑅󿑆󿑇󿑈󿑉󿑊󿑋󿑌󿑍󿑎󿑏?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   󿒀?   ?   ?   󿒄󿒅󿒆󿒇󿒈󿒉󿒊?   󿒌󿒍󿒎?   󿒐?   ?   ?   󿒔󿒕󿒖?   󿒘󿒙󿒚󿒛󿒜?   ?   ?   󿒠󿒡󿒢󿒣󿒤?   ?   ?   󿒨󿒩󿒪󿒫󿒬󿒭󿒮󿒯?   ?   ?   ?   󿒴󿒵?   ?   ?   ?   ?   ?   󿒼󿒽󿒾?   ?   ?   ?   ?   󿓄󿓅?   ?   󿓈?   ?   ?   󿓌?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   󿬡󿬢󿬣󿬤󿬥󿬦󿬧󿬨󿬩󿬪󿬫󿬬󿬭󿬮󿬯󿬰󿬱󿬲󿬳󿬴󿬵󿬶󿬷󿬸󿬹󿬺󿬻󿬼󿬽󿬾󿬿󿭀󿭁󿭂󿭃󿭄󿭅󿭆󿭇󿭈󿭉󿭊󿭋󿭌󿭍󿭎󿭏󿭐󿭑󿭒󿭓󿭔󿭕󿭖󿭗󿭘󿭙󿭚󿭛󿭜󿭝󿭞󿭟󿭠󿭡󿭢󿭣󿭤󿭥󿭦󿭧󿭨󿭩󿭪󿭫󿭬󿭭󿭮󿭯󿭰󿭱󿭲󿭳󿭴󿭵󿭶󿭷󿭸󿭹󿭺?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   󿰡󿰢󿰣󿰤󿰥󿰦󿰧󿰨󿰩󿰪󿰫󿰬󿰭󿰮󿰯󿰰󿰱󿰲󿰳󿰴󿰵󿰶󿰷󿰸󿰹󿰺󿰻󿰼󿰽󿰾󿰿󿱀󿱁󿱂󿱃󿱄󿱅󿱆󿱇󿱈󿱉󿱊󿱋󿱌󿱍󿱎󿱏󿱐󿱑󿱒󿱓󿱔󿱕󿱖󿱗󿱘󿱙󿱚󿱛󿱜󿱝󿱞󿱟󿱠󿱡󿱢󿱣󿱤󿱥󿱦󿱧󿱨󿱩󿱪󿱫󿱬󿱭󿱮󿱯󿱰󿱱󿱲󿱳󿱴󿱵󿱶󿱷󿱸󿱹󿱺?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   󿴡󿴢󿴣󿴤󿴥󿴦󿴧󿴨󿴩󿴪󿴫󿴬󿴭󿴮󿴯󿴰󿴱󿴲󿴳󿴴󿴵󿴶󿴷󿴸󿴹󿴺󿴻󿴼󿴽󿴾󿴿󿵀󿵁󿵂󿵃󿵄󿵅󿵆󿵇󿵈󿵉󿵊󿵋󿵌󿵍󿵎󿵏󿵐󿵑󿵒󿵓󿵔󿵕󿵖󿵗󿵘󿵙󿵚󿵛󿵜󿵝󿵞󿵟󿵠󿵡󿵢󿵣󿵤󿵥󿵦󿵧󿵨󿵩󿵪󿵫󿵬󿵭󿵮󿵯󿵰󿵱󿵲󿵳󿵴󿵵󿵶󿵷󿵸󿵹󿵺?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?                                                                                                                                   ��������������������? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ����������������? ��  �������F? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ������? ������? ? ? ����? ? ��? ����? ? ? ����? ? ��? ����? ? ? ? ? ? ? ? ? ? ? ? ? ������������? ? ����? ? ? ? ��? ? ��? ? ? ��������������? ? ? ? �~? ? ? ? ? ��������? ��������                                                                                                                                      ��������? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ��? ? ? ? ? ? ��? ? ��? ? ? ����? ��? ? ? ? ? ? ��? ����? ? ? ��? ? ? ? ��? ? ? ?   ? �w��? ? ����? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ��? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ��? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ������?                                                                                                                                                                                                                   ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?   ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?         ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?                   ��? ? ? a b c d e f g h I j k l m n o p q r s t u v w x y z                                                                                                                                       A B C D E F G H I J K L M N O P Q R S T U V W X Y Z ������������������������������������������������������������������������  �ĂłƂǂȂɂʂ˂̂͂΂ςЂт҂ӂԂՂւׂ؂قڂۂ܂݂ނ߂�����������������@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O�P�Q�R�S�T�U�V�W�X�Y�Z�[�\�]�^�_�`�a�b�c�d�e�f�g�h�i��k�l�m�n�o�p�q�r�s�t�u�v�w�x�y�z�{�|�}�~����������������������������������                                                                                                                                          ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?                                                                                                 ?       ? ? ? ? ����?   �G? ?   ��      ������  �����C�D?       �������I?       ����? ? ? ? ����        ? ?             ? ? ?           ? ?     ?       ��                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    ��������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������                                                                                                                                      �@�A�B�C�D�E�F�G�H�I                                                                                �r�s�t�u�v�w�x�y�z�{�|�}�~  ��������������������������������������������������������������������������������������������������                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                ? ? �s�r? ? ? ��? ? ? ? ? ? ��? ? ��? ��? ? ? ? ? ? ? ? ? ��? ��? ? ��������? ? ? ����? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ������? ��? ? ? ? ? ? ? ? ? ? ? ? ������? ? ? ��������? ����?                                                                                                                                                                                                                                                                                                                                             ? ? ? ? ? ? ? ��? ��? ��������������? ? �z�{? ? ? ? ? ��������������������? ? ? �|? ? ? ? ? ? ? ? ? ? ? ? ? �����I? ? ? ? ��������������������������? ? ��? ? ? ? ? ? ? ? ��? ? ? ?                                                                                                                                                                                                                                                                                                                                             ? ? ��? ? ? ��������? ? ��? ? ��������������? ��? ? ? ��������? ? ����? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ��? ��? ��? �������}? ? ? ������? �����������C? ? �F? ? �E? ? ? ��? ����?                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           �@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O�P�Q�R�S�T�U�V�W�X�Y�Z�[�\�]�^�_�`�a�b�c�d�e�f�g�h�i�j�k�l�m�n�o�p�q�r�s�t�u�v�w�x�y�z�{�|�}�~  ����������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������                                                                                                                                      �@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O�P�Q�R�S�T�U�V�W�X�Y�Z�[�\�]�^�_�`�a�b�c�d�e�f�g�h�i�j�k�l�m�n�o�p�q�r�s�t�u�v�w�x�y�z�{�|�}�~  ��������������������������������������������������������������������������������������������������������������                                                                                                                                                                                                                  �@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O�P�Q�R�S�T�U�V�W�X�Y�Z�[�\�]�^�_�`�a�b�c�d�e�f�g�h�i�j�k�l�m�n�o�p�q�r�s�t�u�v�w�x�y�z�{�|�}�~  ��������������������������������������������        ������������������������������������������������������������                  ������������������������������������������������������������                                                                                                                                      �@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O�P�Q�R�S�T�U�V�W�X�Y�Z�[�\�]�^�_�`�a�b�c�d�e�f�g�h�i�j�k�l�m�n�o�p�q�r�s�t�u�v�w�x�y�z�{�|�}�~  ��������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������                                                                                                                                          �@�A�B�C�D�E�F�G�H�I�J�K�L�M�N�O                                                                                                �      �������  ���  ��      ������  ����������      ����������      ����������������        ����            ������          ����    ��      ��                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    ������������? ���u�v�w�x�y�z�{�|�~������? ������������? �g����������? ������������������? ��? ? �����? ? ��? ? �����n�]�z? �? �e�d? �q�p�u���A���@? ������������? �V�`��                                                                                                                                      ? ? ? ����? ���? ��                                                                                ? ? ? ? ? �? ? ? ? ? ? ��  ? ���? ��? ? �A�B�C�D�E�F�G�H�I�@����? ��������? ? ? ? ? ? ��? ? ? ? �? ? ? ���C�B? ? ? ? ? ? ��                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                ? ? �? ? ? ? ? ? ��? ? �v��o? ������L�? ? �? ? ��? �]? ? ��������u�r? �q�p? ��? ? �? ? ? ? ������? ? ? �? ? ���W? ? ? ? ? �? ? ? �z? ? ? ? ������������? ����������                                                                                                                                                                                                                                                                                                                                            ��? ? ? ? ? ������? �����A�@? ����? ? ? ? ? ? ? ? ? �A�B�C�D�E�F�G�H�I�@����? ? ? ? �^�W��������? ? ? ? ��������? ? ? ? ? �u�v�w�x�y�z�{�|�~�������}? ��? ? ? ? ? ? ? ? ? ? ? ? ?                                                                                                                                                                                                                                                                                                                                             ��? ���N�V�n�e�d? �i? ? ? ��������������? ��? ? ? ? ���? ����? ? ? ? ? ? ? ? ? ? ? ? ? ��? ? ? �b? ��? ������? ��I�? �? ? ��? �����������? ? ��? ? ? ? ��? ��? ������                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          $FE$F<$F=$F>$F?$F@$FA$FB$FC$FD?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $FM?    ?    ?    ?    ?    ?    $FL?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $F_$F`$Fa$Fb$Fc$Fd$Fe$Ff$Fk$Fg     $Fh$Fi$Fj$Go?    $Gt?    $E*?    ?    ?    ?    ?    ?    ?    $GP$E9?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $G!$G"$EZ?    ?    ?    ?    ?    ?    $Ey$G>$F!$G?$G=$F"?    ?    ?    $Ev?    ?    ?    $Gg$Gd$Ge?    ?    ?    ?    ?    $Ex?    ?    $ED?    $G]?    ?    ?    $G[?    ?    ?    ?    ?    $EL$ET$EV$EU?    $G6$G8?    $G5$G4$G3?    $GY$Eo$GZ$Ep?    ?    ?    $Eu$EA$EC$Em$Er?    $Ew$F(?    $Gj$Gi$Gk$Gh$E]?    ?    ?    ?    ?    ?    $FP$FQ$FO$FN$G0$G1$G2$E1$E<$GB?    $F,$F-                                                                                                                                                                                                                                                                                                                                               $F/$F.?    ?    ?    ?    ?    ?    ?    $G^?    ?    ?    ?    $G&?    ?    ?    ?    ?    ?    ?    $G'$E^?    ?    ?    ?    ?    $E>?    ?    ?    ?    $GT?    $G*$G)?    ?    ?    $G,?    ?    ?    ?    $G($E/$EJ$EI$EG?    ?    $EF$E-?    ?    ?    $Eh?    ?    ?    ?         ?    $E#$E4?    ?    $GV?    $GW?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E3?    ?    ?    ?    ?    ?    $E.?    $EO$G_$Ed?    $E6?    ?    ?    ?    ?    ?    ?    ?    ?    $Ga?    ?    $EE$E2?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $Gz?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $Gv$Gx$Gy?                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E5?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?         ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?                        ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?                                                 $Fm?    $FF$FGa    b    c    d    e    f    g    h    I    j    k    l    m    n    o    p    q    r    s    t    u    v    w    x    y    z                                                                                                                                                                                                                                                                                                                                                   A    B    C    D    E    F    G    H    I    J    K    L    M    N    O    P    Q    R    S    T    U    V    W    X    Y    Z    ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��        ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   �@   �A   �B   �C   �D   �E   �F   �G   �H   �I   �J   �K   �L   �M   �N   �O   �P   �Q   �R   �S   �T   �U   �V   �W   �X   �Y   �Z   �[   �\   �]   �^   �_   �`   �a   �b   �c   �d   �e   �f   �g   �h   �i   ��   �k   �l   �m   �n   �o   �p   �q   �r   �s   �t   �u   �v   �w   �x   �y   �z   �{   �|   �}   �~   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��   ��                                                                                                                                                                                                                                                                                                                                                            ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?                                                                                                                                                                                                                                                    ?                   ?    ?    ?    ?    ?    ?    $Ez     ?    ?    $EB     $En               $Et$Eq$F*     ?    ?    $Gl?    ?                   $FV$FX$FW$FY?                   $F2$GA?    ?    $F)?    ?    $F1                    ?    ?                                  ?    ?    ?                             ?    ?              ?                   ?                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              $Gj$Gi$Gk$Gh$E]?    ?    $F^$F_$F`$Fa$Fb$Fc$Fd$Fe$Ff$Fg$Fh$Fi$Fj?    $G6$G4$G5$G8$G3?    ?    ?    $G>?    $G??    ?    $Ey$G<$G=$GV$GX$Es$Eu$Em$Et$Ex$Ev$GZ$Eo$En$E`$Gc$Ge$Gd$Gg$E@$E^?    $G\$G]$FV$ED$G^?    ?    ?    $EE?    $F($G($E>?    $E2?    ?    $G)$G*?    $EJ$EK$EF$F,$F.$F-$F/?    ?    $G0$G1$G2$FX$FW?    $G'?    $F*                                                                                                                                                                                                                                                                                                                                               ?    ?    ?    $Gl?    $Gr$Go?    ?    $FY                                                                                                                                                                                                        $E$$E#?    ?    ?    ?    ?    ?    $F5$F6$FI$G_?         ?    $E4$F2?    $F1$F0?    $F<$F=$F>$F?$F@$FA$FB$FC$FD$FE$GB?    $GC?    $Gv$Gy?    $Gx?    ?    ?    $EC?    $G#?    $E/?    $G-?    ?    ?    $E\?    ?    ?    ?    ?    $E(?    ?    ?    $Fm                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                $E!$E"$E#$E$$E%$E&$E'$E($E)$E*$E+$E,$E-$E.$E/$E0$E1$E2$E3$E4$E5$E6$E7$E8$E9$E:$E;$E<$E=$E>$E?$E@$EA$EB$EC$ED$EE$EF$EG$EH$EI$EJ$EK$EL$EM$EN$EO$EP$EQ$ER$ES$ET$EU$EV$EW$EX$EY$EZ$E[$E\$E]$E^$E_$E`$Ea$Eb$Ec$Ed$Ee$Ef$Eg$Eh$Ei$Ej$Ek$El$Em$En$Eo$Ep$Eq$Er$Es$Et$Eu$Ev$Ew$Ex$Ey$Ez                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              $F!$F"$F#$F$$F%$F&$F'$F($F)$F*$F+$F,$F-$F.$F/$F0$F1$F2$F3$F4$F5$F6$F7$F8$F9$F:$F;$F<$F=$F>$F?$F@$FA$FB$FC$FD$FE$FF$FG$FH$FI$FJ$FK$FL$FM$FN$FO$FP$FQ$FR$FS$FT$FU$FV$FW$FX$FY$FZ$F[$F\$F]$F^$F_$F`$Fa$Fb$Fc$Fd$Fe$Ff$Fg$Fh$Fi$Fj$Fk$Fl$Fm$Fn$Fo$Fp$Fq$Fr$Fs$Ft$Fu$Fv$Fw$Fx$Fy$Fz                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              $G!$G"$G#$G$$G%$G&$G'$G($G)$G*$G+$G,$G-$G.$G/$G0$G1$G2$G3$G4$G5$G6$G7$G8$G9$G:$G;$G<$G=$G>$G?$G@$GA$GB$GC$GD$GE$GF$GG$GH$GI$GJ$GK$GL$GM$GN$GO$GP$GQ$GR$GS$GT$GU$GV$GW$GX$GY$GZ$G[$G\$G]$G^$G_$G`$Ga$Gb$Gc$Gd$Ge$Gf$Gg$Gh$Gi$Gj$Gk$Gl$Gm$Gn$Go$Gp$Gq$Gr$Gs$Gt$Gu$Gv$Gw$Gx$Gy$Gz                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         