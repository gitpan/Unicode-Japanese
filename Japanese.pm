# -----------------------------------------------------------------------------
# Unicode::Japanese
# Unicode::Japanese::PurePerl
# -----------------------------------------------------------------------------
# $Id: Japanese.pm,v 1.75 2004/11/04 07:23:32 hio Exp $
# -----------------------------------------------------------------------------
package Unicode::Japanese::PurePerl;

# methods of Unicode::Japanese::PurePerl are
# below ones of Unicode::Japanese.

# -----------------------------------------------------------------------------
# Unicode::Japanese
# -----------------------------------------------------------------------------
package Unicode::Japanese;

use strict;
use vars qw($VERSION $PurePerl $xs_loaderror);
$VERSION = '0.23';

# `use bytes' and `use Encode' if on perl-5.8.0 or later.
if( $] >= 5.008 )
{
  my $evalerr;
  {
    local($SIG{__DIE__}) = 'DEFAULT';
    local($@);
    eval 'use bytes;use Encode;';
    $evalerr = $@;
  }
  $evalerr and CORE::die($evalerr);
}

# -----------------------------------------------------------------------------
# import
#
sub import
{
  my $pkg = shift;
  my @na;
  foreach(@_)
  {
    $_ eq 'PurePerl' and $PurePerl=1, next;
    if( $_ eq 'no_I18N_Japanese' )
    {
      $^H &= ~0x0f00_0000;
      package Unicode::Japanese::PurePerl;
      $^H &= ~0x0f00_0000;
      package Unicode::Japanese;
      next;
    }
    push(@na,$_);
  }
  if( @na )
  {
    #use Carp;
    #croak("invalid parameter (".join(',',@na).")");
  }
}

# -----------------------------------------------------------------------------
# DESTROY
#
sub DESTROY
{
}

# -----------------------------------------------------------------------------
# load_xs.
#   loading xs-subs.
#   this method is called from new (through new=>_init_table=>load_xs)
#   
sub load_xs
{
  #print STDERR "load_xs\n";
  if( $PurePerl )
  {
    #print STDERR "PurePerl mode\n";
    $xs_loaderror = 'disabled';
    return;
  }
  #print STDERR "XS mode\n";
  
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

# -----------------------------------------------------------------------------
# Unicode::Japanese->new();
# -----------------------------------------------------------------------------
# $unijp = Unicode::Japanese->new([$str,[$icode]]);
# 
sub new
{
  my $pkg = shift;
  my $this = {};

  if( defined($pkg) )
  {
    bless $this, $pkg;
  $this->_init_table;
  }else
  {
    bless $this;
  $this->_init_table;
  }
  
  @_ and $this->set(@_);
  
  $this;
}


# -----------------------------------------------------------------------------
# _got_undefined_subroutine
#   die with message 'undefiend subroutine'.
# 
sub _got_undefined_subroutine
{
  my $subname = pop;
  CORE::die "Undefined subroutine \&$subname called.\n";
}

# -----------------------------------------------------------------------------
# AUTOLOAD
#   AUTOLOAD of Unicode::Japanese.
#   imports PurePerl methods.
# 
AUTOLOAD
{
  # load pure perl subs.
  use vars qw($AUTOLOAD);
  my ($pkg,$subname) = $AUTOLOAD =~ /^(.*)::(\w+)$/
    or got_undefined_subroutine($AUTOLOAD);
  no strict 'refs';
  my $ppsubname = "$pkg\:\:PurePerl\:\:$subname";
  my $sub = \&$ppsubname;
  *$AUTOLOAD = $sub;
  goto &$sub;
}

# -----------------------------------------------------------------------------
# Unicode::Japanese::PurePerl
# -----------------------------------------------------------------------------
package Unicode::Japanese::PurePerl;


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
     SJIS_DBCS => '[\x81-\x9f\xe0-\xef\xfa-\xfc][\x40-\x7e\x80-\xfc]',
     SJIS_KANA => '[\xa1-\xdf]',
     UTF8      => '[\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}',
     BOM2_BE    => '\xfe\xff',
     BOM2_LE    => '\xff\xfe',
     BOM4_BE    => '\x00\x00\xfe\xff',
     BOM4_LE    => '\xff\xfe\x00\x00',
     UTF32_BE   => '\x00[\x00-\x10][\x00-\xff]{2}',
     UTF32_LE   => '[\x00-\xff]{2}[\x00-\x10]\x00',
     E_IMODEv1  => '\xf8[\x9f-\xfc]|\xf9[\x40-\x49\x72-\x7e\x80-\xb0]',
     E_IMODEv2  => '\xf9[\xb1-\xfc]',
     E_IMODE    => '\xf8[\x9f-\xfc]|\xf9[\x40-\x49\x72-\x7e\x80-\xfc]',
     E_JSKY1    => '[EFGOPQ]',
     E_JSKY1v1  => '[EFG]',
     E_JSKY1v2  => '[OPQ]',
     E_JSKY2    => '[\!-z]',
     E_DOTI     => '\xf0[\x40-\x7e\x80-\xfc]|\xf1[\x40-\x7e\x80-\xd6]|\xf2[\x40-\x7e\x80-\xab\xb0-\xd5\xdf-\xfc]|\xf3[\x40-\x7e\x80-\xfa]|\xf4[\x40-\x4f\x80\x84-\x8a\x8c-\x8e\x90\x94-\x96\x98-\x9c\xa0-\xa4\xa8-\xaf\xb4\xb5\xbc-\xbe\xc4\xc5\xc8\xcc]',
     E_JSKY_START => quotemeta($ESC{E_JSKY_START}),
     E_JSKY_END   => quotemeta($ESC{E_JSKY_END}),
     );

$RE{E_JSKY}     =  $RE{E_JSKY_START}
  . $RE{E_JSKY1} . $RE{E_JSKY2} . '+'
  . $RE{E_JSKY_END};
$RE{E_JSKYv1}     =  $RE{E_JSKY_START}
  . $RE{E_JSKY1v1} . $RE{E_JSKY2} . '+'
  . $RE{E_JSKY_END};
$RE{E_JSKYv2}     =  $RE{E_JSKY_START}
  . $RE{E_JSKY1v2} . $RE{E_JSKY2} . '+'
  . $RE{E_JSKY_END};

use vars qw($s2u_table $u2s_table);
use vars qw($ei2u1 $ei2u2 $ed2u $ej2u1 $ej2u2);
use vars qw($eu2i1 $eu2i2 $eu2d $eu2j1 $eu2j2);

use vars qw(%_h2zNum %_z2hNum %_h2zAlpha %_z2hAlpha %_h2zSym %_z2hSym %_h2zKanaK %_z2hKanaK %_h2zKanaD %_z2hKanaD %_hira2kata %_kata2hira);



use vars qw($FH $TABLE $HEADLEN $PROGLEN);

# -----------------------------------------------------------------------------
# AUTOLOAD
#   AUTOLOAD of Unicode::Japanese::PurePerl.
#   load PurePerl methods from embeded data.
# 
AUTOLOAD
{
  use strict;
  use vars qw($AUTOLOAD);
  
  #print STDERR "AUTOLOAD... $AUTOLOAD\n";
  
  my $save = $@;
  my @BAK = @_;
  
  my $subname = $AUTOLOAD;
  $subname =~ s/^Unicode\:\:Japanese\:\:(?:PurePerl\:\:)?//;

  #print "subs..\n",join("\n",keys %$TABLE,'');
  
  # check
  if(!defined($TABLE->{$subname}{offset}))
    {
      _init_table();
      if( !defined($TABLE->{$subname}{offset}) )
      {
	if( substr($AUTOLOAD,-9) eq '::DESTROY' )
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

  if( $]>=5.008 )
  {
    $sub = 'use bytes;'.$sub;
  }

  CORE::eval(($sub=~/(.*)/s)[0]);
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

# -----------------------------------------------------------------------------
# Unicode::Japanese::PurePerl->new()
# 
sub new
{
  goto &Unicode::Japanese::new;
}

# -----------------------------------------------------------------------------
# DESTROY
# 
sub DESTROY
{
}

# -----------------------------------------------------------------------------
# gensym
# 
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

# -----------------------------------------------------------------------------
# _init_table
# 
sub _init_table {
  
  if(!defined($HEADLEN))
    {
      $FH = gensym;
      
      my $file = "Unicode/Japanese.pm";
      OPEN:
      {
        if( $INC{$file} )
        {
          open($FH,$INC{$file}) || CORE::die("could not open file [$INC{$file}] for input : $!");
          last OPEN;
        }
        foreach my $path (@INC)
          {
            my $mypath = $path;
            $mypath =~ s#/$##;
            if (-f "$mypath/$file")
              {
                open($FH,"$mypath/$file") || CORE::die("could not open file [$INC{$file}] for input : $!");
                last OPEN;
              }
          }
        CORE::die "Can't find Japanese.pm in \@INC\n";
      }
      binmode($FH);
      
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
      $TABLE =~ /(.*)/s;
      $TABLE = eval(($TABLE=~/(.*)/s)[0]);
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
      Unicode::Japanese::load_xs();
    }
}

# -----------------------------------------------------------------------------
# _getFile
#   load embeded file data.
# 
sub _getFile {
  my $this = shift;

  my $file = shift;

  exists($TABLE->{$file})
    or die "no such file [$file]\n";

  #print STDERR "_getFile($file, $TABLE->{$file}{offset}, $TABLE->{$file}{length})\n";
  seek($FH, $PROGLEN + $HEADLEN + $TABLE->{$file}{offset}, 0)
    or die "Can't seek $file. [$!]\n";
  
  my $data;
  read($FH, $data, $TABLE->{$file}{length})
    or die "Can't read $file. [$!]\n";
  
  $data;
}

# -----------------------------------------------------------------------------
# use_I18N_Japanese
#   copy from I18N::Japanese in jperl-5.5.3
#
sub use_I18N_Japanese
{
  shift;
  if( @_ )
  {
    my $bits = 0;
    foreach( @_ )
    {
      $bits |= 0x1000000 if $_ eq 're';
      $bits |= 0x2000000 if $_ eq 'tr';
      $bits |= 0x4000000 if $_ eq 'format';
      $bits |= 0x8000000 if $_ eq 'string';
    }
    $^H |= $bits;
  }else
  {
    $^H |= 0x0f00_0000;
  }
}

# -----------------------------------------------------------------------------
# no_I18N_Japanese
#   copy from I18N::Japanese in jperl-5.5.3
#
sub no_I18N_Japanese
{
  shift;
  if( @_ )
  {
    my $bits = 0;
    foreach( @_ )
    {
      $bits |= 0x1000000 if $_ eq 're';
      $bits |= 0x2000000 if $_ eq 'tr';
      $bits |= 0x4000000 if $_ eq 'format';
      $bits |= 0x8000000 if $_ eq 'string';
    }
    $^H &= ~$bits;
  }else
  {
    $^H &= ~0x0f00_0000;
  }
}

1;

=head1 NAME

Unicode::Japanese - Japanese Character Encoding Handler

=head1 SYNOPSIS

use Unicode::Japanese;

# convert utf8 -> sjis

print Unicode::Japanese->new($str)->sjis;

# convert sjis -> utf8

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

On converting Unicode to SJIS (and EUC-JP/JIS), those encodings that cannot
be converted to SJIS (except "EMOJI") are escaped in "&#dddd;" format.
"EMOJI" on Unicode Private Use Area is going to be '?'.
When converting strings from Unicode to SJIS of mobile phones,
any characters not up to their standard is going to be '?'

=item *

On perl-5.8.0 and later, setting of utf-8 flag is performed properly.
utf8() method returns utf-8 `bytes' string and
getu() method returns utf-8 `char' string.

get() method returns utf-8 `bytes' string in current release.
in future, the behavior of get() maybe change.

sjis(), jis(), utf8(), etc.. methods return bytes string.
The input of new, set, and a getcode method is not asked about utf8/bytes.

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
If '$icode' is omitted, string is considered as UTF-8.

To specify a encodings, choose from the following;
'jis', 'sjis', 'euc', 'utf8',
'ucs2', 'ucs4', 'utf16', 'utf16-ge', 'utf16-le',
'utf32', 'utf32-ge', 'utf32-le', 'ascii', 'binary',
'sjis-imode', 'sjis-doti', 'sjis-jsky'.

'&#dddd' will be converted to "EMOJI", when specified 'sjis-imode'
or 'sjis-doti'.

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

return `bytes' string in current release,
this behavior will be changed.

utf8() method for `character' string or
getu() method for `bytes' string seems better.

=item $str = $s->getu

=over 2

=item $str: string (UTF-8)

=back

Gets a string with UTF-8.

On perl-5.8.0 and later, return value is with utf-8 flag.

=item $code = $s->getcode($str)

=over 2

=item $str: string

=item $code: character encoding name

=back

Detects the character encodings of I<$str>.

Notice: This method detects B<NOT> encoding of the string in the instance
but I<$str>.

Character encodings are distinguished by the following algorithm:

(In case of PurePerl)

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

If it is in proper EUC-JP, the encoding is euc.

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

(In case of XS)

=over 4

=item 1

If BOM of UTF-32 is found, the encoding is utf32.

=item 2

If BOM of UTF-16 is found, the encoding is utf16.

=item 3

String is checked by State Transition if it is applicable
for any listed encodings below. 

ascii / euc-jp / sjis / jis / utf8 / utf32-be / utf32-le / sjis-jsky /
sjis-imode / sjis-doti

=item 4

The listed order below is applied for a final determination.

utf32-be / utf32-le / ascii / jis / euc-jp / sjis / sjis-jsky / sjis-imode /
sjis-doti / utf8

=item 5

If none above is true, the encoding is unknown.


=back

Regarding the algorithm, pay attention to the following:

=over 2

=item *

UTF-8 is occasionally detected as SJIS.

=item *

Can NOT detect UCS2 automatically.

=item *

Can detect UTF-16 only when the string has BOM.

=item *

Can detect "EMOJI" when it is stored in binary, not in "&#dddd;"
format. (If only stored in "&#dddd;" format, getcode() will
return incorrect result. In that case, "EMOJI" will be crashed.)

=back

Because each of XS and PurePerl has a different algorithm, A result of
the detection would be possibly different.  In case that the string is
SJIS with escape characters, it would be considered as SJIS on
PurePerl.  However, it can't be detected as S-JIS on XS. This is
because by using Algorithm, the string can't be distinguished between
SJIS and SJIS-Jsky.  This exclusion of escape characters on XS from
the detection is suppose to be the same for EUC-JP.
  
=item $str = $s->conv($ocode, $encode)

=over 2

=item $ocode: output character encoding (Choose from 'jis', 'sjis', 'euc', 'utf8', 'ucs2', 'ucs4', 'utf16', 'binary')

=item $encode: encoding, may be omitted.

=item $str: string

=back

Gets a string converted to I<$ocode>.

For ASCII encoding, only 'base64' may be specified. With it, the string
encoded in base64 will be returned.

On perl-5.8.0 and later, return value is not with utf-8 flag, and is 
bytes string.

=item $s->tag2bin

Replaces the substrings "&#dddd;" in the string with the binary entity
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

$str: string (EUC-JP)

Gets the string converted to EUC-JP.

=item $str = $s->utf8

$str: `bytes' string (UTF-8)

Gets the string converted to UTF-8.

On perl-5.8.0 and later, return value is not with utf-8 flag, and is
bytes string.

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
This method is alias of sjis_imode2 on VERSION 0.15.

=item $str = $s->sjis_imode1

$str: string (SJIS/imode_EMOJI)

Gets the string converted to SJIS for i-mode.
$str includes only basic pictgraphs, and is without extended pictgraphs.

=item $str = $s->sjis_imode2

$str: string (SJIS/imode_EMOJI)

Gets the string converted to SJIS for i-mode.
$str includes both basic pictgraphs, and extended ones.

=item $str = $s->sjis_doti

$str: string (SJIS/dot-i_EMOJI)

Gets the string converted to SJIS for dot-i.

=item $str = $s->sjis_jsky

$str: string (SJIS/J-SKY_EMOJI)

Gets the string converted to SJIS for j-sky.
This method is alias of sjis_jsky2 on VERSION 0.15.

=item $str = $s->sjis_jsky1

$str: string (SJIS/J-SKY_EMOJI)

Gets the string converted to SJIS for j-sky.
$str includes from Page 1 to Page 3.

=item $str = $s->sjis_jsky

$str: string (SJIS/J-SKY_EMOJI)

Gets the string converted to SJIS for j-sky.
$str includes from Page 1 to Page 6.

=item @str = $s->strcut($len)

=over 2

=item $len: number of characters

=item @str: strings

=back

Splits the string by length(I<$len>).

On perl-5.8.0 and later, each element in return array
is with utf-8 flag.

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

on perl-5.8.0 and later, utf-8 flag of return value depends on
icode of set method. if $s contains binary, return value is bytes
too. if $s contains any string, return value is with utf-8 flag.

=back


=head1 DESCRIPTION OF UNICODE MAPPING

=over 2

=item SJIS

Mapped as MS-CP932. Mapping table in the following URL is used.

ftp://ftp.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP932.TXT

If a character cannot be mapped to SJIS from Unicode,
it will be converted to &#dddd; format.

Also, any unmapped character will be converted into "?" when converting
to SJIS for mobile phones.

=item EUC-JP/JIS

Converted to SJIS and then mapped to Unicode. Any non-SJIS character
in the string will not be mapped correctly.

=item DoCoMo i-mode

Portion of involving "EMOJI" in F800 - F9FF is maapped
 to U+0FF800 - U+0FF9FF.

=item ASTEL dot-i

Portion of involving "EMOJI" in F000 - F4FF is mapped
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

=head1 PurePerl mode

   use Unicode::Japanese qw(PurePerl);

If module was loaded with 'PurePerl' keyword,
it works on Non-XS mode.

=head1 BUGS

=over 2

=item *

EUC-JP, JIS strings cannot be converted correctly when they include
non-SJIS characters because they are converted to SJIS before
being converted to UTF-8.

=item *

Some characters of CP932 not in standard Shift_JIS
(ex; not in Joyo Kanji) will not be detected and converted. 

When string include such non-standard Shift_JIS,
they will not detected as SJIS.
Also, getcode() and all convert method will not work correctly.

=item *

When using XS, character encoding detection of EUC-JP and
SJIS(included all EMOJI) strings when they include "\e" will
fail. Also, getcode() and all convert method will not work.

=item *

The Japanese.pm file will collapse if sent via ASCII mode of FTP,
as it has a trailing binary data.

=back

=head1 AUTHOR INFORMATION

Copyright 2001-2004
SANO Taku (SAWATARI Mikage) and YAMASHINA Hio.
All right reserved.

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
  ›{'utf16'=>{'length'=>187,'offset'=>0},'joinCsv'=>{'length'=>939,'offset'=>187},'_decodeBase64'=>{'length'=>609,'offset'=>1126},'z2hNum'=>{'length'=>284,'offset'=>1735},'_utf16le_utf16'=>{'length'=>179,'offset'=>3261},'kata2hira'=>{'length'=>1242,'offset'=>2019},'_u2si2'=>{'length'=>1621,'offset'=>3440},'z2hAlpha'=>{'length'=>836,'offset'=>5061},'jcode/emoji2/eu2i.dat'=>{'length'=>8192,'offset'=>204926},'splitCsv'=>{'length'=>465,'offset'=>5897},'jcode/emoji2/eu2i2.dat'=>{'length'=>8192,'offset'=>215166},'_ucs4_utf8'=>{'length'=>936,'offset'=>6362},'h2zSym'=>{'length'=>316,'offset'=>7298},'sjis_jsky1'=>{'length'=>70,'offset'=>7614},'h2z'=>{'length'=>114,'offset'=>7684},'_s2j3'=>{'length'=>355,'offset'=>7798},'_u2s'=>{'length'=>2209,'offset'=>8153},'sjis'=>{'length'=>177,'offset'=>10362},'_u2si1'=>{'length'=>1620,'offset'=>10539},'_sj2u1'=>{'length'=>1144,'offset'=>12159},'tag2bin'=>{'length'=>328,'offset'=>13303},'z2hSym'=>{'length'=>596,'offset'=>13631},'_utf16_utf8'=>{'length'=>769,'offset'=>14227},'ucs2'=>{'length'=>183,'offset'=>14996},'jcode/emoji2/ei2u2.dat'=>{'length'=>2048,'offset'=>213118},'h2zNum'=>{'length'=>174,'offset'=>15179},'_si2u1'=>{'length'=>1228,'offset'=>15353},'h2zKanaK'=>{'length'=>979,'offset'=>16581},'strlen'=>{'length'=>360,'offset'=>17560},'_utf8_utf16'=>{'length'=>950,'offset'=>17920},'sjis_jsky2'=>{'length'=>70,'offset'=>18870},'jcode/emoji2/ei2u.dat'=>{'length'=>2048,'offset'=>202878},'getcode'=>{'length'=>1776,'offset'=>18940},'sjis_imode2'=>{'length'=>71,'offset'=>20716},'_j2s2'=>{'length'=>382,'offset'=>20787},'_validate_utf8'=>{'length'=>789,'offset'=>21169},'set'=>{'length'=>2980,'offset'=>24860},'_ucs2_utf8'=>{'length'=>549,'offset'=>24311},'_utf16_utf16'=>{'length'=>300,'offset'=>24011},'h2zAlpha'=>{'length'=>264,'offset'=>23747},'z2hKanaK'=>{'length'=>979,'offset'=>22768},'h2zKanaD'=>{'length'=>810,'offset'=>21958},'_sj2u2'=>{'length'=>1503,'offset'=>27840},'jcode/emoji2/ed2u.dat'=>{'length'=>5120,'offset'=>270462},'_utf32_ucs4'=>{'length'=>312,'offset'=>29343},'sjis_imode1'=>{'length'=>71,'offset'=>29655},'utf8'=>{'length'=>187,'offset'=>29726},'_s2e'=>{'length'=>244,'offset'=>30187},'h2zKana'=>{'length'=>185,'offset'=>30002},'z2hKana'=>{'length'=>89,'offset'=>29913},'_si2u2'=>{'length'=>1227,'offset'=>32204},'_u2sj1'=>{'length'=>1773,'offset'=>30431},'_u2sj2'=>{'length'=>1774,'offset'=>33431},'jcode/s2u.dat'=>{'length'=>48573,'offset'=>154305},'conv'=>{'length'=>1781,'offset'=>35205},'sjis_doti'=>{'length'=>188,'offset'=>36986},'_e2s'=>{'length'=>202,'offset'=>37174},'_utf16be_utf16'=>{'length'=>71,'offset'=>37376},'jcode/emoji2/eu2j.dat'=>{'length'=>20480,'offset'=>226430},'jcode/emoji2/ej2u2.dat'=>{'length'=>3072,'offset'=>246910},'hira2kata'=>{'length'=>1242,'offset'=>37447},'euc'=>{'length'=>175,'offset'=>38689},'_j2s3'=>{'length'=>337,'offset'=>38864},'jcode/emoji2/ej2u.dat'=>{'length'=>3072,'offset'=>223358},'ucs4'=>{'length'=>183,'offset'=>39201},'_sd2u'=>{'length'=>1221,'offset'=>39384},'sjis_doti1'=>{'length'=>69,'offset'=>40605},'_s2j'=>{'length'=>272,'offset'=>40674},'_s2e2'=>{'length'=>446,'offset'=>40946},'z2hKanaD'=>{'length'=>498,'offset'=>41392},'_u2sd'=>{'length'=>1616,'offset'=>41890},'jcode/emoji2/eu2j2.dat'=>{'length'=>20480,'offset'=>249982},'jcode/emoji2/eu2d.dat'=>{'length'=>8192,'offset'=>275582},'jcode/u2s.dat'=>{'length'=>85504,'offset'=>68801},'_utf8_ucs2'=>{'length'=>672,'offset'=>43506},'join_csv'=>{'length'=>29,'offset'=>44178},'_s2u'=>{'length'=>988,'offset'=>44207},'_utf32le_ucs4'=>{'length'=>178,'offset'=>45195},'sjis_jsky'=>{'length'=>189,'offset'=>45373},'_e2s2'=>{'length'=>535,'offset'=>45754},'sjis_imode'=>{'length'=>192,'offset'=>45562},'_s2j2'=>{'length'=>376,'offset'=>46289},'jis'=>{'length'=>179,'offset'=>46665},'_utf8_ucs4'=>{'length'=>1149,'offset'=>47585},'_encodeBase64'=>{'length'=>741,'offset'=>46844},'get'=>{'length'=>162,'offset'=>48734},'z2h'=>{'length'=>114,'offset'=>48896},'validate_utf8'=>{'length'=>129,'offset'=>49276},'getu'=>{'length'=>266,'offset'=>49010},'split_csv'=>{'length'=>131,'offset'=>49405},'_loadConvTable'=>{'length'=>18009,'offset'=>49536},'strcut'=>{'length'=>1009,'offset'=>67545},'_utf32be_ucs4'=>{'length'=>70,'offset'=>68554},'_j2s'=>{'length'=>177,'offset'=>68624}}# -----------------------------------------------------------------------------
# $bytes_utf16 = $unijp->utf16();
# 
sub utf16
{
  my $this = shift;
  $this->_utf8_utf16($this->{str});
}
sub joinCsv {
  my $this = shift;
  my $list;
  
  if(ref($_[0]) eq 'ARRAY')
    {
      $list = shift;
      if( $]>=5.008 )
      {
	$list = [ @$list ];
	foreach(@$list)
	{
	  defined($_) and Encode::_utf8_off($_);
	}
      }
    }
  elsif(!ref($_[0]))
    {
      $list = [ @_ ];
      if( $]>=5.008 )
      {
	foreach(@$list)
	{
	  defined($_) and Encode::_utf8_off($_);
	}
      }
    }
  else
    {
      my $ref = ref($_[0]);
      die "String->joinCsv, Param[1] is not ARRAY/ARRRAY-ref. [$ref]\n";
    }
      
  my $text;
  if( $^W && grep{!defined($_)}@$list )
  {
    $_[0] && $list eq $_[0] and $list = [@$list];
    foreach(@$list)
    {
      defined($_) and next;
      warn "Use of uninitialized value in Unicode::Japanese::joinCsv";
      $_ = "";
    }
  }
  $text = join ',', map {defined($_) ? (s/"/""/g or /[\r\n,]/) ? qq("$_") : $_ : ""} @$list;

  $this->{str} = $text."\n";
  $this->{icode} = 'binary';

  $this;
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
sub z2hNum {
  my $this = shift;

  if(!defined(%_z2hNum))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbc\x90|\xef\xbc\x91|\xef\xbc\x92|\xef\xbc\x93|\xef\xbc\x94|\xef\xbc\x95|\xef\xbc\x96|\xef\xbc\x97|\xef\xbc\x98|\xef\xbc\x99)/$_z2hNum{$1}/eg;
  
  $this;
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
sub _u2si2 {
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

  if(!defined($eu2i2))
    {
      $eu2i2 = $this->_getFile('jcode/emoji2/eu2i2.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|(.)/
    defined($2) ? '?' :
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
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
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
			    $c = substr($eu2i2, ($ch - 0x0ff000) * 2, 2),
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
sub z2hAlpha {
  my $this = shift;

  if(!defined(%_z2hAlpha))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbc\xa1|\xef\xbc\xa2|\xef\xbc\xa3|\xef\xbc\xa4|\xef\xbc\xa5|\xef\xbc\xa6|\xef\xbc\xa7|\xef\xbc\xa8|\xef\xbc\xa9|\xef\xbc\xaa|\xef\xbc\xab|\xef\xbc\xac|\xef\xbc\xad|\xef\xbc\xae|\xef\xbc\xaf|\xef\xbc\xb0|\xef\xbc\xb1|\xef\xbc\xb2|\xef\xbc\xb3|\xef\xbc\xb4|\xef\xbc\xb5|\xef\xbc\xb6|\xef\xbc\xb7|\xef\xbc\xb8|\xef\xbc\xb9|\xef\xbc\xba|\xef\xbd\x81|\xef\xbd\x82|\xef\xbd\x83|\xef\xbd\x84|\xef\xbd\x85|\xef\xbd\x86|\xef\xbd\x87|\xef\xbd\x88|\xef\xbd\x89|\xef\xbd\x8a|\xef\xbd\x8b|\xef\xbd\x8c|\xef\xbd\x8d|\xef\xbd\x8e|\xef\xbd\x8f|\xef\xbd\x90|\xef\xbd\x91|\xef\xbd\x92|\xef\xbd\x93|\xef\xbd\x94|\xef\xbd\x95|\xef\xbd\x96|\xef\xbd\x97|\xef\xbd\x98|\xef\xbd\x99|\xef\xbd\x9a)/$_z2hAlpha{$1}/eg;
  
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

  if( $]>=5.008 && $this->{icode} ne 'binary' )
  {
    foreach(@field)
    {
      Encode::_utf8_on($_);
    }
  }

  \@field;
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
sub h2zSym {
  my $this = shift;

  if(!defined(%_h2zSym))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\x20|\x21|\x22|\x23|\x24|\x25|\x26|\x27|\x28|\x29|\x2a|\x2b|\x2c|\x2d|\x2e|\x2f|\x3a|\x3b|\x3c|\x3d|\x3e|\x3f|\x40|\x5b|\x5c|\x5d|\x5e|_|\x60|\x7b|\x7c|\x7d|\x7e)/$_h2zSym{$1}/eg;
  
  $this;
}
sub sjis_jsky1
{
  my $this = shift;
  $this->_u2sj1($this->{str});
}
sub h2z {
  my $this = shift;

  $this->h2zKana;
  $this->h2zNum;
  $this->h2zAlpha;
  $this->h2zSym;

  $this;
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
# -----------------------------------------------------------------------------
# utf8 ==> sjis/³¨Ê¸»ú
#
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
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|(.)/
    defined($2) ? '?' : (
    $U2S{$1}
      or ($U2S{$1}
	  = ((length($1) == 1) ? $1 :
	     (length($1) == 2) ? (
				  ($c1,$c2) = unpack("C2", $1),
				  $ch = (($c1 & 0x1F)<<6)|($c2 & 0x3F),
				  $c = substr($u2s_table, $ch * 2, 2),
				  # UTF-3¥Ð¥¤¥È(U+0x80-U+07FF)¤«¤ésjis-1¥Ð¥¤¥È¤Ø¤Î¥Þ¥Ã¥Ô¥ó¥°¤Ï¤Ê¤¤¤Î¤Ç\0¤òºï½ü¤ÏÉ¬Í×¤Ï¤Ê¤¤
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
				    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
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
	     (length($1) == 5) ? (($c1,$c2,$c3,$c4,$c5) = unpack("C5", $1),
				  $ch = (($c1 & 0x03) << 24)|(($c2 & 0x3F) << 18)|
				  (($c3 & 0x3f) << 12)|(($c4 & 0x3f) << 6)|
				  ($c5 & 0x3F),
				  '&#' . $ch . ';'
				 ) :
	                         (
				  ($c1,$c2,$c3,$c4,$c5,$c6) = unpack("C6", $1),
				  $ch = (($c1 & 0x03) << 30)|(($c2 & 0x3F) << 24)|
				  (($c3 & 0x3f) << 18)|(($c4 & 0x3f) << 12)|
				  (($c5 & 0x3f) << 6)|($c6 & 0x3F),
				  '&#' . $ch . ';'
				 )
	    )
	 )
			 )
	/eg;
  $str;
  
}
# -----------------------------------------------------------------------------
# $bytes_sjis = $unijp->sjis();
# 
sub sjis
{
  my $this = shift;
  $this->_u2s($this->{str});
}
sub _u2si1 {
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

  if(!defined($eu2i1))
    {
      $eu2i1 = $this->_getFile('jcode/emoji2/eu2i.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|(.)/
    defined($2) ? '?' :
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
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
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
			    $c = substr($eu2i1, ($ch - 0x0ff000) * 2, 2),
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
sub _sj2u1 {
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

  if(!defined($ej2u1))
    {
      $ej2u1 = $this->_getFile('jcode/emoji2/ej2u.dat');
    }

  my $l;
  my $j1;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|$RE{E_JSKYv1}|[\x00-\xff])/
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
	($l >= 0xe000 and $l <= 0xffff) ?
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
	 $l =~ s,^$RE{E_JSKY_START}($RE{E_JSKY1v1}),,o,
	 $j1 = $1,
	 $uc = '',
	 $l =~ s!($RE{E_JSKY2})!$uc .= substr($ej2u1, (unpack('n', $j1 . $1) - 0x4500) * 4, 4), ''!ego,
	 $uc =~ tr,\0,,d,
	 $uc
	)
  /eg;
  
  $str;
  
}
# -----------------------------------------------------------------------------
# tag2bin
#
sub tag2bin {
  my $this = shift;

  $this->{str} =~ s/\&(\#\d+|\#x[a-f0-9A-F]+);/
    (substr($1, 1, 1) eq 'x') ? $this->_ucs4_utf8(pack('N', hex(substr($1, 2)))) :
      $this->_ucs4_utf8(pack('N', substr($1, 1)))
	/eg;
  
  $this;
}
sub z2hSym {
  my $this = shift;

  if(!defined(%_z2hSym))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x80\x80|\xef\xbc\x8c|\xef\xbc\x8e|\xef\xbc\x9a|\xef\xbc\x9b|\xef\xbc\x9f|\xef\xbc\x81|\xef\xbd\x80|\xef\xbc\xbe|\xef\xbc\xbf|\xef\xbc\x8f|\xef\xbd\x9e|\xef\xbd\x9c|\xe2\x80\x99|\xe2\x80\x9d|\xef\xbc\x88|\xef\xbc\x89|\xef\xbc\xbb|\xef\xbc\xbd|\xef\xbd\x9b|\xef\xbd\x9d|\xef\xbc\x8b|\xef\xbc\x8d|\xef\xbc\x9d|\xef\xbc\x9c|\xef\xbc\x9e|\xef\xbf\xa5|\xef\xbc\x84|\xef\xbc\x85|\xef\xbc\x83|\xef\xbc\x86|\xef\xbc\x8a|\xef\xbc\xa0|\xe3\x80\x9c)/$_z2hSym{$1}/eg;
  
  $this;
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
# -----------------------------------------------------------------------------
# $bytes_ucs2 = $unijp->ucs2();
# 
sub ucs2
{
  my $this = shift;
  $this->_utf8_ucs2($this->{str});
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
sub _si2u1 {
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

  if(!defined($ei2u1))
    {
      $ei2u1 = $this->_getFile('jcode/emoji2/ei2u.dat');
    }

  $str =~ s/(\&\#(\d+);)/
    ($2 >= 0xf800 and $2 <= 0xf9ff) ? pack('n', $2) : $1
      /eg;
  
  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|$RE{E_IMODEv1}|[\x00-\xff])/
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
	    ($l >= 0xf800 and $l <= 0xf9ff) ?
	    (
	     $uc = substr($ei2u1, ($l - 0xf800) * 4, 4),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xffff) ?
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
sub h2zKanaK {
  my $this = shift;

  if(!defined(%_h2zKanaK))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xef\xbd\xa1|\xef\xbd\xa2|\xef\xbd\xa3|\xef\xbd\xa4|\xef\xbd\xa5|\xef\xbd\xa6|\xef\xbd\xa7|\xef\xbd\xa8|\xef\xbd\xa9|\xef\xbd\xaa|\xef\xbd\xab|\xef\xbd\xac|\xef\xbd\xad|\xef\xbd\xae|\xef\xbd\xaf|\xef\xbd\xb0|\xef\xbd\xb1|\xef\xbd\xb2|\xef\xbd\xb3|\xef\xbd\xb4|\xef\xbd\xb5|\xef\xbd\xb6|\xef\xbd\xb7|\xef\xbd\xb8|\xef\xbd\xb9|\xef\xbd\xba|\xef\xbd\xbb|\xef\xbd\xbc|\xef\xbd\xbd|\xef\xbd\xbe|\xef\xbd\xbf|\xef\xbe\x80|\xef\xbe\x81|\xef\xbe\x82|\xef\xbe\x83|\xef\xbe\x84|\xef\xbe\x85|\xef\xbe\x86|\xef\xbe\x87|\xef\xbe\x88|\xef\xbe\x89|\xef\xbe\x8a|\xef\xbe\x8b|\xef\xbe\x8c|\xef\xbe\x8d|\xef\xbe\x8e|\xef\xbe\x8f|\xef\xbe\x90|\xef\xbe\x91|\xef\xbe\x92|\xef\xbe\x93|\xef\xbe\x94|\xef\xbe\x95|\xef\xbe\x96|\xef\xbe\x97|\xef\xbe\x98|\xef\xbe\x99|\xef\xbe\x9a|\xef\xbe\x9b|\xef\xbe\x9c|\xef\xbe\x9d|\xef\xbe\x9e|\xef\xbe\x9f)/$_h2zKanaK{$1}/eg;
  
  $this;
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
sub sjis_jsky2
{
  my $this = shift;
  $this->_u2sj2($this->{str});
}
# -----------------------------------------------------------------------------
# $code = Unicode::Japanese->getcode($str);
# 
sub getcode {
  my $this = shift;
  my $str = shift;

  if( $]>=5.008 )
  {
    Encode::_utf8_off($str);
  }
  
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
  1 while($str2 =~ s/^(?:$RE{ASCII}|$RE{SJIS_DBCS}|$RE{SJIS_KANA})//o);
  if($str2 eq '')
    {
      return 'sjis';
    }

  my $str3;
  $str3 = $str2;
  1 while($str3 =~ s/^(?:$RE{ASCII}|$RE{SJIS_DBCS}|$RE{SJIS_KANA}|$RE{E_IMODE})//o);
  if($str3 eq '')
    {
      return 'sjis-imode';
    }

  $str3 = $str2;
  1 while($str3 =~ s/^(?:$RE{ASCII}|$RE{SJIS_DBCS}|$RE{SJIS_KANA}|$RE{E_DOTI})//o);
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
sub sjis_imode2
{
  my $this = shift;
  $this->_u2si2($this->{str});
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
sub _validate_utf8
{
  my $pkg = shift;
  my $str = shift;
  
  defined($str) and $str =~ s{
     # 2 bytes char which is restricted 1 byte.
     #
     [\xc0-\xc1] [\x80-\xbf]   
    |
     # 3 bytes char which is restricted <= 2 bytes.
     #
     \xe0        [\x80-\x9f] [\x80-\xbf]
    |
     # 4 bytes char which is restricted <= 3 bytes.
     #
     \xf0        [\x80-\x8f] [\x80-\xbf] [\x80-\xbf]
    |
     # > U+10FFFF (4byte)
     #
     \xf4        [\x90-\xbf] [\x80-\xbf] [\x80-\xbf]
    |[\xf5-\xf7] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf]
    |
     # > U+10FFFF (5byte)
     #
     [\xf8-\xfb] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf]
    |
     # > U+10FFFF (6byte)
     #
     [\xfc-\xfd] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf]
  }{?}xg;
  $str;
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
sub z2hKanaK {
  my $this = shift;

  if(!defined(%_z2hKanaK))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x80\x81|\xe3\x80\x82|\xe3\x83\xbb|\xe3\x82\x9b|\xe3\x82\x9c|\xe3\x83\xbc|\xe3\x80\x8c|\xe3\x80\x8d|\xe3\x82\xa1|\xe3\x82\xa2|\xe3\x82\xa3|\xe3\x82\xa4|\xe3\x82\xa5|\xe3\x82\xa6|\xe3\x82\xa7|\xe3\x82\xa8|\xe3\x82\xa9|\xe3\x82\xaa|\xe3\x82\xab|\xe3\x82\xad|\xe3\x82\xaf|\xe3\x82\xb1|\xe3\x82\xb3|\xe3\x82\xb5|\xe3\x82\xb7|\xe3\x82\xb9|\xe3\x82\xbb|\xe3\x82\xbd|\xe3\x82\xbf|\xe3\x83\x81|\xe3\x83\x83|\xe3\x83\x84|\xe3\x83\x86|\xe3\x83\x88|\xe3\x83\x8a|\xe3\x83\x8b|\xe3\x83\x8c|\xe3\x83\x8d|\xe3\x83\x8e|\xe3\x83\x8f|\xe3\x83\x92|\xe3\x83\x95|\xe3\x83\x98|\xe3\x83\x9b|\xe3\x83\x9e|\xe3\x83\x9f|\xe3\x83\xa0|\xe3\x83\xa1|\xe3\x83\xa2|\xe3\x83\xa3|\xe3\x83\xa4|\xe3\x83\xa5|\xe3\x83\xa6|\xe3\x83\xa7|\xe3\x83\xa8|\xe3\x83\xa9|\xe3\x83\xaa|\xe3\x83\xab|\xe3\x83\xac|\xe3\x83\xad|\xe3\x83\xaf|\xe3\x83\xb2|\xe3\x83\xb3)/$_z2hKanaK{$1}/eg;
  
  $this;
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
# -----------------------------------------------------------------------------
# Unicode Æâ Áê¸ßÊÑ´¹
# 
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
# -----------------------------------------------------------------------------
# $unijp->set($str,[$icode,[$encode]]);
# 
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

  if( $]>=5.008 )
  {
    Encode::_utf8_off($str);
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
    { # omitted then 'utf8'
      $this->{str} = $this->_validate_utf8($str);
      $this->{icode} = 'utf8';
    }
  else
    {
      $icode = lc($icode);
      if($icode eq 'auto')
	{
	  $icode = $this->getcode($str);
	  if($icode eq 'unknown')
	    {
	      $icode = 'binary';
	    }
	}

      if($icode eq 'utf8')
	{
	  $this->{str} = $this->_validate_utf8($str);
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
	  $this->{str} = $this->_s2u($this->_j2s($str));
	}
      elsif($icode eq 'euc')
	{
	  $this->{str} = $this->_s2u($this->_e2s($str));
	}
      elsif($icode eq 'sjis')
	{
	  $this->{str} = $this->_s2u($str);
	}
      elsif($icode eq 'sjis-imode')
	{
	  $this->{str} = $this->_si2u2($str);
	}
      elsif($icode eq 'sjis-imode1')
	{
	  $this->{str} = $this->_si2u1($str);
	}
      elsif($icode eq 'sjis-imode2')
	{
	  $this->{str} = $this->_si2u2($str);
	}
      elsif($icode eq 'sjis-doti')
	{
	  $this->{str} = $this->_sd2u($str);
	}
      elsif($icode eq 'sjis-doti1')
	{
	  $this->{str} = $this->_sd2u($str);
	}
      elsif($icode eq 'sjis-jsky')
	{
	  $this->{str} = $this->_sj2u2($str);
	}
      elsif($icode eq 'sjis-jsky1')
	{
	  $this->{str} = $this->_sj2u1($str);
	}
      elsif($icode eq 'sjis-jsky2')
	{
	  $this->{str} = $this->_sj2u2($str);
	}
      elsif($icode eq 'ascii')
	{
	  $this->{str} = $str;
	}
      elsif($icode eq 'binary')
	{
	  $this->{str} = $str;
	}
      else
	{
	  use Carp;
	  croak "icode error [$icode]";
	}
      $this->{icode} = $icode;
    }

  $this;
}
sub _sj2u2 {
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

  if(!defined($ej2u1))
  {
    $ej2u1 = $this->_getFile('jcode/emoji2/ej2u.dat');
  }
  if(!defined($ej2u2))
  {
    $ej2u2 = $this->_getFile('jcode/emoji2/ej2u2.dat');
  }

  my $l;
  my $j1;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|$RE{E_JSKY}|[\x00-\xff])/
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
	($l >= 0xe000 and $l <= 0xffff) ?
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
         ( $l =~ s,^$RE{E_JSKY_START}($RE{E_JSKY1v1}),,o
	   ?
	   (
	    $j1 = $1,
	    $uc = '',
	    $l =~ s!($RE{E_JSKY2})!$uc .= substr($ej2u1, (unpack('n', $j1 . $1) - 0x4500) * 4, 4), ''!ego,
	    $uc =~ tr,\0,,d,
	    $uc
	    )
	   :
	   (
	    $l =~ s,^$RE{E_JSKY_START}($RE{E_JSKY1v2}),,o,
	    $j1 = $1,
	    $uc = '',
	    $l =~ s!($RE{E_JSKY2})!$uc .= substr($ej2u2, (unpack('n', $j1 . $1) - 0x4f00) * 4, 4), ''!ego,
	    $uc =~ tr,\0,,d,
	    $uc
	    )
	   )
	)
  /eg;
  
  $str;
  
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
sub sjis_imode1
{
  my $this = shift;
  $this->_u2si1($this->{str});
}
# -----------------------------------------------------------------------------
# $bytes_utf8 = $unijp->utf8();
# 
sub utf8
{
  my $this = shift;
  $this->_validate_utf8($this->{str});
}
sub z2hKana
{
  my $this = shift;
  
  $this->z2hKanaD;
  $this->z2hKanaK;
  
  $this;
}
# -----------------------------------------------------------------------------
# h2z/z2h Kana
# 
sub h2zKana
{
  my $this = shift;

  $this->h2zKanaD;
  $this->h2zKanaK;
  
  $this;
}
sub _s2e {
  my $this = shift;
  my $str = shift;
  
  if( $]>=5.008 )
  {
    Encode::_utf8_off($str);
  }

  $str =~ s/($RE{SJIS_DBCS}|$RE{SJIS_KANA})/
    $S2E[unpack('n', $1) or unpack('C', $1)] or $this->_s2e2($1)
      /geo;
  
  $str;
}
sub _u2sj1 {
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

  if(!defined($eu2j1))
    {
      $eu2j1 = $this->_getFile('jcode/emoji2/eu2j.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|(.)/
    defined($2) ? '?' :
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
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
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
			    $c = substr($eu2j1, ($ch - 0x0ff000) * 5, 5),
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
sub _si2u2 {
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

  if(!defined($ei2u2))
    {
      $ei2u2 = $this->_getFile('jcode/emoji2/ei2u2.dat');
    }

  $str =~ s/(\&\#(\d+);)/
    ($2 >= 0xf800 and $2 <= 0xf9ff) ? pack('n', $2) : $1
      /eg;
  
  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|$RE{E_IMODE}|[\x00-\xff])/
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
	    ($l >= 0xf800 and $l <= 0xf9ff) ?
	    (
	     $uc = substr($ei2u2, ($l - 0xf800) * 4, 4),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xffff) ?
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
sub _u2sj2 {
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

  if(!defined($eu2j2))
    {
      $eu2j2 = $this->_getFile('jcode/emoji2/eu2j2.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|(.)/
    defined($2) ? '?' :
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
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
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
			    $c = substr($eu2j2, ($ch - 0x0ff000) * 5, 5),
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
# -----------------------------------------------------------------------------
# $bytes_str = $unijp->conv($ocode,[$encode]);
# 
sub conv {
  my $this = shift;
  my $ocode = shift;
  my $encode = shift;
  my (@option) = @_;

  my $res;
  if(!defined($ocode))
    {
      use Carp;
      croak(qq(String->conv, Param[1] is undef.));
    }
  elsif($ocode eq 'utf8')
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
  elsif($ocode eq 'sjis-imode1')
    {
      $res = $this->sjis_imode1;
    }
  elsif($ocode eq 'sjis-imode2')
    {
      $res = $this->sjis_imode2;
    }
  elsif($ocode eq 'sjis-doti')
    {
      $res = $this->sjis_doti;
    }
  elsif($ocode eq 'sjis-doti1')
    {
      $res = $this->sjis_doti;
    }
  elsif($ocode eq 'sjis-jsky')
    {
      $res = $this->sjis_jsky;
    }
  elsif($ocode eq 'sjis-jsky1')
    {
      $res = $this->sjis_jsky1;
    }
  elsif($ocode eq 'sjis-jsky2')
    {
      $res = $this->sjis_jsky2;
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
      use Carp;
      croak(qq(String->conv, Param[1] "$ocode" is error.));
    }

  if(defined($encode))
    {
      if($encode eq 'base64')
	{
	  $res = $this->_encodeBase64($res, @option);
	}
      else
	{
	  use Carp;
	  croak(qq(String->conv, Param[2] "$encode" encode name error.));
	}
    }

  $res;
}
# -----------------------------------------------------------------------------
# $bytes_doti = $unijp->sjis_doti();
# 
sub sjis_doti
{
  my $this = shift;
  $this->_u2sd($this->{str});
}
sub _e2s {
  my $this = shift;
  my $str = shift;

  $str =~ s/($RE{EUC_KANA}|$RE{EUC_0212}|$RE{EUC_C})/
    $E2S[unpack('n', $1) or unpack('N', "\0" . $1)] or $this->_e2s2($1)
      /geo;
  
  $str;
}
sub _utf16be_utf16 {
  my $this = shift;
  my $str = shift;

  $str;
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
# -----------------------------------------------------------------------------
# $bytes_eucjp = $unijp->euc();
# 
sub euc
{
  my $this = shift;
  $this->_s2e($this->sjis);
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
# -----------------------------------------------------------------------------
# $bytes_ucs4 = $unijp->ucs4();
# 
sub ucs4
{
  my $this = shift;
  $this->_utf8_ucs4($this->{str});
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
      $ed2u = $this->_getFile('jcode/emoji2/ed2u.dat');
    }

  $str =~ s/(\&\#(\d+);)/
    ($2 >= 0xf000 and $2 <= 0xf4ff) ? pack('n', $2) : $1
      /eg;
  
  my $l;
  my $uc;
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|$RE{E_DOTI}|[\x00-\xff])/
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
	    ($l >= 0xf000 and $l <= 0xf4ff) ?
	    (
	     $uc = substr($ed2u, ($l - 0xf000) * 4, 4),
	     $uc =~ tr,\0,,d,
	     $uc
	    ) :
	    ($l >= 0xe000 and $l <= 0xffff) ?
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
sub sjis_doti1
{
  my $this = shift;
  $this->_u2sd($this->{str});
}
# -----------------------------------------------------------------------------
# conversion methods (private).
# 
sub _s2j {
  my $this = shift;
  my $str = shift;

  $str =~ s/((?:$RE{SJIS_DBCS}|$RE{SJIS_KANA})+)/
    $this->_s2j2($1) . $ESC{ASC}
      /geo;

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
sub z2hKanaD {
  my $this = shift;

  if(!defined(%_z2hKanaD))
    {
      $this->_loadConvTable;
    }

  $this->{str} =~ s/(\xe3\x82\xac|\xe3\x82\xae|\xe3\x82\xb0|\xe3\x82\xb2|\xe3\x82\xb4|\xe3\x82\xb6|\xe3\x82\xb8|\xe3\x82\xba|\xe3\x82\xbc|\xe3\x82\xbe|\xe3\x83\x80|\xe3\x83\x82|\xe3\x83\x85|\xe3\x83\x87|\xe3\x83\x89|\xe3\x83\x90|\xe3\x83\x91|\xe3\x83\x93|\xe3\x83\x94|\xe3\x83\x96|\xe3\x83\x97|\xe3\x83\x99|\xe3\x83\x9a|\xe3\x83\x9c|\xe3\x83\x9d|\xe3\x83\xb4)/$_z2hKanaD{$1}/eg;
  
  $this;
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
      $eu2d = $this->_getFile('jcode/emoji2/eu2d.dat');
    }

  my $c1;
  my $c2;
  my $c3;
  my $c4;
  my $c5;
  my $c6;
  my $c;
  my $ch;
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5})|(.)/
    defined($2) ? '?' :
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
			    (($c =~ tr,\0,,d)==2 and $c = "\0\0"),
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
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}|(.))/
    defined($2)?"\0$2":
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
sub join_csv {
  &joinCsv;
}
# -----------------------------------------------------------------------------
# sjis/³¨Ê¸»ú => utf8
# 
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
  $str =~ s/($RE{SJIS_KANA}|$RE{SJIS_DBCS}|[\x00-\xff])/
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
# -----------------------------------------------------------------------------
# $bytes_jsky = $unijp->sjis_jsky();
# 
sub sjis_jsky
{
  my $this = shift;
  $this->_u2sj2($this->{str});
}
# -----------------------------------------------------------------------------
# $bytes_imode = $unijp->sjis_imode();
# 
sub sjis_imode
{
  my $this = shift;
  $this->_u2si2($this->{str});
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
sub _s2j2 {
  my $this = shift;
  my $str = shift;

  $str =~ s/((?:$RE{SJIS_DBCS})+|(?:$RE{SJIS_KANA})+)/
    my $s = $1;
  if($s =~ m,^$RE{SJIS_KANA},)
    {
      $s =~ tr,\xa1-\xdf,\x21-\x5f,;
      $ESC{KANA} . $s
    }
  else
    {
      $s =~ s!($RE{SJIS_DBCS})!
	$S2J[unpack('n', $1)] or $this->_s2j3($1)
	  !geo;
      $ESC{JIS_0208} . $s;
    }
  /geo;
  
  $str;
}
# -----------------------------------------------------------------------------
# $bytes_iso2022jp = $unijp->jis();
# 
sub jis
{
  my $this = shift;
  $this->_s2j($this->sjis);
}
# -----------------------------------------------------------------------------
# encode/decode
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
  $str =~ s/([\x00-\x7f]|[\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf]{2}|[\xf0-\xf7][\x80-\xbf]{3}|[\xf8-\xfb][\x80-\xbf]{4}|[\xfc-\xfd][\x80-\xbf]{5}|(.))/
    defined($2) ? "\0\0\0$2" : 
    (length($1) == 1) ? pack("N", unpack("C", $1)) :
    (length($1) == 2) ? 
      do {
        ($c1,$c2) = unpack("C2", $1);
        my $n = (($c1 & 0x1F) << 6)|($c2 & 0x3F);
        pack("N", $n>=0x80 ? $n : unpack("C",'?'));
      } :
    (length($1) == 3) ?
      do {
        ($c1,$c2,$c3) = unpack("C3", $1);
        my $n = (($c1 & 0x0F) << 12)|(($c2 & 0x3F) << 6)| ($c3 & 0x3F);
        pack("N", $n>=0x800 ? $n : unpack("C",'?'));
      } :
    (length($1) == 4) ?
      do {
        ($c1,$c2,$c3,$c4) = unpack("C4", $1);
        my $n = (($c1 & 0x07) << 18)|(($c2 & 0x3F) << 12)|
                           (($c3 & 0x3f) << 6)|($c4 & 0x3F);
        pack("N", ($n>=0x010000 && $n<=0x10FFFF) ? $n : unpack("C",'?'));
      } :
      pack("N", unpack("C",'?'))
    /eg;

  $str;
}
# -----------------------------------------------------------------------------
# $bytes_utf8 = $unijp->get();
# 
sub get {
  my $this = shift;
  $this->{str};
}
sub z2h {
  my $this = shift;

  $this->z2hKana;
  $this->z2hNum;
  $this->z2hAlpha;
  $this->z2hSym;

  $this;
}
# -----------------------------------------------------------------------------
# $chars_utf8 = $unijp->getu();
# 
sub getu {
  my $this = shift;
  my $str = $this->{str};
  if( $]>=5.008 && $this->{icode} ne 'binary' )
  {
    Encode::_utf8_on($str);
  }
  $str;
}
sub validate_utf8
{
  # my $safer_utf8 = Unicode::Japanese->validate_utf8($utf8_str);
  #
  $_[0]->_validate_utf8(@_[1..$#_]);
}
# -----------------------------------------------------------------------------
# split/join Csv
# 
sub split_csv {
  &splitCsv;
}
sub _loadConvTable {


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
		"\x26" => "\xef\xbc\x86", "\x27" => "\xe2\x80\x99", 
		"\x28" => "\xef\xbc\x88", "\x29" => "\xef\xbc\x89", 
		"\x2a" => "\xef\xbc\x8a", "\x2b" => "\xef\xbc\x8b", 
		"\x2c" => "\xef\xbc\x8c", "\x2d" => "\xef\xbc\x8d", 
		"\x2e" => "\xef\xbc\x8e", "\x2f" => "\xef\xbc\x8f", 
		"\x3a" => "\xef\xbc\x9a", "\x3b" => "\xef\xbc\x9b", 
		"\x3c" => "\xef\xbc\x9c", "\x3d" => "\xef\xbc\x9d", 
		"\x3e" => "\xef\xbc\x9e", "\x3f" => "\xef\xbc\x9f", 
		"\x40" => "\xef\xbc\xa0", "\x5b" => "\xef\xbc\xbb", 
		"\x5c" => "\xef\xbf\xa5", "\x5d" => "\xef\xbc\xbd", 
		"\x5e" => "\xef\xbc\xbe", "_" => "\xef\xbc\xbf", 
		"\x60" => "\xef\xbd\x80", "\x7b" => "\xef\xbd\x9b", 
		"\x7c" => "\xef\xbd\x9c", "\x7d" => "\xef\xbd\x9d", 
		"\x7e" => "\xef\xbd\x9e", 
);



%_z2hSym = (
		"\xe3\x80\x80" => "\x20", "\xef\xbc\x8c" => "\x2c", 
		"\xef\xbc\x8e" => "\x2e", "\xef\xbc\x9a" => "\x3a", 
		"\xef\xbc\x9b" => "\x3b", "\xef\xbc\x9f" => "\x3f", 
		"\xef\xbc\x81" => "\x21", "\xef\xbd\x80" => "\x60", 
		"\xef\xbc\xbe" => "\x5e", "\xef\xbc\xbf" => "_", 
		"\xef\xbc\x8f" => "\x2f", "\xef\xbd\x9e" => "\x7e", 
		"\xef\xbd\x9c" => "\x7c", "\xe2\x80\x99" => "\x27", 
		"\xe2\x80\x9d" => "\x22", "\xef\xbc\x88" => "\x28", 
		"\xef\xbc\x89" => "\x29", "\xef\xbc\xbb" => "\x5b", 
		"\xef\xbc\xbd" => "\x5d", "\xef\xbd\x9b" => "\x7b", 
		"\xef\xbd\x9d" => "\x7d", "\xef\xbc\x8b" => "\x2b", 
		"\xef\xbc\x8d" => "\x2d", "\xef\xbc\x9d" => "\x3d", 
		"\xef\xbc\x9c" => "\x3c", "\xef\xbc\x9e" => "\x3e", 
		"\xef\xbf\xa5" => "\x5c", "\xef\xbc\x84" => "\x24", 
		"\xef\xbc\x85" => "\x25", "\xef\xbc\x83" => "\x23", 
		"\xef\xbc\x86" => "\x26", "\xef\xbc\x8a" => "\x2a", 
		"\xef\xbc\xa0" => "\x40", "\xe3\x80\x9c" => "\x7e", 
		
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
# -----------------------------------------------------------------------------
# strcut, strlen
# 
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
	  $line ne '' and push(@$result, $line);
	  $line = '';
	  $linelength = 0;
	}
      $linelength += (length($c) >= 3 ? 2 : 1);
      $line .= $c;
    }
  push(@$result, $line);

  if( $]>=5.008 && $this->{icode} ne 'binary' )
  {
    foreach(@$result)
    {
      Encode::_utf8_on($_);
    }
  }
  
  $result;
}
sub _utf32be_ucs4 {
  my $this = shift;
  my $str = shift;

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
          	 
                        ! " # $ % & ' ( ) * + , - . / 0 1 2 3 4 5 6 7 8 9 : ; < = > ? @ A B C D E F G H I J K L M N O P Q R S T U V W X Y Z [ \ ] ^ _ ` a b c d e f g h i j k l m n o p q r s t u v w x y z { | } ~                                                                                ˜N              ‹}    L  ÷                                                                ~                                                              €                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  ƒŸƒ ƒ¡ƒ¢ƒ£ƒ¤ƒ¥ƒ¦ƒ§ƒ¨ƒ©ƒªƒ«ƒ¬ƒ­ƒ®ƒ¯  ƒ°ƒ±ƒ²ƒ³ƒ´ƒµƒ¶              ƒ¿ƒÀƒÁƒÂƒÃƒÄƒÅƒÆƒÇƒÈƒÉƒÊƒËƒÌƒÍƒÎƒÏ  ƒÐƒÑƒÒƒÓƒÔƒÕƒÖ                                                                                                              „F                            „@„A„B„C„D„E„G„H„I„J„K„L„M„N„O„P„Q„R„S„T„U„V„W„X„Y„Z„[„\„]„^„_„`„p„q„r„s„t„u„w„x„y„z„{„|„}„~„€„„‚„ƒ„„„…„†„‡„ˆ„‰„Š„‹„Œ„„Ž„„„‘  „v                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            ]        \    ef    gh    õö      dc                  ñ  Œ              ¦                                                                                                                                                                                                                                                                                                                                                                                                              Ž                                    ‡‚                    ‡„                  ð                                                                                                        úJúKúLúM‡X‡Y‡ZúQúR‡]            ú@îðîñîòúDúEîõúGúHúI                                            ©ª¨«                                                                                                                            Ë  Ì                                                                                      Í  ÝÎ      Þ¸    ¹          ‡”                ‡•    å‡‡˜‡—        a  ÈÉ¿¾çè  ‡“          ˆú[              ä                                        à                          ‚‡‘        …†    áâ                                            ¼½    º»                                                          ‡–                                                  ‡™                                                                                                                                                                    Ü                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          ‡@‡A‡B‡C‡D‡E‡F‡G‡H‡I‡J‡K‡L‡M‡N‡O‡P‡Q‡R‡S                                                                                                                                                                                                                                                                                        „Ÿ„ª„ „«                „¡    „¬„¢    „­„¤    „¯„£    „®„¥„º    „µ    „°„§„¼    „·    „²„¦    „¶„»    „±„¨    „¸„½    „³„©    „¹    „¾                „´                                                                                                                                                                        ¡                                 £¢                ¥¤                Ÿž      ›    œ                                                              ü                                          š™                                                                                                                  Š  ‰                                                                              ô    ó  ò                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                @ABV  XYZqrstuvwxyz§¬kl            `‡€  ‡                                                                  ‚Ÿ‚ ‚¡‚¢‚£‚¤‚¥‚¦‚§‚¨‚©‚ª‚«‚¬‚­‚®‚¯‚°‚±‚²‚³‚´‚µ‚¶‚·‚¸‚¹‚º‚»‚¼‚½‚¾‚¿‚À‚Á‚Â‚Ã‚Ä‚Å‚Æ‚Ç‚È‚É‚Ê‚Ë‚Ì‚Í‚Î‚Ï‚Ð‚Ñ‚Ò‚Ó‚Ô‚Õ‚Ö‚×‚Ø‚Ù‚Ú‚Û‚Ü‚Ý‚Þ‚ß‚à‚á‚â‚ã‚ä‚å‚æ‚ç‚è‚é‚ê‚ë‚ì‚í‚î‚ï‚ð‚ñ              JKTU    ƒ@ƒAƒBƒCƒDƒEƒFƒGƒHƒIƒJƒKƒLƒMƒNƒOƒPƒQƒRƒSƒTƒUƒVƒWƒXƒYƒZƒ[ƒ\ƒ]ƒ^ƒ_ƒ`ƒaƒbƒcƒdƒeƒfƒgƒhƒiƒjƒkƒlƒmƒnƒoƒpƒqƒrƒsƒtƒuƒvƒwƒxƒyƒzƒ{ƒ|ƒ}ƒ~ƒ€ƒƒ‚ƒƒƒ„ƒ…ƒ†ƒ‡ƒˆƒ‰ƒŠƒ‹ƒŒƒƒŽƒƒƒ‘ƒ’ƒ“ƒ”ƒ•ƒ–        E[RS                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    ‡Š‡‹            ‡Œ                                                                                                                                                                                                                    ‡…‡†‡‡‡ˆ‡‰                                                                                                                                                                                    ‡e                  ‡i            ‡`      ‡c                  ‡a‡k    ‡j‡d      ‡l                    ‡f        ‡n                          ‡_‡m    ‡b      ‡g          ‡h                                                                      ‡~‡‡Ž‡                              ‡r‡s                        ‡o‡p‡q    ‡u                                                                    ‡t                ‡ƒ                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    ˆê’š  Žµ      –œäŽOã‰º  •s—^  ˜ ‰N    ŠŽ˜¡¢™À‹u•¸        å    —¼        •À  íL  ˜¢    ’†      ˜£‹ø      ˜¤  ŠÛ’O  Žå˜¥    ˜¦    ˜§”T  ‹v          ”V  “áŒÁ–R          åh˜¨æ˜©‰³      ‹ãŒî–ç    ›¤                            —  “û                    Š£  ‹T  ˜ª    ˜«—¹  —\‘ˆ˜­Ž–“ñ  ˜°    ‰]ŒÝ  ŒÜˆä    ˜j˜i  ±ˆŸ  ˜±˜²˜³–S˜´  Œðˆå–’  ‹œ    ‹‹ž’à—º  ˜µ    ˜¶    ˜·      l          Ym˜¼  ˜º  ˜»‹w    ¡‰î  ˜¹˜¸•§        ŽeŽd‘¼˜½•tå      W˜¾˜À  úi  ‘ã—ßˆÈ              ˜¿‰¼  ‹Â  ’‡      Œ˜Á      ”Cúj      úkŠé  íP          ˜ÂˆÉ    ŒÞŠê•š”°‹x                ‰ï  ˜å“`                                  ”Œ˜Ä      ”º  —à  LúmŽf  Ž—‰¾          ’Ï    ’A˜È          ˆÊ’áZ²—C  ‘Ì  ‰½ún˜Ç  —]˜Ã˜Åì˜Æ›C                    ˜Î          ˜Ñ˜Ï    ‰À  •¹˜É        ˜ÍŒñ    Žg      Š¤    ˜Ò  ˜Ê  íT—á  Ž˜  ˜Ë  ˜Ðúo  íV  ˜Ó  ˜Ì  íU‹Ÿ  ˆË    ‹ ‰¿                  ›D  –™•ŽŒò          N—µ                •Ö    ŒW‘£‰â        úar    íW˜×  ˜Ü˜Ú    ˜Õ    ‘­˜Ø  ˜Û˜Ù  •Û  ˜Ö  M  –“˜Ý˜Þ                C˜ë      ”o  •U˜æ  •î  ‰´      ˜êúv          ˜ä˜í    ‘q  ŒÂ  ”{  àÅ  ˜ì“|  ˜á  Œô    Œó˜ß      úwŽØ  ˜çúu•í’l˜ãŒ‘  ˜à˜è˜â—Ï˜é˜`                ‹ä    Œ            íX  úz˜î    úx˜ï˜óˆÌ          •Î˜ò        ˜ñ˜õ      ˜ô  ’â                Œ’            ˜ö      í]  ŽÃ  ‘¤’ã‹ô  ˜÷        ‹U    ˜ø        ˜ú              –T      Œ†    í_      ŽP”õ˜ù                                  Ã—b        ˜ü™B˜ûÂ              ŒX      ™C    ‹Í      ™@™A    “­  ‘œ  ‹¡      –l™D  ía  —»      ™E        ™H  ™F  ‘m          ™G™I          ú|™K      ™J  •Æ        ‹V™M™N  ‰­        ™L                Žò  ™Q™P™O  ˜Ô  ™R        ž  ™S                —D              –×        ™U    ™T™W™V    ™X™Yˆò  Œ³ŒZ[’›‹¢æŒõíbŽ™[–Æ“e  Ž™  ™Z  ™\          “}  Š•          ™]  ú€“ü    ‘S™_™`”ªŒö˜Z™a    ‹¤      •º‘´‹ï“T      Œ“      ™b  ™c    “à‰~    ™fû  ™eÄ  ™gãì™h–`™i  ™j™kç  ŽÊ      íd    Š¥  ™n  ™l–»™m  •y™o™p™q“~      ™u™s™t™rá™v–è—â          ™wú‚          ¦™xy    ™y  ’œ—½“€                ™Ã        ™zê£‹Ã    ™{–}        ˆ‘ú  ™}“â  íf™~    ™€ŠM      ™‹¥  “Ê‰šo    ”Ÿ™‚  “    n™ƒ  •ªØŠ   Š§™„    ™†    ŒY    ™…ú„  —ñ          ‰            ”»•Ê  ™‡  —˜™ˆ      ™‰  “ž    ™Š    §üŒ”™‹Žh              ’ä™    ‘¥    í™Ž™‘O  ™Œ        ™‘  –U        „    ™        Œ•Ü”      ™”™’        •›è™›Š„™•™“‘n              ™—  ™–      Šc      Œ€™œ—«      ™˜      ™™š  ™™            —Íú…    Œ÷‰Á    —ò    íi    •“w…™ ™¡  ûw  —ã    ˜J™£      Œø    ™¢  ŠN  íj™¤  –u  ’º  —E  •×      ™¥        èÓ    “®  ™¦Š¨–±  úˆ  Ÿ™§•å™«  ¨™¨‹Î  ™©Š©                    ŒM™¬  ™­    ™®™¯ŽÙ      Œù–Üíl–æ“õ    •ï™°úŠ™±        ™³  ™µ™´        ™¶‰»–k  ú™·    ‘x     ‹§  ™¸ín          ”Ù        ™¹  ™º  ™»        ™¼•C‹æˆã      “½™½\  ç  ™¿™¾¡Œß™Á”¼    ™Â      ”Ú‘²‘ì‹¦    “ì’P  ”Ž  –m  ™Ä  è          ŒT    ™Å        ™Æ‰KˆóŠëúŒ‘¦‹p—‘  ™É‰µ    ™È      ‹¨    ™Ê  –ï                            ú    ™Ë  —Ð  Œú        Œ´™Ì        ™Î™Í  ~‰X      ‰}™Ï  ™Ð  úŽŒµ    ™Ñ        ‹Ž            ŽQ™Ò        –”³‹y—F‘o”½Žû          f  ŽæŽó  –  ”¾  ú  ™Õ  ‰b‘pŒûŒÃ‹å    ™Ù’@‘ü‹©¢™Ú™Ø‰Â‘äŽ¶Žj‰E    Š†Ži  ™Û            ™Ü  ‹hŠe      ‡‹g’Ý‰D“¯–¼@—™“fŒü                  ŒN  ™å  ‹á–i          ”Û    ™ä  ŠÜ™ß™à™â              ™ã  ‹z  •«™á™ÝŒá  ™Þ  ˜C      •ð  ’æŒà      ™æ    “Û                          ™ê                Žü  Žô          ™í™ë  –¡  ™è™ñ™ì      ™ïŒÄ–½    ™ð      ™ò  ™ô      ú’î˜a  ™é™ç™ó  ™î                  ít          ™ö  šB™ø    ™üú“  š@™ù    š]    çŠP        ™÷      šDˆôšC  ˆ£•išA  ™ú    ™õ™ûÆ                            šE                ˆõšN    šFšG  £–‰      šLšK      “N              šM    šJ  ú”        ‰S  ´O              šH“‚      šI  ˆ                                               šS—B  ¥  šY        šXšO        ‘Á  šP      ‘íšU¤          šR    –â      Œ[    šVšW        šTšZ          šQ                                              š`še  ša  š\    šf‘P  ú•šh  Aš^’                        šbš[Š«  ŠìŠ…šcš_              Œ–šišg‘r‹i‹ª  šd  ‹ò          ‰c                          šmšk  š¥                        šp          šj  šn    šl      Žkšo                                    šr  šw      šušt              ’Q    ‰Ã                    šq  šs¦‰R    šv                          ‰Ü          š‚  úš}  š{  š|  š~                  ‰\                  ‘X  šx  šy                    Šš                š      Ší  š„š€šƒ              •¬      “Ó  ”¶          š†          š…Šd    š‡        šŠ        š‰                      šˆ  ”X    š‹                šŒ          šŽ  š          š      š“š‘šš’        š”          š•    š–  š—      š˜™d  ŽúŽl    ‰ñ  ˆö    ’c                    š™  ¢  ˆÍ}          ššŒÅ    ‘  šœš›    •Þš      šŸšž  š   š¡  Œ—    ‰€š¢    š¤  š£      š¦    “y            š§ˆ³Ý        Œ\    ’n            š¨š©    š«        š¬  â        ‹Ï    –V      šªš­¿B              ú–              š±    £ú—’R    š®’Ø                                        š²    ‚          š°š³  Œ^              š´                        šµ  CŠ_š·          š¸  í{      š¹    š¶                        š¯    šº    š»úší|    –„    é      š½š¾š¼  šÀ          ”W    ˆæ•u    šÁ                                û    Ž·  ”|Šî  é      –x  “°    Œ˜‘Í      š¿šÂ                  ‘Â      šÃ      šÄ      šÆ    ’ç          Š¬        êŸ‰•ñ    ê“g        ä    šÌ    •»—Û                ‰òšÈ          ‘YšË  “ƒ    “h“„”·’Ë      Ç      šÇ            ‰–  “U        šÉ  šÅ    o      šÍ        m        ‹«  šÎ                          •æ      ‘        ’Ä  íšÐ                –n    šÑ    šÖ      úž•­        šÕšÏšÒšÔ    ¤    •Ç      š×  ’d    ‰ó  ë        šÙ  šØ  ˆ  šÚšÜšÛ    šÞ  šÓšà        šßšÝ          Žmp  ‘sšáºˆë”„        ’Ù  šãšâšäšåšæ        šç            •Ïšèíƒ      ‰Äšé        —[ŠO  ™Çg‘½šê–é          –²    šì  ‘å  “V‘¾•všíšî‰›    Ž¸šï        ˆÎšð          šñ          ‰‚    Šï“Þ•ò        šõ‘tšôŒ_  í„–zšó  “…š÷  šöú¡  ú¢    šù  šøú£  ‰œ  šú§šü’D  šû  •±        —“z      ›@        D      ›A”@”Ü–Ï          ”D    ›J          ‹W    —d    –­  ›ª  ›B          ›Eíˆ‘Ã    –W      “i          ›F            –…í‰È    ¨              ›G    Žo  Žn        ˆ·ŒÆ  ©ˆÏ        ›K›L  ›I                ‰WŠ­  ›H  –Ã•P                    ˆ¦        ˆ÷      Žp  ˆÐ  ˆ¡          ›Q              ›O            –º  ›R  ›P    ›NP        ›M      •Ø          Œâ          ›V›W          ©      ›S˜K        ”k    ›U                                ¥              ›X      •w      ›Y  ›T                                    –¹                                    ”}              ›Z•Q                                                                ›[›_›\    ‰Å›^            Ž¹  ›]Œ™      ›k          ›d›a                  ’„  ›`    ›b    ›c                                ›e›f                          Šð  ›h›g                  ›i                      ì              ›l  ’Ú      ‰d  ›j      ›m              ›n  ›q    ›o  ›p                    Žq›r    E›síŠŽš‘¶  ›t›uŽyF  –Ð      ‹GŒÇ›vŠw    ›w  ‘·        ›x›¡  ›y  ›z    ›{  ›}          ›~    ›€  ‘î  ‰FŽçˆÀ  ‘vŠ®Ž³  G          “†  @Š¯’ˆ’èˆ¶‹X•ó  ŽÀ    ‹qéŽº—G›              ‹{  É    ŠQ‰ƒª‰Æ  ›‚—e          hí‹  Žâ›ƒŠñ“Ð–§›„  ›…    •x      ›‡  Š¦‹õ›†      í    Š°  Q›‹Ž@  ‰Ç›Š  ›ˆ›Œ›‰”JžËR  ›úª  —¾  ›Ž    ›  ’ž›  ¡  Ž›      ‘ÎŽõ  ••ê  ŽË›‘«›’›“ˆÑ‘¸q  ›”“±¬  ­  ›•    ë      ®      ú«  ›–  ›—  –Þ      ›˜        ‹Ä      A            ›™›šŽÚK“òs”ö”A‹Ç››      ‹›œ  ‹ü  “Í‰®  Žr›› ›Ÿ‹û  ›ž  “W                ‘®  “jŽÆ    ‘w—š            ›¢  ›£“Ô  ŽR        ›¥    ›¦                                    ›§      Šò›¨    ›©                        ‰ª        ú¬  ‘ZŠâ  ›«–¦        ‘Ð  Šx    ›­›¯ŠÝ  ú­›¬›®  ›±            ›°  ›²                                  ›³            “»‹¬            ‰ã›´›¹    ›·  •õ•ô        ú®“‡      ›¶s  ›µ                  ’      ›º    è    ›À    ›Á›»ŠR›¼›Å›Ä›Ã›¿      ›¾    ›Â        í“  •ö                                                í–                ›É›Æ  ›È  —’  ›Çí”                ›½                        “    ›Êú³  µ      ›Ë    ›Ì                      ›Ï  ›Î    ›Í      “ˆ›¸      ›Õ                        ›Ñ        ›Ð                  ›Ò  ›Ó                ›Öú´í™—ä  ›×›Ô                      ›Ø    ŠÞ›Ù    ú¶  ›Û›Ú    ›Ü        ›Ý  ìB    „  ‘ƒ  H¶I‹    ›Þ    ·    ŒÈ›ß–¤”b›à  J      Šª  ’F‹Ð      Žs•z    ”¿        ›áŠó        ›ä        ’Ÿ    ›ã›â›å  ’é              ƒ          Žt  È  ‘Ñ‹A    ’     ›æ›çí        –X    ›ê    ›é›è•  ›ñ        –y  ›ë          ›í–‹  ›ì              ›î  ”¦›ï•¼›ð                          Š±•½”N›ò›ó  KŠ²›ôŒ¶—c—HŠô›ö  ’¡  L¯    ”Ý    °        ˜          ’ê•÷“X    M  •{      ›÷          “xÀ      ŒÉ  ’ë              ˆÁŽN—f                ›ø›ù”p        ›ú—õ˜L        ›ü›û    Šf    œ@      œCœD  œB  •_±œFœEœA        œGœH    œI      œLœJ  œKœM  ‰„’ìœN  Œš‰ô”U  œO“ù  •Ù  œP˜M        œQ•¾œT˜Ÿ˜¯  Ž®“óœU  ‹|’¢ˆøœV•¤O    ’o      ’í  ú·      –íŒ·ŒÊ  œW      œX  œ^  Žã    ú¸’£  ‹­œY      •J  ’e    œZ      íK    œ[  ‹®  œ\  œ]    œ_  “–    œ`œa  œb    œSœR      œcŒ`      •Fí  Ê•V’¤•jœd    ²‰e  œe      œf  –ð    ”Þ    œi‰ªœhœgŒa‘Ò  œmœk  œj—¥Œã      ™œl“k]      “¾œpœo        œn  œqŒä            œr•œz    œs”÷        “¿’¥    íž  “O    œt‹J          S  •K            Šõ”E                œuŽu–Y–Z    ‰žœzú»  ’‰      œw            ‰õ        œ«œy      ”O    œx    œv  š  œ|                            œƒœ‰œ  “{    œ†•|    œ€  œ…—åŽv    ‘Óœ}      ‹}œˆ«‰…œ‚‰öœ‡      ‹¯  œ„                œŠ            œŒœ–œ”    œ‘      œ—ö  œ’    ‹°  P    š      œ™œ‹    í   œœ~  ‰øœ“œ•’p    ¦‰¶œœ˜œ—‹±  ‘§Š†        Œb  œŽ                  œš  œœŸú½      Ž»í¢œ¥’îœ›        œ£  ‰÷  œ¡œ¢    œžœ       Œå—I    Š³    ‰xœ¤  ”Yˆ«              ”ßœ{œªœ®–ã  œ§      “‰œ¬              îœ­“Õ                  ˜f  œ©  úÀ    œ¯  ›  É  ú¿ˆÒœ¨œ¦  ‘y      œœŽS              ‘Äœ»úÂ‘zœ¶  œ³œ´  Žäœ·œº        œµD  œ¸    œ²  –ú–ù      œ¼œ½ˆÓ  í§      œ±        ‹ðˆ¤      Š´úÁœ¹          œÁœÀ      œÅ      úÅ      œÆ    í¨        œÄœÇœ¿œÃ    œÈ  œÉ    œ¾Žœ  œÂ‘ÔQœ°T        œÖ  •ç    œÌœÍœÎ    œÕ  œÔ    –Šµ  œÒ  ŒdŠS    œÏ    —¶œÑˆÔœÓ  œÊœÐœ×ŒcœË            —|      —J        œÚ    œÞ      ‘ž  —÷œß    œÜ  œÙ  íªœØœÝ                  •®    “²  Œe  œàœÛ  œá      Œ›      ‰¯      œé      Š¶        œç    œè§œæœäœãœêœâœì    ‰ù                                    œî    œí                      ’¦  œñ  œïœåŒœ  œð  œôœóœõœòœö              œ÷œø•è  œúœù^  ¬‰ä‰úúÇœû  ˆ½      Êœü  æÁ@Œ  A        í      B      C‹YD  EF‘Õ      ŒË    –ß      –[ŠG          îç»”à  Žè  ËH        ‘Å  •¥    ‘ï    K    I  L    J        M          •¯    ˆµ        •}    ”á    N  Q³‹Z  OV´        P”c            —}RSW“ŠTRÜ    e”²  ‘ð              í¬        ”â«        •ø      ’ï      –•  Z‰Ÿ’Š        c    ’S]d_fb  a”  [‰ûY‹‘‘ñU    XSÙ  µ`”q    ‹’Šg                    Š‡@hm  i  Œ  nŽA‰            E\  Žk        ŽwlˆÂ    g        ’§              ‹“          ‹²              jˆ¥    Á      U                    ’ð    ”Òp‘}                  ‘¨    ŽJq  so        •ß  ’»        ‘{                    •ùŽÌ€  ~    ˜      Œž      x·    “æ”P        v    ‘|        Žö{    ¶  uz    ”r      t  Œ@    Š|      |—©Ì’Ty  Ú  T„‰†‘[w‹d          Œf  ’Í}          ‘~      ƒ    ‘µ‰  „    †          •`’ñ  ‡      —K      —gŠ·          ˆ¬  …          ‚        Šö          ‰‡í­ˆ      —h                      Œ            ‘¹  “          Š‘        r                  Ž  ’      ”À“‹            ‹        Œg      ï      Û                      —                  “E              í®            ”  –€          •            –  –Ì                   Œ‚                          ŽTš  ™        ”Q    í¯“³          “P›      œ  •  ”dŽB  ï  –o            Šh  £ž        —i¥    ¡  ¢          ‘€úÌ         ^      ¤  Ÿ          ©ª“F¬    ŽC§        ‹[    ­  ¦±  °  ¯      ²    ´ï  ³        ·                                    µ      ¶          ¹¸          ˜º®    Žx        »¼¾½¿‰ü  U    •ú­          ŒÌ    Á        Äí±•q  ‹~      ÃÂ”sÅ‹³      ÇÆ      Š¸ŽU    “Ö          Œh      ”  È  ®“G  •~É                  ÊË      •¶›|Ä    •k  Ö  ”ã”Á          “l  —¿  ÍŽÎ    Î  ˆ´    ‹ÒË  •€      ÏŽa’f  ŽzV            Ð  •û    ‰—Ž{      Ó  ÑÔ—·Ò        ùÕ    ‘°    Ö        Šø  Ø  ×        ÙÚŠù    “ú’U‹ŒŽ|‘    {ˆ®      Û                ‰ ß        úÎ  VÞ    ©¸  íµÝ  ¹  –¾¨      ˆÕÌúÏ            ä  úÓ¯‰f      í¸t  –†ð        ºúÒ¥  úc    ãáâ        úÐ’‹    žE  èŽžWæ        ç  W      å    ŽN        íº  í»      êéî    ï  ëí¹ŠAìí”Ó        •Œið    í½°  »      ’q            ‹Å  ñõ    ‰Éòô        ó    ‹        ’gˆÃöí¾      ÷    í¿  ’¨      —ï        Žb    •é      úÜ  –\      žAù    ü  ûíÁ  ø    ž@    “Ü  ú                        žB    ŒžC  —j”˜    žD          žF    žG            žH  ‹È‰gXžI  žJ‘‘‚íÂíJ™Ö‘]‘\‘ÖÅ    ˜ð        ŒŽ—L  •ü  •žíÃžK        ñ’½žL˜N      –]  ’©žMŠú            žNžO–Ø  –¢–––{ŽDžQ    Žé    –p  žSžVžU  Š÷    ‹€  žR  žT        žW    ™        —›ˆÇÞ‘º  ŽÛ    ñ    žZ    “m  žX‘©žYð–Ûž[ž\—ˆúá      ža    Y  ”tž^“ŒÜà  ‹n  ”f        ž`  ¼”Â          žf  ”ø  ž]  žcžb      Í        –  —Ñ    –‡  ‰ÊŽ}    ˜gže•      žd    ž_          ŒÍ      žkži  ‰Ëžgžmžs  úâ        íÈ‘Æ    •¿  žu      •A      žt”–^Š¹  õ_      ’Ñ  —M    žpžo      žq  žn    žv  žl    žj  žržh  ’Œ  –öŽÄò          ¸    –Š`  íÉ’Ì“È‰h                            ð    ²ŒI            žx    ZŠœ            žzŠ”ž            ž}  ñ      Šjª    ŠiÍ    ž{Œ…Œj“úæ  žy  ˆÄ        ž|ž~  ‹ËŒKúãŠº‹j        ž‚    ÷–‘  ŽV      žƒ      •O                        ž  ‰±ž„            ž•ž…  —À  žŒ  ”~              ž”  ž‡      ˆ²ž‰    [      ž‹  žŠ  ž†ž‘  ½      šëŒæ—œ        žˆ  ’òŠB«  ž€  žŠ    žŽž’  “Ž              Šü  ž°  úd–Çž—Šû  žž  íË    –_  žŸž¡  ž¥ž™  ’I        “ž©žœ  ž¦      ž             Xžª    ±            ž¨Š»          ˜ož–    ž¤ˆÖ    ž˜    –¸žA’Åž“    ž£            šž­Š‘ŒŸ        ž¯žšž®  ž§ž›  ž«  ž¬          ž½      “Ì  ž¢    ž¹      ž»  ’Ö                    —k                •–ž¶‘È      ž¼‘^  ž³žÀž¿  “íž¾“è          íÍ  žÂžµ  ‹Æž¸|      ”€žº‹É  ž²ž´ž±    ˜OŠyž·    žÁŠT              å      ‰|    žÒ    ˜PžÕ    úë    YžÔ      žÓ            žÐ            žÄ    žážÃ  žÖ            žÎ    žÉžÆ  žÇ  žÏ      ê     žÌ\’Æ‘„žÊ  žÅ    žÈ        —l–Š      žÍž×      úì        žßžØ    žå  žã        žÞ            žÝ  ’Î  ‘…  žÛ    žÙ    žà        žæ”óžì          žçžêžä    ’”  •W  žÚ    žâ¾  –Ížöžé          Œ ‰¡Š~    žÑ  úí        ¿žî  žõŽ÷Š’    ’M            žë  úïžðžô    ‹´                        ‹kžò          ‹@  “Éžñ      žó        íÒ            žíúð        žï          úñŠ€’h      žú                žøŒç  ž÷            Ÿ@        žw      žù  žûžü            ŸK  ŸG  ž        ŸF        ŸE    ŸB          žèŸDŸC                          ŸI  ˜E            ŸL‹ù    ŸHŸJ    íÖ  í×      ”¥  ŸM                              ŸQŸN                —“ŸO        žÜ              ŸR      ŸS            ‰T  ŸUŒ‡ŽŸ  ‹Ó      ‰¢                    —~        ŸWŸVŸY‹\    ‹ÔŠ¼        Ÿ\      Ÿ[  Ÿ]    ‰Ì  ’V  Ÿ^    Š½Ÿ`        Ÿ_  Ÿa      Ÿb  ŸcŽ~³Ÿ  •    •à˜c        Ž•      Î—ð      ŸdŸe  Ž€      ŸfŸg    ŸiŸh  –w    }ŽêŽc  Ÿj              ŸlB  Ÿk          Ÿm          Ÿn          ŸoŸp      Ÿq  ŸsŸrŸt‰£’i  Ÿu    ŽEŠkŸv    “ašÊ        ‹BŸw        Ÿx  •ê–ˆ      “ÅŸy”ä  íØ  ”ù    –Ñ      Ÿz                      Ÿ|Ÿ{    Ÿ~      Ÿ}                                        Ÿ            Ž  –¯  Ÿ‚Ÿƒ    ‹C      Ÿ„              Ÿ†Ÿ…                              …    •X‰i          ”Ãúõ’ó`‹                      ”Ä  Ž¬        Ÿˆ  Š¾    ‰˜  úö“ðŸ‡]’r  Ÿ‰          Ÿ‘  ŸŠ        úø‘¿  ‹‚Ÿ’            Œˆ    ‹DŸ    ŸŽŸ‹—€    íÛ  ’¾      “×ŸŒ    Ÿ”  Ÿ“ŒB    ‰«    ¹ŸŸ          –v‘ò                –—    Ÿœ    Ÿ  ‰Í        •¦–ûŸŸŽ¡ÀŸ˜Ÿž‰ˆ  ‹µ    Ÿ•Ÿš      ò”‘  ”å            Ÿ—  –@  Ÿ™  Ÿ¢úùŸ   Ÿ›      –A”g‹ƒ  “D    ’  Ÿ£        Ÿ¡‘×Ÿ–  ‰j                                íÞ            —mŸ®          Ÿ­        ô  Ÿª  —Œ    “´Ÿ¤          ’Ã      ‰k^Ÿ§            FŸ¬  Ÿ«Ÿ¦  Ÿ©    Šˆ  Ÿ¨”h    —¬    òó                                      Ÿ´Ÿ²  •l            Ÿ¯Ÿ±  ‰Y    _˜Q  Š\  •‚íà        —    ŠCZŸ³                      Ÿ¸  úûÁ      —O  Ÿµ        Ÿ°  Ÿ¶íá    —Ü  “““À                              ûA    ŠU    ‰t    Ÿ¼    Ÿ¿      —Á      —„        ŸÆŸÀŸ½      —ÒŸÃ    ûB  iŸÅ    ŸÊ    “‘ŸÈ        ŸÂ    ’W    ŸÉ  Ÿ¾  ŸÄ  ŸËˆúŸÁ  ŸÌ    [íå~  •£  ¬íäŸ¹ŸÇ“YûE                ´  Š‰ÏÂŸ»a              Œk  Ÿº      ŸÐŒ¸  Ÿß  ŸÙ‹”“n  ŸÔŸÝˆ­‰QûH  ‰·  ŸÖ‘ªŸÍŸÏ`                ŸàûFŸÛ  íê  ŸÓ        ŸÚ            –©    ŸØŸÜ              ŒÎ  Ã    ’XûG    ŸÒ              —N      ŸÕ    ŸÎ“’    ŸÑ      Ÿ×              ˜pŽ¼–ž  Ÿá                  ”¬    ŸíŒ¹          €  Ÿã      —­a  Ÿð    ˆì    Ÿî        Ÿâ        Ÿè    Ÿê      —nŸå    “M    Ÿç  íë    Ÿï  Ÿé–Å      Ÿä  Ž Ÿü        ŠŠ  ŸæŸëŸì              ‘ê‘Ø                          Ÿô    Ÿú    Ÿø  “H    àBŸõ          ŸöŸÞ  ‹™•Y      Ž½    —          ˜R  Ÿò  àA‰‰‘†                    ”™  Š¿—ø              –Ÿ’Ð        ŸùŸû          ‘Q          à@Ÿ÷  Ÿñ      ŠÁ                            Œ‰      àN    àIö    Šƒ          àR            àK’ªàH’×      àk      àE  àD  àM      àGàFàL  Ÿ  àC  ûK          àO    àP          ŠÀ                  àU  àTàV          àY            “b  àS  ûL      àW            Œƒ‘÷àQ”Z    àX                          à]à[    à^    àa      àZŠ”G    Ÿ·            —”à\  à`‘ó  à_  àJ  ûMè‰      àd      àh    àf      íï  íð  àb  àc      àg  àe      •m    àm  àjài  àl“Òàn            ’•‘ëûP      £      ào  àq                      àp                          Ÿó        àr            “å                    às              ‰Î      “”ŠD              ‹„      ŽÜÐ              íò      ˜F†      ‰Š      àu            àt                                  íóàx’Yà{àv      àz        ày“_ˆ×úb                        —ó    à}      ‰G                  à€      à~  à|                                  àw              –B      à‚            ûT        à          íô        ‰‹        à„•°  àƒ        –³        Å                              ‘R          Ä                  í÷íø  —ù    àŠ  ÷            à†à‹    ‰Œ    ûU          à‰  ”à…àˆÆ  ”Ï    àŒ  ŽÏ                            ø            à      à‡  ŒF        à        —oà      ê¤          n                à‘      à’        ”M              à”        à•    ûY  ”R        “•à—        à™  —Ó  à–  à˜‰  à“              šzàš        ‘‡ŽWàœ        à›C™×            à      àŸ  àŽàž  ûZà             ”š            à¡    à¢                    à£                        à¤  ’Ü  à¦à¥    à§  à¨    ŽÝ•ƒ      –êà©àª‘uŽ¢à«à¬          à­•Ð”Å    à®”v          ’«          à¯‰å  ‹  –Ä  –´  ‰²˜S        –q  •¨                µ  à°        “Á      Œ¡à±  Òà³à²        à´                    àµ      à¶                  ‹]  à·        à¸        Œ¢    ”Æ  û[àº      ó    à¹        î@      ‹¶à»à½  à¼              à¾  ŒÏ  à¿        ‹ç  ‘_          àÁàÂàÀ            Žë    “Æ‹·                  àÄ’KàÃ    ˜T”‚                        àÇ                      àÉàÆ      –ÒàÈàÊ  —Â        û]àÎ      àÍ’–”L    Œ£àÌ        àË  —P—Q            àÏ‰Ž        –Ž‚                àÐàÑ              àÓ                      b        àÕ  àÔ          àÖ  Šl    àØ  û_à×  àÚàÙ                Œº    —¦  ‹Ê  ‰¤                    ‹è                                    Šß                —æàÜ              àÞ  îD    àß  ‰Ï          àÛîEŽX    ’¿àÝ      ûd      ûb              àâ  Žì    îG  àà        Œ]    ”Çàá    àü      îJ    àç          Œ»        ‹…  àä—îI  —®                                                ‘ô    àæîK    ûiûh      îN      àè—Ô‹Õ”ú”i      àé        àë  àî                                      àê      àíŒè‰làï  àì—Ú  îOàòê¢        àðàó        àåàñ    º    àô              àõ        —ž          ûl  àö                                    à÷îQ    àã        àø                ŠÂ                        Ž£                        àù        àú        àû              ‰Z      á@  •ZáA    Š¢áB  áC        áD  áFáGáE      •ráIáH                îR  áKáJáL            áMáOáN    ™  áQ  áP    ŠÃ  r  “[  áR¶      ŽY  ‰™áS  —p    •ááT    íŒ“c—Rb\      ’j™²  ’¬‰æáU              áV  á[    áYáXÀŠEáW  ˆØ  ”¨    ”È        —¯á\áZ’{¤    ”©  •L  á^—ªŒlá_  á]”Ôá`  áa  ûoˆÙ    ôáf  ác“ëáb            ‹E    ái      ádáe  áhág•D    ‘a‘`  ‹^    áj          ák    ál          án  ám          ‰u          áv”æáp  ár    át]    áuásŽ¾      áoáq  •a  Ç    áx    áw        áy  Ž¤­    “—áz  ’É    á|      —Ÿá{          ‘‰            á‚  á„á…’s          áƒ  á€  á}á~  á              áˆ  á†  á‡                                  á‰á‹áŒá  áŽ    áŠ                á      á            á‘            —Ã      á”á’á“      Šà          –ü      •È  á–      á•        á—á˜        áœá™ášá›  á      áž  áŸ      á   á¡  ”­“oá¢”’•S  á£  îTá¤“I  ŠFcá¥    á¦    á§  ŽH    á©    á¨    áªá«îWûq  ûr              ût              ”ç  á¬      á­    ê‰á®á¯á°        ŽM    á±”u    –~  ‰m  ‰v    á²        á´      á³“      ·ŸX  áµ–¿  á¶  ŠÄ”Õá·  á¸    á¹      –Ú      –Ó  ’¼      ‘Š    á»    ‚    È    á¾    á½á¼”û  ŠÅŒ§                            áÄ    áÁ^–°      áÀáÂáÃ    á¿                          áÅáÆ  ’­  Šá      ’…          îZáÇ                                    áÈáË          ‡  “Â  áÌ–r  áÉ    áÊ                          áÏ        áÎáÍ                      áÑ    áÐ    áÒ                        áÔ  áÓ        •Ë            u—Ä    áÕ    “µ    áÖ    á×  áÛáÙáÚ  áØ              áÜ          áÝ                  áÞ    áß–µáà          –îáá  ’m  ”Š  ‹é      ’Záâ‹¸      Î                áã          »                  áä          áå  Œ¤Ó                    áçî\      “uÔ‹m                    –C  ”j          “v        {          áé                ûy                            É            ûz            —°d    Œ¥    ”¡  áë          û{  áí        Œé        áì’ô        áïŠVáê    ”è  ‰O  ê  ˜q    áî                áð      •É  ×áò        áó          áñ        Šm  áù  áø    Ž¥      áúáõ      áûáö        ”Öáô    á÷          âA                        â@–      áü    ˆé        âC                âB      Ê          âD            ‘b    âFâE            âG                        áæ      áèâIâH      û|                  Ž¦  —ç  ŽÐ  âJŒV          ‹_‹FŽƒ            —S    âP  âO‘câL    âN    j_âMâK  ”I    Ë    •[        Õ                  “˜    âQ        âRâh‹Ö    ˜\‘T        âS    ‰Ð’õ•Ÿ        û            ûƒ  âT                ‹šâU    âW      âX  ”H    âY          âZâ[    ‹×‰Ñ“ÃGŽ„              â\  H          ‰È•b    â]    ”é            ‘d  â`  âa”‰  `â^  ’    â_      Ì                    ˆÚ        ‹H              âb    ’ö  âcÅ          –«    •Bâdâe’t  —Å    âgâf                          Ží    âiˆî        âl      âj‰ÒŒmâke’  •äâm    –s    âo      Ï‰n‰¸ˆª            ân                  âpâqõ          âr  Šn        ât      ŒŠ  ‹†    âu‹ó    âv  ú  “Ë  Þó      âw                  ’‚‘‹  âyâ{âxâz            ŒA                  â|ŒE      ‹‡—qâ~          â€      ‰M        âƒ      Š–â‚â  â…â}  â†—§  â‡  âˆ  û„šòâŠ  â‰      â‹âŒ  —³â  èíÍâŽâv  “¶âîh    ’Gû‡  â‘  ’[â’          ‹£  ™^’|Ž±        ŠÆ    â“  â   â–  ‹ˆ  â•â¢      â”  Î            â˜â™  “J    âš  Š}        y•„  âœ      ‘æ            â—  â›â    ù                      â¤•M  ”¤“™  ‹Øâ£â¡  ”³âž’}“›  “š  ô            â¶              â¦  â¨        â«  â¬  â©âª    â§â¥        âŸ                      •Í‰Ó      â³  â°  âµ    â´  ”“–¥  ŽZâ®â·â²  â±â­ûˆâ¯  ŠÇ                ’\    û      ”     â¼      ”¢              ßâ¹    ”Í  â½•Ñ  ’z  â¸âº    â»                          â¾    ŽÂ      “ÄâÃâÂ    â¿      ˜U          âÈ    âÌâÉ                âÅ            âÆ          âË      âÀ™ÓâÇâÁ    âÊ              âÐ  ŠÈ  âÍ      âÎ    âÏâÒ                      âÑ”ô        âÓ—ú•ëâØ    âÕ                âÔÐ  â×âÙ      âÖ  âÝ  âÚ            âÛâÄ      âÜâÞ            âß            •Ä  âà                –à    ‹ÌŒHâá          •²  ˆ  –®    ââ  —±    ””  ‘e”S    l      ˆ¾  âçâå  âãŠŸ  Ïâè    âæ  âäâì    âëâêâé          âí      âî¸  âï  âñ    âð        ŒÐ      ‘W      âó      “œ  âò      âô  •³‘Œf  âõ        —Æ              â÷    âø  âù  âú  Ž…  âûŒn    ‹Š  ‹I  ã@  –ñgâü      ãC–ä  ”[    •R      ƒãB  ŽÑhŽ†‹‰•´ãA      ‘f–aõ                Ž‡’Û  ãF—Ý×  ãGa  ãI      Ð®        ãH    IŒ¼‘gãDãJ  îm    ãEŒo  ãMãQŒ‹          ãL        ãUîn  i    —ˆºãR    ‹‹  ãO          ãP    “ãNãK  ŠGâ    Œ¦      ãW                      ãT          ãV      ãS          Œp‘±ãX‘Ž    ãeû  ãaã[              ã_ŽøˆÛãZãbãfj–Ô  ’Ôã\  îoãd  ãY’]  ã^ˆ»–È              ã]    ‹Ù”ê      ‘  —Î    ãŽîq  ãg  ü  ãcãhãj  ’÷ãm    ãi      •ÒŠÉ    –É    ˆÜ    ãl  —û            ãk          ‰    “êãn      ãuãoãv            ãr                ”›    ŽÈãt  ãqãwãp    c        –D    k    ãsã€    ã{  ã~  ã|ããz  ã`Ñ    ”É  ã}    ãx      ‘@Œq  J        û  D‘Uã„    ã†ã‡    ãƒã…              ãyã‚  ãŠã‰    –š    ŒJ                ãˆ  ãŒã‹ã  ã‘    Ž[ã        ã’ã“ú\  ã”  ãš“Zã–  ã•ã—ã˜  ã™        ã›ãœ                                                                                                                                                                                                                                                                                                                  ŠÊ  ã  ãž                    ãŸ  û        ã ã¡ã¢  ã£ã¤    ã¦ã¥    ã§            ã¨ã©            ã¬ãªã«ßŒr    ’u  ”±      ”l  ”ëã­œë                ã®ã°  —…ã¯ã²ã±  —r  ã³  ”ü          ã´          ã·    ã¶ãµ    û‘  ã¸ŒQ      ‘A‹`        ã¼ã¹    ãº      ã½  ã¾ã»      ‰H      ‰¥      ãÀãÁ      ãÂ  —‚          K  ãÄãÃ                    ‰ãÅ        ãÆ    ãÇ  Šã        ŠË    ãÈ          ãÉ  –|—ƒ      —s˜V  lãÌŽÒãË        ãÍŽ§      ‘Ï  ãÎ    k  –ÕãÏãÐ    ãÑ        ãÒ            ãÓ                    Ž¨    –ë        ãÕ  ’^  ãÔ            ã×      ãÖ              ãØ      ¹  ãÙ  ãÚ      •·ãÛ  ‘ãÜ          ãÝ            —üãà  ãßãÞ’®  ãáE  ãâ      ãã˜Wãä        ãåãçãæ”£  “÷  ˜]”§            ãé    Ñ  •I  ãêãè  ŠÌ      ŒÒŽˆ    ”ì      Œ¨–b  ãíãë  m  nˆç  æ          ”x                ˆÝãò  ’_          ”w  ‘Ù              ãô    ãðãóãî  ãñ–E    ŒÓ    ˆûãï                  ãö  ã÷    “·      ‹¹      äE”\        Ž‰    ‹ºÆ˜e–¬ãõÒ                              ‹rãø              ãú          ãù          ãû  ’E  ”]          ’¯        äB              äA        ãü    t  •…äD  äCo˜r                  äT          äHäI        Žî    äG  ˜äF    äJ      ’°• ‘B        ‘ÚäN  äOäK        äL  äM        p      äU  äQ        •†  –Œ•G    äP    äSäR      –cäV            äW    ‘V  äX    äZ  ä^    ä[äY”^ä\  ä]      ‰°  ädä_      ä`      äa  ‘Ÿ        äcäbäe        äfäg    b  ‰ç  äh—Õ  Ž©    L          ŽŠ’v          äiäj‰P  äk    äläm    än  äo‹»¨äp  ãäqŽÉ  är  ˜®      äs•ÜŠÚ    ‘Cw  •‘M                  ätqäu”Ê  ä„        äw  ‘Ç”•Œ½äv‘D            äx            ’ø                                äzäyä|    ä{  ä}    ä€  ä~  ŠÍ  ä  ä‚äƒ    ¯—Ç  ä…F      ‰ä†ä‡          äˆ                        ˆð  ä‰        äŠ            •‡      ŽÅ  äŒ          ŠHˆ°        ä‹äŽ”m  c  ‰Ô  –F        Œ|‹Ú  ä  ‰è              Š¡                      ‰‘ä’—è‘Û    •c  äž  ‰Õäœ  äšä‘  ä  ä  Žá‹ê’—      “Ï          ‰p  ä”ä“        ä™ä•ä˜          û“–Îä—‰ÖŠä›    ä        Œs              ä¡äªä«      ˆ©            ä²        ˆï    ä©      ä¨  ä£ä¢  ä äŸ’ƒ  ‘ùä¥            ä¤        ä§      ‘Œt        ‰`ä¦  r          ‘‘                  û”                                ä¸  ä¹  ‰×      ‰¬ä¶    û•          ä¬  ä´  ä»äµ      ä³        ä–    ä±      ä­      ŠÎä¯äº  ä°          ä¼  ä®”œ          —‰      ä·              äÍ      äÅ      ›  îy    ‹e  ‹Û  äÀ        ‰Ù    Ò  äÃ      Ø    “päÈ                •ì  ä¿      ‰ØŒÔ•HäÉ  ä½  îzäÆ      äÐ  äÁ          äÂ“¸    äÇ      äÄ–GäÊˆÞ        ä¾                        äÌ  äË            ”‹äÒ  äÝ        Šž      äà    äÎ      äÓ—Ž                äÜ  î{—t        —¨                ’˜      Š‹          •’äâ“Ÿ    ˆ¯    äÛ  ä×‘’äÑäÙäÞ  ”K      ˆ¨  äÖ  äß•˜              äÚ  äÕ            Ó        N      Žª        –Ö    •f    äå  äî                      äØ        Š—  û™      öäã  äè‘“    ää  äë    ’~  äì    —uäáŠW  äç    äê–ª        äí    äæäé  ú`                              –H  ˜@          äñ              äø    äðŽÁ          äÏ                    •Ì  – ä÷äö  äòäó  ‰U        äõ  äï        ’Ó          äôˆü              ‘               •Á    äùå@  ”×        äüÔŽÇåB    ‹¼        ûš  åC  •™äûû›äÔ                äú        ˜n“ •“ûœ  åJ                  åP            åQ  åD      ”–    åNåF  åH          åRåG    åK    ‰’  “ã  åLåO              åE  ‘E  åIŽFdŒO–ò  –÷’ûž                åVåT            ˜m              åS      —•  åUåW        åX            å[åY            “¡åZ      ”ËåM                        “  å\åa‘”    å`      åA      åb‘h    å]å_              å^    ŸPŸA    åd              åc                    —–  áºåe                            åf                          ågŒÕ  ‹s      åi™|        ‹•  —¸  ‹ñåj              åk      ’Ž          ål              “ø  ˆ¸                            ‰áåqår            åm  Ž\                          ån”a        åoåpåz      åtåw          ås                          åu  åvŽÖ  åx  ’`  ŒuŠa          å{        Š^  å    å|å€        ”¸        å}    å~•g”Øå‚                ‘ûåŒ  åˆ    ‰é  å†  –Iå‡    å„  å…åŠå    å‹      å‰åƒ          ’w  å”  –¨                å’      å“                    åŽ    å      å‘      å                  ä  ˜Xå˜  å™        åŸ  I  å›  åž          å–å•    å     ‰Ú  åœ  å¡      å          åš  ’±  å—            ”ˆ    å¥                    —Z                                  å¤    å£                å¬      å¦      å®            —†å±  å¨    å©      å­  å°å¯      å§        åª  å»                          å´                            å²    å³      å¸å¹  ŠI  ‹a    å·            å¢  û¡          å¶åºåµ  å¼      å¾å½                    åÀå¿åy      åÄ                  åÁ        åÂ    åÃ  åÅ        ŒŒ  åÇ  åÆ  O          sŸ¥        åÈp      ŠX  åÉ  ‰q  ÕåÊ    tåËˆß        •\    åÌ        Š  åÓ    åÐ  ’          åÑåÎ‹Ü  åÍåÔ          ŒU    ‘Ü  åÚ        åÖ      ‘³åÕ  åØ        åÏ      åÙ  åÛ            ”í    å×  åÜåÞ    ŒÑåÒ  ˆ¿              åÝ  Ù—ôåßåà‘•                  —         åá—T    åâåã    •âåä  ¾  —¡            åé                  åêÖåèû¢    —‡åå    åç»ž      åæ  åë    •¡    åí  åì      ŠŒ  –Jåî                íAåúåð            åñ        åòåó                    å÷  åø    åö          åô  åïåõ              åùèµ                ‰¦              åü‹Ýåû      æA  æ@      æC    æB  æD    P  æE    æF            æG¼  —v  æH    •¢”eæI  æJŒ©      ‹K      æK    Ž‹”`æL  Šo            æM        æO——  æNe  æP    æQ    æRŠÏ            æS    æT  æUæV                                  Šp              æW  æXæY          ‰ð    GæZ                        æ[      æ\              Œ¾  ’ùæ]        Œv  u  æ`  “¢  æ_  û£ŒP    æ^‘õ‹L    æa  æb  ×      Œ  æc        –K    Ý      ‹–  –ó‘i  ædîˆ    f’Ø        æe        æh  æi              ¼‘Àæg  Ù•]          æf    ŽŒ  ‰r  æmŒw    ŽŽ    Ž  ˜lælæk‘F  ‹l˜bŠYÚ          û¥    æj          æo  æpæn  ŒÖ  —_    Ž”F      æs  ¾  ’a    —U  æv      Œê  ½ær  æwŒëætæuîŠæq      à“Ç    ’N  ‰Û            ”î    ‹b  î‹’²    æz  æx    ’k      ¿ŠÐæy  z    —È      ˜_      æ{æ‡’³  æ†û¨æƒæ‹æ„  æ€  ’úæ~      æ|  —@Ž    æ  æ}    îŽæ…”  Œ¿      ‘ø  –d‰yˆà  “£    æ‰        æˆ  “ä  æ      æ‚  æŒæŽ  ŒªæŠu  ŽÓ    æ—w        æ’  æ•    æ“•T            æ          ‹Þ        æ”    æ–              æš    æ—  æ™æ˜      û«    æ›  Ž¯  ææœ•ˆ    æŸ            Œx        æžæ     æ¡‹cã¿÷  æ¢    Œì          æ£  îæ¤    Ž]            Ì  æ¥  æ¦  Q  æ§æ¨    æ©    æªæ«                                                                                                                                                                                                                                                                                                                        ’J    æ¬        æ®  æ­        “¤  æ¯  –L  æ°  æ±  æ²        æ³        “Ø            Ûæ´              ‹˜¬æµ                      æ¶•^æ·  æ¿          æ¸    æº      æ¹æ»  –eæ¼æ½          æ¾      æÀ        ŠL’å  •‰àv        •n‰Ý”ÌæÃŠÑÓæÂæÇ’™–á  æÅæÆ‹M  æÈ”ƒ‘Ý    ”ï“\æÄ  –f‰êæÊ˜G’À˜d    Ž‘æÉ  ‘¯    æÚ‘G    “ö  •o            æÍŽ^Ž’  Ü  ”…  Œ«æÌæË  •Š      Ž¿    “q    î‘      û®          æÏæÐwæÎ            æÑæÒ  æÔ‘¡  æÓŠä  æÖ  æÕæ×  î“æÙæÛ  æÜ                                                                                                                                                          Ô  ŽÍæÝ      Šq  æÞ    ‘–æß  æà•‹  î”‹N                  æá      ’´        ‰z                            æâ                  Žï        –                    ‘«            æå      æä      æã                æëæé    ææ            æè      æçæê  ‹—  æî  Õ  æï        Œ×  æìæí      ˜H      ’µ  ‘H            æð    æó                æñæò—x        “¥æö                        æôæõæ÷                    çH          æú      æûæù                        æø  ’û    ç@çDçAæü  çB      çC        çJ      çE          ÖçG    çIçF                          çL  R  çK          çM        çN    çQçP  çO    çSçR  –ô      çU  çTçV        çW              çY                çXgçZ    ‹ëç[ç]                        ç^            ç_ç\  ç`  ŽÔça‹OŒR  û²    Œ¬                çb      “î    “]çc              çf                        Ž²    çeçdŒyçg        Šr  çi      Úçh  çq          çkçm•ãçj      çl  çpçn‹P  ço            çr    ”y—Ö        S      çs        —Açu  çt    çx—`    çw  Šçvç{    çz    çy“Qç|                ç}        ç~    Œ  ŒDç€çç‚                                                                                                            hçƒ  Ž«ç„      ç…      ™Ÿ™ž        ç†ãç‡’CJ”_        çˆ    •Ó’Òž    ’H    ‰I  –˜v                Œ}    ‹ß    •Ô          ç‰              ç‹    çŠ‰Þ    “ôçŒ”—  “R  çq      ç    –Àçžç‘ç’    ’Ç    ‘Þ‘—  “¦  ç‹t        ç™  ç–ç£“§’€ç“  ’ü“rç”ç˜€  ”‡’Ê    Àç—‘¬‘¢ç•ˆ§˜A      çš            ‘ß    Ti    çœç›  ˆíç    •N  ç¥    “Ù‹    ’x  ‹ö  ç¤—V‰^  •Õ‰ßçŸç ç¡ç¢“¹’Bˆáç¦  ç§ê¡    ‘»  ç¨  ‰“‘k  Œ­  —y  î™ç©“K      ‘˜ŽÕçª    ç­    …ç«‘J‘I  ˆâ  —Éç¯  ”ðç±ç°ç®â„ŠÒ    çŽ  ç³ç²        ç´  —W                                  “ß    –M  çµ  Ž×        ç¶  ç·      ç¸    “@                ˆè                x      ˜Y                        ç¼    îš    ŒSç¹  çº      •”        Šs              —X  ‹½          “s        ç½                              ç¾    û¸      ç¿                          î          “A    çÁ  çÀ                                            “ÑçÂUŽÞ”z’‘      Žð  Œ  çÃ  çÄ                  |çÅ  çÆ      çÇ—  V          çÉçÈ  y  “Ž_                  çÌ        †  çË  çÊ  ‘ç    Œí  Á        ”®        X          çÍ  Ý          çÐçÎ      çÏ        çÒçÑ    ø  çÓ          çÔçÕ        ”ÎÑŽßçÖ  ç×—¢d–ì—ÊçØ‹à        çÙîŸ“B  îžçÜŠ˜jî çÚ  çÛ  ’Þû¿ûÀ–t‹ú          î¡û¾            çÞçß          çÝ    çá            ûÁ      ûÃ    “ÝŠb  ûÂçå    çâçä                çà                    èn    çã              —é    ŒØ  ûÊûÄ  îª    çíî©      “Sçè    çëçé  çî    î«  çïî­          çç  î¬çô‰”    çæ      ”«  çê  ÞûË                  z          ûÍûÎ          –g  ‹â    e  “º    íC                ‘L  çò  çìçñ  –Á  ’¶çóçð                    ûÌ          ‘K                  ç÷  çö                                          çõî¶  –Nîº  ûÔ  ûÐ  ûÑ            î¹      ›    ûÏ  çø•Ý    ‰s        •e’’        ‹˜íIçúî½|    îÀ    ûÞ      ŽK                çù              Žè@èB    îÁî¿  ùûØèAèC  û×‹Ñ  •d    Žà˜B  çüö    ˜^    èE        èDèF                çû      íB    “ç  “t            ’Õ  èKûà      ’bèG      èH                      ŒL  èJ  ûß        Œ®            èI  ß                          Š™              èO  ½‘™    ’È                  ûá    ŠZ        èMèN’Á  èL                èP                  èV    ûâ  èY              èX“L        èQèRèU        èWîÇ    ‹¾    èZèT    èS                              îÈ                    è^      è_                è`    è]è\      à“¨è[            èd                  èb          ûå      ècèa  ‘ö  èe            èf    èhûæ    ûç                ŠÓèg–ø            èsèi    èl  èj  èk              èm          èo        èp  èq        ètèrèuèw  èv                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          ’·                –å  èx‘M      èy  •ÂèzŠJ      ‰[  ŠÕûèŠÔè{  è|  è}è~            è€  ŠÖŠt}”´  è‚è        èƒ        ‰{            è†  è…è„  è‡        èŠ      ˆÅ    èˆ  èŒè‹            èŽèè  “¬      è        è‘è“    è’                                                                                                            •Œ        è”            è•  ã      è–è—    –h                ‘j      ˆ¢‘É  è˜  •            è›è™~  èšŒÀ                    •ÃèèŸèžè     ‰@wœŠ×è¡      ”†  è£      ‰A  è¢’Â  —Ë“©èœ—¤  Œ¯    —z              ‹÷—²  ŒG  ‘àä@  è¤ŠK        Šuè¦  è§è¥Œ„  ÛáîÏ    ‰B    —×      è©ç¬  è¨        îÐè¬èªè«  è­  è®—êè¯è°  Ç”¹      Šå    —Y‰ëWŒÙ  è³  è²Ž“è´è±    ŽG      è¸å«    ™Ô  —è¶          —£“ï        ‰J  áŽ´        •µ  ‰_      —ë—‹  è¹  “d        Žù      èº  è»kè¼  —ì    è·è¾èÀ  è¿  è½    èÁ    èÂ    ‘š  ‰à          èÃ    –¶    èÄ          èÅ  ˜Iûí        žPèÆ  îÒ  èÇèÈ      èÌîÓèÉ  èÊ  èËèÍ      ûð  ûñ  îÖÂ    ûó–õ    Ã    èÎ  ”ñ  èÏêr–Ê  èÐ  èÑ  èÒŠv  èÔ  x      èÕ    ŒC        èÖèÚ  èØ        èÙ    Š“è×èÛ        èÜ  ˆÆ  èÝèÞ              â      èß      ‹f    èâ    èá  èà    æ‘  •Ú          èãèä                            èå    èæ  èç    èè              ŠØ                èé                                èê”B      èì‰¹  èïèî        ‰C      ‹¿  •Å’¸   €‡  {      èñ    èð—aŠæ”Ð“Ú      œ—Ì  Œz            èô    èó              –j“ª            ‰o    èõèò    •p—Šèö                è÷        èù‘èŠzŠ{èø        ŠçŒ°  îØŠè    “^    —Þ            ûõ  ŒÚ      èú      èûèüé@  éBéA                                                                                                      •—  éC        éD  éE        éF                        éHéG  éI                                        ”òãÊ    H    ‹Q            éJ  éK  ™ªŸZ”Ñ    ˆù  ˆ¹              Ž”–Oü        éL  –Ý      éM—{  ‰a      Ž`  éN‰ìéO      éP        éRéS  éUéQ    éT    îÜŠÙ      éV  éW                            éXéY      éZ    é\      é[  é^éa      é]é_é`    éb  ‹À                                                                                                                            Žñécéd        ûú            ée    Š]      ”néfég        ’y“é              éh        ”    ‘Ê‰w‹ì  ‹í              ’“ém‹î    ‰í    él    éj  ék  éi    éw                    énéo    épéq          és    ér      x  ét      év                ‹Réu    ‘›Œ±          éx                            ‘Ë    éy        “«            éz            é€  é}  é|é~  é{              é‚ûû            é  é„    ‹Áéƒ      é…    é†  éˆé‡      é‰é‹éŠ                                                                                                                        œ        éŒ    é              Š[      éŽ      é      ‘                    é  é‘  é’é“      ‚ûü    ü@  é”é•    é–é—    é˜      ”¯éš  •Eé›é™  é    éœ    éž      éŸ                    é                                   é¡  é¢        é£    é¤é¥  é¦  é§é¨é©éª      é«é¬  ŸTé­                âö‹S        Š@°é¯é®–£              é±é²é°  é³    –‚      é´  ‹›                                        ˜D    üB  éµüA                          é·                    ˆ¼üC  é¸•©é¶    é¹éº              é»é¼              é½  –ŽŽL  ø‘N    îå    é¾        éÁ  îæ        é¿          éÂ    ŒïéÀ        éÃ  éÄéÅ  éÉ  ŽI        ‘â          éÊéÇéÆéÈ      Œ~              éÎéÍéÌ    ˆ±                    îç      éØ  éÔ  éÕéÑé×  éÓŠ‚    ˜k  éÖéÒéÐéÏ          éÚ          éÝ    éÜéÛ              •héÙˆñéÞ  éà            ŠéË‰V    éâ              éáéß’L                  –        —Ø    éã          éä            éå                            éæ  éç                                                                                                                                                                                                                        ’¹  éè  ”µ  éíéé      éê    –P–Â  “Î                        éî    éï“¼éìéë        ‰¨      é÷    éö          ‰•      éô      éó    éñ  Š›  éðŽ°‰§                            ƒ    éúéù  éø    éõ  éû  éü              êDêC              êE    ‰Lê@êA  ”–·    êB            îé–Q    êJüG  êF              êK                        êH  êG          Œ{                    êL                  êM        êN  êI      éò    êO  ’ß      êS  êTêR          êQêW  êP  êU                êV      êY          êX                        ê[            ê\  ê]    ˜h          êZ‘éë    ê^                                                      îëê_ê`    êa                                                                                                                                                                            êb    Œ²êc      êd  Ž­  êe            êf    êgêh        êkêi˜[  êj  —í          êl  —Ù          êm”ž    ênêp    êq                    êo–Ë–ƒ›õ  Ÿ€–›        ‰©              ês‹oêtêuêvüK•  êw      àÒ–Ù  ‘áêxêzêy  ê{        ê|    ê}            ê~        ê€  êê‚  êƒ  ê„ê…ê†                  ê‡êˆ          “C        ŒÛ  êŠ                    ‘lê‹                    êŒ                            •@    ê                      êŽâV    æØèë    ê  ê                    ê’ê“ê”—îê‘    ê•ê–    ê˜  ê—          êš      ê›ê™                                          —´              êœ            êâs    êž                                                                                                                                                                                                                                                                                úà                                                                                                                                                                                                                                                                                                                                                                    îÍ                                                                                                  ísí~í€ú±úØíÌúêíùîBîYîaîbû€û‚û†û‰û’ûîƒû û©î•û³î˜î›ûÓî¾îÎîÚû÷ûùüI                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      Iîü”“•îûij–{C|D^‚O‚P‚Q‚R‚S‚T‚U‚V‚W‚XFGƒ„H—‚`‚a‚b‚c‚d‚e‚f‚g‚h‚i‚j‚k‚l‚m‚n‚o‚p‚q‚r‚s‚t‚u‚v‚w‚x‚ym_nOQM‚‚‚‚ƒ‚„‚…‚†‚‡‚ˆ‚‰‚Š‚‹‚Œ‚‚Ž‚‚‚‘‚’‚“‚”‚•‚–‚—‚˜‚™‚šobp`    ¡ ¢ £ ¤ ¥ ¦ § ¨ © ª « ¬ ­ ® ¯ ° ± ² ³ ´ µ ¶ · ¸ ¹ º » ¼ ½ ¾ ¿ À Á Â Ã Ä Å Æ Ç È É Ê Ë Ì Í Î Ï Ð Ñ Ò Ó Ô Õ Ö × Ø Ù Ú Û Ü Ý Þ ß                                                                                                                                 ‘’úTPúU                                                    ï½¡ï½¢ï½£ï½¤ï½¥ï½¦ï½§ï½¨ï½©ï½ªï½«ï½¬ï½­ï½®ï½¯ï½°ï½±ï½²ï½³ï½´ï½µï½¶ï½·ï½¸ï½¹ï½ºï½»ï½¼ï½½ï½¾ï½¿ï¾€ï¾ï¾‚ï¾ƒï¾„ï¾…ï¾†ï¾‡ï¾ˆï¾‰ï¾Šï¾‹ï¾Œï¾ï¾Žï¾ï¾ï¾‘ï¾’ï¾“ï¾”ï¾•ï¾–ï¾—ï¾˜ï¾™ï¾šï¾›ï¾œï¾ï¾žï¾Ÿ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ã€€ã€ã€‚ï¼Œï¼Žãƒ»ï¼šï¼›ï¼Ÿï¼ã‚›ã‚œÂ´ ï½€Â¨ ï¼¾ï¿£ï¼¿ãƒ½ãƒ¾ã‚ã‚žã€ƒä»ã€…ã€†ã€‡ãƒ¼â€•â€ï¼ï¼¼ï½žâˆ¥ï½œâ€¦â€¥â€˜â€™â€œâ€ï¼ˆï¼‰ã€”ã€•ï¼»ï¼½ï½›ï½ã€ˆã€‰ã€Šã€‹ã€Œã€ã€Žã€ã€ã€‘ï¼‹ï¼Â± Ã— ?  Ã· ï¼â‰ ï¼œï¼žâ‰¦â‰§âˆžâˆ´â™‚â™€Â° â€²â€³â„ƒï¿¥ï¼„ï¿ ï¿¡ï¼…ï¼ƒï¼†ï¼Šï¼ Â§ â˜†â˜…â—‹â—â—Žâ—‡â—†â–¡â– â–³â–²â–½â–¼â€»ã€’â†’â†â†‘â†“ã€“?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  âˆˆâˆ‹âŠ†âŠ‡âŠ‚âŠƒâˆªâˆ©?  ?  ?  ?  ?  ?  ?  ?  âˆ§âˆ¨ï¿¢â‡’â‡”âˆ€âˆƒ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  âˆ âŠ¥âŒ’âˆ‚âˆ‡â‰¡â‰’â‰ªâ‰«âˆšâˆ½âˆâˆµâˆ«âˆ¬?  ?  ?  ?  ?  ?  ?  â„«â€°â™¯â™­â™ªâ€ â€¡Â¶ ?  ?  ?  ?  â—¯?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ï¼ï¼‘ï¼’ï¼“ï¼”ï¼•ï¼–ï¼—ï¼˜ï¼™?  ?  ?  ?  ?  ?  ?  ï¼¡ï¼¢ï¼£ï¼¤ï¼¥ï¼¦ï¼§ï¼¨ï¼©ï¼ªï¼«ï¼¬ï¼­ï¼®ï¼¯ï¼°ï¼±ï¼²ï¼³ï¼´ï¼µï¼¶ï¼·ï¼¸ï¼¹ï¼º?  ?  ?  ?  ?  ?  ?  ï½ï½‚ï½ƒï½„ï½…ï½†ï½‡ï½ˆï½‰ï½Šï½‹ï½Œï½ï½Žï½ï½ï½‘ï½’ï½“ï½”ï½•ï½–ï½—ï½˜ï½™ï½š?  ?  ?  ?  ãã‚ãƒã„ã…ã†ã‡ãˆã‰ãŠã‹ãŒããŽããã‘ã’ã“ã”ã•ã–ã—ã˜ã™ãšã›ãœããžãŸã ã¡ã¢ã£ã¤ã¥ã¦ã§ã¨ã©ãªã«ã¬ã­ã®ã¯ã°ã±ã²ã³ã´ãµã¶ã·ã¸ã¹ãºã»ã¼ã½ã¾ã¿ã‚€ã‚ã‚‚ã‚ƒã‚„ã‚…ã‚†ã‚‡ã‚ˆã‚‰ã‚Šã‚‹ã‚Œã‚ã‚Žã‚ã‚ã‚‘ã‚’ã‚“?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ã‚¡ã‚¢ã‚£ã‚¤ã‚¥ã‚¦ã‚§ã‚¨ã‚©ã‚ªã‚«ã‚¬ã‚­ã‚®ã‚¯ã‚°ã‚±ã‚²ã‚³ã‚´ã‚µã‚¶ã‚·ã‚¸ã‚¹ã‚ºã‚»ã‚¼ã‚½ã‚¾ã‚¿ãƒ€ãƒãƒ‚ãƒƒãƒ„ãƒ…ãƒ†ãƒ‡ãƒˆãƒ‰ãƒŠãƒ‹ãƒŒãƒãƒŽãƒãƒãƒ‘ãƒ’ãƒ“ãƒ”ãƒ•ãƒ–ãƒ—ãƒ˜ãƒ™ãƒšãƒ›ãƒœãƒãƒžãƒŸ?  ãƒ ãƒ¡ãƒ¢ãƒ£ãƒ¤ãƒ¥ãƒ¦ãƒ§ãƒ¨ãƒ©ãƒªãƒ«ãƒ¬ãƒ­ãƒ®ãƒ¯ãƒ°ãƒ±ãƒ²ãƒ³ãƒ´ãƒµãƒ¶?  ?  ?  ?  ?  ?  ?  ?  Î‘ Î’ Î“ Î” Î• Î– Î— Î˜ Î™ Îš Î› Îœ Î Îž ÎŸ Î  Î¡ Î£ Î¤ Î¥ Î¦ Î§ Î¨ Î© ?  ?  ?  ?  ?  ?  ?  ?  Î± Î² Î³ Î´ Îµ Î¶ Î· Î¸ Î¹ Îº Î» Î¼ Î½ Î¾ Î¿ Ï€ Ï Ïƒ Ï„ Ï… Ï† Ï‡ Ïˆ Ï‰ ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  Ð Ð‘ Ð’ Ð“ Ð” Ð• Ð Ð– Ð— Ð˜ Ð™ Ðš Ð› Ðœ Ð Ðž ÐŸ Ð  Ð¡ Ð¢ Ð£ Ð¤ Ð¥ Ð¦ Ð§ Ð¨ Ð© Ðª Ð« Ð¬ Ð­ Ð® Ð¯ ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  Ð° Ð± Ð² Ð³ Ð´ Ðµ Ñ‘ Ð¶ Ð· Ð¸ Ð¹ Ðº Ð» Ð¼ Ð½ ?  Ð¾ Ð¿ Ñ€ Ñ Ñ‚ Ñƒ Ñ„ Ñ… Ñ† Ñ‡ Ñˆ Ñ‰ ÑŠ Ñ‹ ÑŒ Ñ ÑŽ Ñ ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  â”€â”‚â”Œâ”â”˜â””â”œâ”¬â”¤â”´â”¼â”â”ƒâ”â”“â”›â”—â”£â”³â”«â”»â•‹â” â”¯â”¨â”·â”¿â”â”°â”¥â”¸â•‚?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  â‘ â‘¡â‘¢â‘£â‘¤â‘¥â‘¦â‘§â‘¨â‘©â‘ªâ‘«â‘¬â‘­â‘®â‘¯â‘°â‘±â‘²â‘³â… â…¡â…¢â…£â…¤â…¥â…¦â…§â…¨â…©?  ã‰ãŒ”ãŒ¢ããŒ˜ãŒ§ãŒƒãŒ¶ã‘ã—ãŒãŒ¦ãŒ£ãŒ«ãŠãŒ»ãŽœãŽãŽžãŽŽãŽã„ãŽ¡?  ?  ?  ?  ?  ?  ?  ?  ã»?  ã€ã€Ÿâ„–ãâ„¡ãŠ¤ãŠ¥ãŠ¦ãŠ§ãŠ¨ãˆ±ãˆ²ãˆ¹ã¾ã½ã¼â‰’â‰¡âˆ«âˆ®âˆ‘âˆšâŠ¥âˆ âˆŸâŠ¿âˆµâˆ©âˆª?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  äºœå”–å¨ƒé˜¿å“€æ„›æŒ¨å§¶é€¢è‘µèŒœç©æ‚ªæ¡æ¸¥æ—­è‘¦èŠ¦é¯µæ¢“åœ§æ–¡æ‰±å®›å§è™»é£´çµ¢ç¶¾é®Žæˆ–ç²Ÿè¢·å®‰åºµæŒ‰æš—æ¡ˆé—‡éžæä»¥ä¼Šä½ä¾å‰å›²å¤·å§”å¨å°‰æƒŸæ„æ…°æ˜“æ¤…ç‚ºç•ç•°ç§»ç¶­ç·¯èƒƒèŽè¡£è¬‚é•éºåŒ»äº•äº¥åŸŸè‚²éƒç£¯ä¸€å£±æº¢é€¸ç¨²èŒ¨èŠ‹é°¯å…å°å’½å“¡å› å§»å¼•é£²æ·«èƒ¤è”­?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  é™¢é™°éš éŸ»å‹å³å®‡çƒç¾½è¿‚é›¨å¯éµœçªºä¸‘ç¢“è‡¼æ¸¦å˜˜å”„æ¬è”šé°»å§¥åŽ©æµ¦ç“œé–å™‚äº‘é‹é›²èé¤Œå¡å–¶å¬°å½±æ˜ æ›³æ „æ°¸æ³³æ´©ç‘›ç›ˆç©Žé ´è‹±è¡›è© é‹­æ¶²ç–«ç›Šé§…æ‚¦è¬è¶Šé–²æ¦ŽåŽ­å††?  åœ’å °å¥„å®´å»¶æ€¨æŽ©æ´æ²¿æ¼”ç‚Žç„”ç…™ç‡•çŒ¿ç¸è‰¶è‹‘è–—é é‰›é´›å¡©æ–¼æ±šç”¥å‡¹å¤®å¥¥å¾€å¿œæŠ¼æ—ºæ¨ªæ¬§æ®´çŽ‹ç¿è¥–é´¬é´Žé»„å²¡æ²–è»å„„å±‹æ†¶è‡†æ¡¶ç‰¡ä¹™ä¿ºå¸æ©æ¸©ç©éŸ³ä¸‹åŒ–ä»®ä½•ä¼½ä¾¡ä½³åŠ å¯å˜‰å¤å«å®¶å¯¡ç§‘æš‡æžœæž¶æ­Œæ²³ç«ç‚ç¦ç¦¾ç¨¼ç®‡èŠ±è‹›èŒ„è·è¯è“è¦èª²å˜©è²¨è¿¦éŽéœžèšŠä¿„å³¨æˆ‘ç‰™ç”»è‡¥èŠ½è›¾è³€é›…é¤“é§•ä»‹ä¼šè§£å›žå¡Šå£Šå»»å¿«æ€ªæ‚”æ¢æ‡æˆ’æ‹æ”¹?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  é­æ™¦æ¢°æµ·ç°ç•Œçš†çµµèŠ¥èŸ¹é–‹éšŽè²å‡±åŠ¾å¤–å’³å®³å´–æ…¨æ¦‚æ¶¯ç¢è“‹è¡—è©²éŽ§éª¸æµ¬é¦¨è›™åž£æŸ¿è›ŽéˆŽåŠƒåš‡å„å»“æ‹¡æ’¹æ ¼æ ¸æ®»ç²ç¢ºç©«è¦šè§’èµ«è¼ƒéƒ­é–£éš”é©å­¦å²³æ¥½é¡é¡ŽæŽ›ç¬ æ¨«?  æ©¿æ¢¶é°æ½Ÿå‰²å–æ°æ‹¬æ´»æ¸‡æ»‘è‘›è¤è½„ä¸”é°¹å¶æ¤›æ¨ºéž„æ ªå…œç«ƒè’²é‡œéŽŒå™›é´¨æ ¢èŒ…è±ç²¥åˆˆè‹…ç“¦ä¹¾ä¾ƒå† å¯’åˆŠå‹˜å‹§å·»å–šå ªå§¦å®Œå®˜å¯›å¹²å¹¹æ‚£æ„Ÿæ…£æ†¾æ›æ•¢æŸ‘æ¡“æ£ºæ¬¾æ­“æ±—æ¼¢æ¾—æ½…ç’°ç”˜ç›£çœ‹ç«¿ç®¡ç°¡ç·©ç¼¶ç¿°è‚è‰¦èŽžè¦³è«Œè²«é‚„é‘‘é–“é–‘é–¢é™¥éŸ“é¤¨èˆ˜ä¸¸å«å²¸å·ŒçŽ©ç™Œçœ¼å²©ç¿«è´‹é›é ‘é¡”é¡˜ä¼ä¼Žå±å–œå™¨åŸºå¥‡å¬‰å¯„å²å¸Œå¹¾å¿Œæ®æœºæ——æ—¢æœŸæ£‹æ£„?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  æ©Ÿå¸°æ¯…æ°—æ±½ç•¿ç¥ˆå­£ç¨€ç´€å¾½è¦è¨˜è²´èµ·è»Œè¼é£¢é¨Žé¬¼äº€å½å„€å¦“å®œæˆ¯æŠ€æ“¬æ¬ºçŠ ç–‘ç¥‡ç¾©èŸ»èª¼è­°æŽ¬èŠéž å‰åƒå–«æ¡”æ©˜è©°ç §æµé»å´å®¢è„šè™é€†ä¸˜ä¹…ä»‡ä¼‘åŠå¸å®®å¼“æ€¥æ•‘?  æœ½æ±‚æ±²æ³£ç¸çƒç©¶çª®ç¬ˆç´šç³¾çµ¦æ—§ç‰›åŽ»å±…å·¨æ‹’æ‹ æŒ™æ¸ è™šè¨±è·é‹¸æ¼ç¦¦é­šäº¨äº«äº¬ä¾›ä¾ åƒ‘å…‡ç«¶å…±å‡¶å”åŒ¡å¿å«å–¬å¢ƒå³¡å¼·å½Šæ€¯ææ­æŒŸæ•™æ©‹æ³ç‹‚ç‹­çŸ¯èƒ¸è„…èˆˆè•Žéƒ·é¡éŸ¿é¥—é©šä»°å‡å°­æšæ¥­å±€æ›²æ¥µçŽ‰æ¡ç²åƒ…å‹¤å‡å·¾éŒ¦æ–¤æ¬£æ¬½ç´ç¦ç¦½ç­‹ç·ŠèŠ¹èŒè¡¿è¥Ÿè¬¹è¿‘é‡‘åŸéŠ€ä¹å€¶å¥åŒºç‹—çŽ–çŸ©è‹¦èº¯é§†é§ˆé§’å…·æ„šè™žå–°ç©ºå¶å¯“é‡éš…ä¸²æ«›é‡§å±‘å±ˆ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  æŽ˜çªŸæ²“é´è½¡çªªç†Šéšˆç²‚æ —ç¹°æ¡‘é¬å‹²å›è–«è¨“ç¾¤è»éƒ¡å¦è¢ˆç¥ä¿‚å‚¾åˆ‘å…„å•“åœ­çªåž‹å¥‘å½¢å¾„æµæ…¶æ…§æ†©æŽ²æºæ•¬æ™¯æ¡‚æ¸“ç•¦ç¨½ç³»çµŒç¶™ç¹‹ç½«èŒŽèŠè›è¨ˆè©£è­¦è»½é šé¶èŠ¸è¿Žé¯¨?  åŠ‡æˆŸæ’ƒæ¿€éš™æ¡å‚‘æ¬ æ±ºæ½”ç©´çµè¡€è¨£æœˆä»¶å€¹å€¦å¥å…¼åˆ¸å‰£å–§åœå …å«Œå»ºæ†²æ‡¸æ‹³æ²æ¤œæ¨©ç‰½çŠ¬çŒ®ç ”ç¡¯çµ¹çœŒè‚©è¦‹è¬™è³¢è»’é£éµé™ºé¡•é¨“é¹¸å…ƒåŽŸåŽ³å¹»å¼¦æ¸›æºçŽ„ç¾çµƒèˆ·è¨€è«ºé™ä¹Žå€‹å¤å‘¼å›ºå§‘å­¤å·±åº«å¼§æˆ¸æ•…æž¯æ¹–ç‹ç³Šè¢´è‚¡èƒ¡è°è™Žèª‡è·¨éˆ·é›‡é¡§é¼“äº”äº’ä¼åˆå‘‰å¾å¨¯å¾Œå¾¡æ‚Ÿæ¢§æªŽç‘šç¢èªžèª¤è­·é†ä¹žé¯‰äº¤ä½¼ä¾¯å€™å€–å…‰å…¬åŠŸåŠ¹å‹¾åŽšå£å‘?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  åŽå–‰å‘åž¢å¥½å­”å­å®å·¥å·§å··å¹¸åºƒåºšåº·å¼˜æ’æ…ŒæŠ—æ‹˜æŽ§æ”»æ˜‚æ™ƒæ›´æ­æ ¡æ¢—æ§‹æ±Ÿæ´ªæµ©æ¸¯æºç”²çš‡ç¡¬ç¨¿ç³ ç´…ç´˜çµžç¶±è€•è€ƒè‚¯è‚±è…”è†èˆªè’è¡Œè¡¡è¬›è²¢è³¼éƒŠé…µé‰±ç ¿é‹¼é–¤é™?  é …é¦™é«˜é´»å‰›åŠ«å·åˆå£•æ‹·æ¿ è±ªè½Ÿéº¹å…‹åˆ»å‘Šå›½ç©€é…·éµ é»’ç„æ¼‰è…°ç”‘å¿½æƒšéª¨ç‹›è¾¼æ­¤é ƒä»Šå›°å¤å¢¾å©šæ¨æ‡‡æ˜æ˜†æ ¹æ¢±æ··ç—•ç´ºè‰®é­‚äº›ä½å‰å”†åµ¯å·¦å·®æŸ»æ²™ç‘³ç ‚è©éŽ–è£Ÿååº§æŒ«å‚µå‚¬å†æœ€å“‰å¡žå¦»å®°å½©æ‰æŽ¡æ ½æ­³æ¸ˆç½é‡‡çŠ€ç •ç ¦ç¥­æ–Žç´°èœè£è¼‰éš›å‰¤åœ¨æç½ªè²¡å†´å‚é˜ªå ºæ¦Šè‚´å’²å´ŽåŸ¼ç¢•é·ºä½œå‰Šå’‹æ¾æ˜¨æœ”æŸµçª„ç­–ç´¢éŒ¯æ¡œé®­ç¬¹åŒ™å†Šåˆ·?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  å¯Ÿæ‹¶æ’®æ“¦æœ­æ®ºè–©é›‘çšé¯–æŒéŒ†é®«çš¿æ™’ä¸‰å‚˜å‚å±±æƒ¨æ’’æ•£æ¡Ÿç‡¦çŠç”£ç®—çº‚èš•è®ƒè³›é…¸é¤æ–¬æš«æ®‹ä»•ä»”ä¼ºä½¿åˆºå¸å²å—£å››å£«å§‹å§‰å§¿å­å±å¸‚å¸«å¿—æ€æŒ‡æ”¯å­œæ–¯æ–½æ—¨æžæ­¢?  æ­»æ°ç…ç¥‰ç§ç³¸ç´™ç´«è‚¢è„‚è‡³è¦–è©žè©©è©¦èªŒè«®è³‡è³œé›Œé£¼æ­¯äº‹ä¼¼ä¾å…å­—å¯ºæ…ˆæŒæ™‚æ¬¡æ»‹æ²»çˆ¾ç’½ç—”ç£ç¤ºè€Œè€³è‡ªè’”è¾žæ±é¹¿å¼è­˜é´«ç«ºè»¸å®é›«ä¸ƒå±åŸ·å¤±å«‰å®¤æ‚‰æ¹¿æ¼†ç–¾è³ªå®Ÿè”€ç¯ å²æŸ´èŠå±¡è•Šç¸žèˆŽå†™å°„æ¨èµ¦æ–œç…®ç¤¾ç´—è€…è¬è»Šé®è›‡é‚ªå€Ÿå‹ºå°ºæ“ç¼çˆµé…Œé‡ˆéŒ«è‹¥å¯‚å¼±æƒ¹ä¸»å–å®ˆæ‰‹æœ±æ®Šç‹©ç ç¨®è…«è¶£é…’é¦–å„’å—å‘ªå¯¿æŽˆæ¨¹ç¶¬éœ€å›šåŽå‘¨?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  å®—å°±å·žä¿®æ„æ‹¾æ´²ç§€ç§‹çµ‚ç¹ç¿’è‡­èˆŸè’è¡†è¥²è®è¹´è¼¯é€±é…‹é…¬é›†é†œä»€ä½å……åå¾“æˆŽæŸ”æ±æ¸‹ç£ç¸¦é‡éŠƒå”å¤™å®¿æ·‘ç¥ç¸®ç²›å¡¾ç†Ÿå‡ºè¡“è¿°ä¿Šå³»æ˜¥çž¬ç«£èˆœé§¿å‡†å¾ªæ—¬æ¥¯æ®‰æ·³?  æº–æ½¤ç›¾ç´”å·¡éµé†‡é †å‡¦åˆæ‰€æš‘æ›™æ¸šåº¶ç·’ç½²æ›¸è–¯è—·è«¸åŠ©å™å¥³åºå¾æ•é‹¤é™¤å‚·å„Ÿå‹åŒ å‡å¬å“¨å•†å”±å˜—å¥¨å¦¾å¨¼å®µå°†å°å°‘å°šåº„åºŠå» å½°æ‰¿æŠ„æ‹›æŽŒæ·æ˜‡æ˜Œæ˜­æ™¶æ¾æ¢¢æ¨Ÿæ¨µæ²¼æ¶ˆæ¸‰æ¹˜ç„¼ç„¦ç…§ç—‡çœç¡ç¤ç¥¥ç§°ç« ç¬‘ç²§ç´¹è‚–è–è’‹è•‰è¡è£³è¨Ÿè¨¼è©”è©³è±¡è³žé†¤é‰¦é¾é˜éšœéž˜ä¸Šä¸ˆä¸žä¹—å†—å‰°åŸŽå ´å£Œå¬¢å¸¸æƒ…æ“¾æ¡æ–æµ„çŠ¶ç•³ç©£è’¸è­²é†¸éŒ å˜±åŸ´é£¾?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  æ‹­æ¤æ®–ç‡­ç¹”è·è‰²è§¦é£Ÿè•è¾±å°»ä¼¸ä¿¡ä¾µå”‡å¨ å¯å¯©å¿ƒæ…ŽæŒ¯æ–°æ™‹æ£®æ¦›æµ¸æ·±ç”³ç–¹çœŸç¥žç§¦ç´³è‡£èŠ¯è–ªè¦ªè¨ºèº«è¾›é€²é‡éœ‡äººä»åˆƒå¡µå£¬å°‹ç”šå°½è…Žè¨Šè¿…é™£é­ç¬¥è«é ˆé…¢å›³åŽ¨?  é€—å¹åž‚å¸¥æŽ¨æ°´ç‚Šç¡ç²‹ç¿ è¡°é‚é…”éŒéŒ˜éšç‘žé«„å´‡åµ©æ•°æž¢è¶¨é››æ®æ‰æ¤™è…é —é›€è£¾æ¾„æ‘ºå¯¸ä¸–ç€¬ç•æ˜¯å‡„åˆ¶å‹¢å§“å¾æ€§æˆæ”¿æ•´æ˜Ÿæ™´æ£²æ –æ­£æ¸…ç‰²ç”Ÿç››ç²¾è–å£°è£½è¥¿èª èª“è«‹é€é†’é’é™æ–‰ç¨Žè„†éš»å¸­æƒœæˆšæ–¥æ˜”æžçŸ³ç©ç±ç¸¾è„Šè²¬èµ¤è·¡è¹Ÿç¢©åˆ‡æ‹™æŽ¥æ‘‚æŠ˜è¨­çªƒç¯€èª¬é›ªçµ¶èˆŒè‰ä»™å…ˆåƒå å®£å°‚å°–å·æˆ¦æ‰‡æ’°æ “æ ´æ³‰æµ…æ´—æŸ“æ½œç…Žç…½æ—‹ç©¿ç®­ç·š?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ç¹Šç¾¨è…ºèˆ›èˆ¹è–¦è©®è³Žè·µé¸é·éŠ­éŠ‘é–ƒé®®å‰å–„æ¼¸ç„¶å…¨ç¦…ç¹•è†³ç³Žå™Œå¡‘å²¨æŽªæ›¾æ›½æ¥šç‹™ç–ç–Žç¤Žç¥–ç§Ÿç²—ç´ çµ„è˜‡è¨´é˜»é¡é¼ åƒ§å‰µåŒå¢å€‰å–ªå£®å¥çˆ½å®‹å±¤åŒæƒ£æƒ³æœæŽƒæŒ¿æŽ»?  æ“æ—©æ›¹å·£æ§æ§½æ¼•ç‡¥äº‰ç—©ç›¸çª“ç³Ÿç·ç¶œè¡è‰è˜è‘¬è’¼è—»è£…èµ°é€é­éŽ—éœœé¨’åƒå¢—æ†Žè‡“è”µè´ˆé€ ä¿ƒå´å‰‡å³æ¯æ‰æŸæ¸¬è¶³é€Ÿä¿—å±žè³Šæ—ç¶šå’è¢–å…¶æƒå­˜å­«å°Šææ‘éœä»–å¤šå¤ªæ±°è©‘å”¾å •å¦¥æƒ°æ‰“æŸèˆµæ¥•é™€é§„é¨¨ä½“å †å¯¾è€å²±å¸¯å¾…æ€ æ…‹æˆ´æ›¿æ³°æ»žèƒŽè…¿è‹”è¢‹è²¸é€€é€®éšŠé»›é¯›ä»£å°å¤§ç¬¬é†é¡Œé·¹æ»ç€§å“å•„å®…æ‰˜æŠžæ‹“æ²¢æ¿¯ç¢è¨—é¸æ¿è«¾èŒ¸å‡§è›¸åª?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  å©ä½†é”è¾°å¥ªè„±å·½ç«ªè¾¿æ£šè°·ç‹¸é±ˆæ¨½èª°ä¸¹å˜å˜†å¦æ‹…æŽ¢æ—¦æ­Žæ·¡æ¹›ç‚­çŸ­ç«¯ç®ªç¶»è€½èƒ†è›‹èª•é›å›£å£‡å¼¾æ–­æš–æª€æ®µç”·è«‡å€¤çŸ¥åœ°å¼›æ¥æ™ºæ± ç—´ç¨šç½®è‡´èœ˜é…é¦³ç¯‰ç•œç«¹ç­‘è“„?  é€ç§©çª’èŒ¶å«¡ç€ä¸­ä»²å®™å¿ æŠ½æ˜¼æŸ±æ³¨è™«è¡·è¨»é…Žé‹³é§æ¨—ç€¦çŒªè‹§è‘—è²¯ä¸å…†å‡‹å–‹å¯µå¸–å¸³åºå¼”å¼µå½«å¾´æ‡²æŒ‘æš¢æœæ½®ç‰’ç”ºçœºè´è„¹è…¸è¶èª¿è«œè¶…è·³éŠšé•·é ‚é³¥å‹…æ—ç›´æœ•æ²ˆçè³ƒéŽ®é™³æ´¥å¢œæ¤Žæ§Œè¿½éŽšç—›é€šå¡šæ ‚æŽ´æ§»ä½ƒæ¼¬æŸ˜è¾»è”¦ç¶´é”æ¤¿æ½°åªå£·å¬¬ç´¬çˆªåŠé‡£é¶´äº­ä½Žåœåµå‰ƒè²žå‘ˆå ¤å®šå¸åº•åº­å»·å¼Ÿæ‚ŒæŠµæŒºææ¢¯æ±€ç¢‡ç¦Žç¨‹ç· è‰‡è¨‚è«¦è¹„é€“?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  é‚¸é„­é‡˜é¼Žæ³¥æ‘˜æ“¢æ•µæ»´çš„ç¬›é©é‘æººå“²å¾¹æ’¤è½è¿­é‰„å…¸å¡«å¤©å±•åº—æ·»çºç”œè²¼è»¢é¡›ç‚¹ä¼æ®¿æ¾±ç”°é›»å…Žåå µå¡—å¦¬å± å¾’æ–—æœæ¸¡ç™»èŸè³­é€”éƒ½éç ¥ç ºåŠªåº¦åœŸå¥´æ€’å€’å…šå†¬?  å‡åˆ€å”å¡”å¡˜å¥—å®•å³¶å¶‹æ‚¼æŠ•æ­æ±æ¡ƒæ¢¼æ£Ÿç›—æ·˜æ¹¯æ¶›ç¯ç‡ˆå½“ç—˜ç¥·ç­‰ç­”ç­’ç³–çµ±åˆ°è‘£è•©è—¤è¨Žè¬„è±†è¸é€ƒé€é™é™¶é ­é¨°é—˜åƒå‹•åŒå ‚å°Žæ†§æ’žæ´žçž³ç«¥èƒ´è„é“éŠ…å³ é´‡åŒ¿å¾—å¾³æ¶œç‰¹ç£ç¦¿ç¯¤æ¯’ç‹¬èª­æ ƒæ©¡å‡¸çªæ¤´å±Šé³¶è‹«å¯…é…‰ç€žå™¸å±¯æƒ‡æ•¦æ²Œè±šéé “å‘‘æ›‡éˆå¥ˆé‚£å†…ä¹å‡ªè–™è¬Žç˜æºé‹æ¥¢é¦´ç¸„ç•·å—æ¥ è»Ÿé›£æ±äºŒå°¼å¼è¿©åŒ‚è³‘è‚‰è™¹å»¿æ—¥ä¹³å…¥?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  å¦‚å°¿éŸ®ä»»å¦Šå¿èªæ¿¡ç¦°ç¥¢å¯§è‘±çŒ«ç†±å¹´å¿µæ»æ’šç‡ƒç²˜ä¹ƒå»¼ä¹‹åŸœåš¢æ‚©æ¿ƒç´èƒ½è„³è†¿è¾²è¦—èš¤å·´æŠŠæ’­è¦‡æ·æ³¢æ´¾ç¶ç ´å©†ç½µèŠ­é¦¬ä¿³å»ƒæ‹æŽ’æ•—æ¯ç›ƒç‰ŒèƒŒè‚ºè¼©é…å€åŸ¹åª’æ¢…?  æ¥³ç…¤ç‹½è²·å£²è³ é™ªé€™è¿ç§¤çŸ§è©ä¼¯å‰¥åšæ‹æŸæ³Šç™½ç®”ç²•èˆ¶è–„è¿«æ›æ¼ çˆ†ç¸›èŽ«é§éº¦å‡½ç®±ç¡²ç®¸è‚‡ç­ˆæ«¨å¹¡è‚Œç•‘ç• å…«é‰¢æºŒç™ºé†—é«ªä¼ç½°æŠœç­é–¥é³©å™ºå¡™è›¤éš¼ä¼´åˆ¤åŠåå›å¸†æ¬æ–‘æ¿æ°¾æ±Žç‰ˆçŠ¯ç­ç•”ç¹èˆ¬è—©è²©ç¯„é‡†ç…©é ’é£¯æŒ½æ™©ç•ªç›¤ç£è•ƒè›®åŒªå‘å¦å¦ƒåº‡å½¼æ‚²æ‰‰æ‰¹æŠ«æ–æ¯”æ³Œç–²çš®ç¢‘ç§˜ç·‹ç½·è‚¥è¢«èª¹è²»é¿éžé£›æ¨‹ç°¸å‚™å°¾å¾®æž‡æ¯˜çµçœ‰ç¾Ž?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  é¼»æŸŠç¨—åŒ¹ç–‹é«­å½¦è†è±è‚˜å¼¼å¿…ç•¢ç­†é€¼æ¡§å§«åª›ç´ç™¾è¬¬ä¿µå½ªæ¨™æ°·æ¼‚ç“¢ç¥¨è¡¨è©•è±¹å»Ÿæç—…ç§’è‹—éŒ¨é‹²è’œè›­é°­å“å½¬æ–Œæµœç€•è²§è³“é »æ•ç“¶ä¸ä»˜åŸ å¤«å©¦å¯Œå†¨å¸ƒåºœæ€–æ‰¶æ•·?  æ–§æ™®æµ®çˆ¶ç¬¦è…è†šèŠ™è­œè² è³¦èµ´é˜œé™„ä¾®æ’«æ­¦èˆžè‘¡è•ªéƒ¨å°æ¥“é¢¨è‘ºè•—ä¼å‰¯å¾©å¹…æœç¦è…¹è¤‡è¦†æ·µå¼—æ‰•æ²¸ä»ç‰©é®’åˆ†å»å™´å¢³æ†¤æ‰®ç„šå¥®ç²‰ç³žç´›é›°æ–‡èžä¸™ä½µå…µå¡€å¹£å¹³å¼ŠæŸ„ä¸¦è”½é–‰é™›ç±³é åƒ»å£ç™–ç¢§åˆ¥çž¥è”‘ç®†åå¤‰ç‰‡ç¯‡ç·¨è¾ºè¿”éä¾¿å‹‰å¨©å¼éž­ä¿èˆ—é‹ªåœƒæ•æ­©ç”«è£œè¼”ç©‚å‹Ÿå¢“æ…•æˆŠæš®æ¯ç°¿è©å€£ä¿¸åŒ…å‘†å ±å¥‰å®å³°å³¯å´©åº–æŠ±æ§æ”¾æ–¹æœ‹?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  æ³•æ³¡çƒ¹ç ²ç¸«èƒžèŠ³èŒè“¬èœ‚è¤’è¨ªè±Šé‚¦é‹’é£½é³³éµ¬ä¹äº¡å‚å‰–åŠå¦¨å¸½å¿˜å¿™æˆ¿æš´æœ›æŸæ£’å†’ç´¡è‚ªè†¨è¬€è²Œè²¿é‰¾é˜²å é ¬åŒ—åƒ•åœå¢¨æ’²æœ´ç‰§ç¦ç©†é‡¦å‹ƒæ²¡æ®†å €å¹Œå¥”æœ¬ç¿»å‡¡ç›†?  æ‘©ç£¨é­”éº»åŸ‹å¦¹æ˜§æžšæ¯Žå“©æ§™å¹•è†œæž•é®ªæŸ¾é±’æ¡äº¦ä¿£åˆæŠ¹æœ«æ²«è¿„ä¾­ç¹­éº¿ä¸‡æ…¢æº€æ¼«è”“å‘³æœªé­…å·³ç®•å²¬å¯†èœœæ¹Šè“‘ç¨”è„ˆå¦™ç²æ°‘çœ å‹™å¤¢ç„¡ç‰ŸçŸ›éœ§éµ¡æ¤‹å©¿å¨˜å†¥åå‘½æ˜Žç›Ÿè¿·éŠ˜é³´å§ªç‰æ»…å…æ£‰ç¶¿ç·¬é¢éººæ‘¸æ¨¡èŒ‚å¦„å­Ÿæ¯›çŒ›ç›²ç¶²è€—è’™å„²æœ¨é»™ç›®æ¢å‹¿é¤…å°¤æˆ»ç±¾è²°å•æ‚¶ç´‹é–€åŒä¹Ÿå†¶å¤œçˆºè€¶é‡Žå¼¥çŸ¢åŽ„å½¹ç´„è–¬è¨³èºé–æŸ³è–®é‘“æ„‰æ„ˆæ²¹ç™’?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  è«­è¼¸å”¯ä½‘å„ªå‹‡å‹å®¥å¹½æ‚ æ†‚æ–æœ‰æŸšæ¹§æ¶ŒçŒ¶çŒ·ç”±ç¥è£•èª˜éŠé‚‘éƒµé›„èžå¤•äºˆä½™ä¸Žèª‰è¼¿é å‚­å¹¼å¦–å®¹åº¸æšæºæ“æ›œæ¥Šæ§˜æ´‹æº¶ç†”ç”¨çª¯ç¾Šè€€è‘‰è“‰è¦è¬¡è¸Šé¥é™½é¤Šæ…¾æŠ‘æ¬²?  æ²ƒæµ´ç¿Œç¿¼æ·€ç¾…èžºè£¸æ¥èŽ±é ¼é›·æ´›çµ¡è½é…ªä¹±åµåµæ¬„æ¿«è—è˜­è¦§åˆ©åå±¥æŽæ¢¨ç†ç’ƒç—¢è£è£¡é‡Œé›¢é™¸å¾‹çŽ‡ç«‹è‘ŽæŽ ç•¥åŠ‰æµæºœç‰ç•™ç¡«ç²’éš†ç«œé¾ä¾¶æ…®æ—…è™œäº†äº®åƒšä¸¡å‡Œå¯®æ–™æ¢æ¶¼çŒŸç™‚çž­ç¨œç³§è‰¯è«’é¼é‡é™µé ˜åŠ›ç·‘å€«åŽ˜æž—æ·‹ç‡ç³è‡¨è¼ªéš£é±—éºŸç‘ å¡æ¶™ç´¯é¡žä»¤ä¼¶ä¾‹å†·åŠ±å¶ºæ€œçŽ²ç¤¼è‹“éˆ´éš·é›¶éœŠéº—é½¢æš¦æ­´åˆ—åŠ£çƒˆè£‚å»‰æ‹æ†æ¼£ç…‰ç°¾ç·´è¯?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  è“®é€£éŒ¬å‘‚é­¯æ«“ç‚‰è³‚è·¯éœ²åŠ´å©å»Šå¼„æœ—æ¥¼æ¦”æµªæ¼ç‰¢ç‹¼ç¯­è€è¾è‹éƒŽå…­éº“ç¦„è‚‹éŒ²è«–å€­å’Œè©±æ­ªè³„è„‡æƒ‘æž é·²äº™äº˜é°è©«è—è•¨æ¤€æ¹¾ç¢—è…•?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  å¼Œä¸ä¸•ä¸ªä¸±ä¸¶ä¸¼ä¸¿ä¹‚ä¹–ä¹˜äº‚äº…è±«äºŠèˆ’å¼äºŽäºžäºŸäº äº¢äº°äº³äº¶ä»Žä»ä»„ä»†ä»‚ä»—ä»žä»­ä»Ÿä»·ä¼‰ä½šä¼°ä½›ä½ä½—ä½‡ä½¶ä¾ˆä¾ä¾˜ä½»ä½©ä½°ä¾‘ä½¯ä¾†ä¾–å„˜ä¿”ä¿Ÿä¿Žä¿˜ä¿›ä¿‘ä¿šä¿ä¿¤ä¿¥å€šå€¨å€”å€ªå€¥å€…ä¼œä¿¶å€¡å€©å€¬ä¿¾ä¿¯å€‘å€†åƒå‡æœƒå•ååˆåšå–å¬å¸å‚€å‚šå‚…å‚´å‚²?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  åƒ‰åƒŠå‚³åƒ‚åƒ–åƒžåƒ¥åƒ­åƒ£åƒ®åƒ¹åƒµå„‰å„å„‚å„–å„•å„”å„šå„¡å„ºå„·å„¼å„»å„¿å…€å…’å…Œå…”å…¢ç«¸å…©å…ªå…®å†€å†‚å›˜å†Œå†‰å†å†‘å†“å†•å†–å†¤å†¦å†¢å†©å†ªå†«å†³å†±å†²å†°å†µå†½å‡…å‡‰å‡›å‡ è™•å‡©å‡­?  å‡°å‡µå‡¾åˆ„åˆ‹åˆ”åˆŽåˆ§åˆªåˆ®åˆ³åˆ¹å‰å‰„å‰‹å‰Œå‰žå‰”å‰ªå‰´å‰©å‰³å‰¿å‰½åŠåŠ”åŠ’å‰±åŠˆåŠ‘è¾¨è¾§åŠ¬åŠ­åŠ¼åŠµå‹å‹å‹—å‹žå‹£å‹¦é£­å‹ å‹³å‹µå‹¸å‹¹åŒ†åŒˆç”¸åŒåŒåŒåŒ•åŒšåŒ£åŒ¯åŒ±åŒ³åŒ¸å€å†å…ä¸—å‰åå‡–åžå©å®å¤˜å»å·åŽ‚åŽ–åŽ åŽ¦åŽ¥åŽ®åŽ°åŽ¶åƒç°’é›™åŸæ›¼ç‡®å®å¨å­åºåå½å‘€å¬å­å¼å®å¶å©åå‘Žå’å‘µå’Žå‘Ÿå‘±å‘·å‘°å’’å‘»å’€å‘¶å’„å’å’†å“‡å’¢å’¸å’¥å’¬å“„å“ˆå’¨?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  å’«å“‚å’¤å’¾å’¼å“˜å“¥å“¦å”å””å“½å“®å“­å“ºå“¢å”¹å•€å•£å•Œå”®å•œå•…å•–å•—å”¸å”³å•å–™å–€å’¯å–Šå–Ÿå•»å•¾å–˜å–žå–®å•¼å–ƒå–©å–‡å–¨å—šå—…å—Ÿå—„å—œå—¤å—”å˜”å—·å˜–å—¾å—½å˜›å—¹å™Žå™ç‡Ÿå˜´å˜¶å˜²å˜¸?  å™«å™¤å˜¯å™¬å™ªåš†åš€åšŠåš åš”åšåš¥åš®åš¶åš´å›‚åš¼å›å›ƒå›€å›ˆå›Žå›‘å›“å›—å›®å›¹åœ€å›¿åœ„åœ‰åœˆåœ‹åœåœ“åœ˜åœ–å—‡åœœåœ¦åœ·åœ¸åŽåœ»å€åå©åŸ€åžˆå¡å¿åž‰åž“åž åž³åž¤åžªåž°åŸƒåŸ†åŸ”åŸ’åŸ“å ŠåŸ–åŸ£å ‹å ™å å¡²å ¡å¡¢å¡‹å¡°æ¯€å¡’å ½å¡¹å¢…å¢¹å¢Ÿå¢«å¢ºå£žå¢»å¢¸å¢®å£…å£“å£‘å£—å£™å£˜å£¥å£œå£¤å£Ÿå£¯å£ºå£¹å£»å£¼å£½å¤‚å¤Šå¤å¤›æ¢¦å¤¥å¤¬å¤­å¤²å¤¸å¤¾ç«’å¥•å¥å¥Žå¥šå¥˜å¥¢å¥ å¥§å¥¬å¥©?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  å¥¸å¦å¦ä½žä¾«å¦£å¦²å§†å§¨å§œå¦å§™å§šå¨¥å¨Ÿå¨‘å¨œå¨‰å¨šå©€å©¬å©‰å¨µå¨¶å©¢å©ªåªšåª¼åª¾å«‹å«‚åª½å«£å«—å«¦å«©å«–å«ºå«»å¬Œå¬‹å¬–å¬²å«å¬ªå¬¶å¬¾å­ƒå­…å­€å­‘å­•å­šå­›å­¥å­©å­°å­³å­µå­¸æ–ˆå­ºå®€?  å®ƒå®¦å®¸å¯ƒå¯‡å¯‰å¯”å¯å¯¤å¯¦å¯¢å¯žå¯¥å¯«å¯°å¯¶å¯³å°…å°‡å°ˆå°å°“å° å°¢å°¨å°¸å°¹å±å±†å±Žå±“å±å±å­±å±¬å±®ä¹¢å±¶å±¹å²Œå²‘å²”å¦›å²«å²»å²¶å²¼å²·å³…å²¾å³‡å³™å³©å³½å³ºå³­å¶Œå³ªå´‹å´•å´—åµœå´Ÿå´›å´‘å´”å´¢å´šå´™å´˜åµŒåµ’åµŽåµ‹åµ¬åµ³åµ¶å¶‡å¶„å¶‚å¶¢å¶å¶¬å¶®å¶½å¶å¶·å¶¼å·‰å·å·“å·’å·–å·›å·«å·²å·µå¸‹å¸šå¸™å¸‘å¸›å¸¶å¸·å¹„å¹ƒå¹€å¹Žå¹—å¹”å¹Ÿå¹¢å¹¤å¹‡å¹µå¹¶å¹ºéº¼å¹¿åº å»å»‚å»ˆå»å»?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  å»–å»£å»å»šå»›å»¢å»¡å»¨å»©å»¬å»±å»³å»°å»´å»¸å»¾å¼ƒå¼‰å½å½œå¼‹å¼‘å¼–å¼©å¼­å¼¸å½å½ˆå½Œå½Žå¼¯å½‘å½–å½—å½™å½¡å½­å½³å½·å¾ƒå¾‚å½¿å¾Šå¾ˆå¾‘å¾‡å¾žå¾™å¾˜å¾ å¾¨å¾­å¾¼å¿–å¿»å¿¤å¿¸å¿±å¿æ‚³å¿¿æ€¡æ ?  æ€™æ€æ€©æ€Žæ€±æ€›æ€•æ€«æ€¦æ€æ€ºæšææªæ·æŸæŠæ†ææ£æƒæ¤æ‚æ¬æ«æ™æ‚æ‚æƒ§æ‚ƒæ‚šæ‚„æ‚›æ‚–æ‚—æ‚’æ‚§æ‚‹æƒ¡æ‚¸æƒ æƒ“æ‚´å¿°æ‚½æƒ†æ‚µæƒ˜æ…æ„•æ„†æƒ¶æƒ·æ„€æƒ´æƒºæ„ƒæ„¡æƒ»æƒ±æ„æ„Žæ…‡æ„¾æ„¨æ„§æ…Šæ„¿æ„¼æ„¬æ„´æ„½æ…‚æ…„æ…³æ…·æ…˜æ…™æ…šæ…«æ…´æ…¯æ…¥æ…±æ…Ÿæ…æ…“æ…µæ†™æ†–æ†‡æ†¬æ†”æ†šæ†Šæ†‘æ†«æ†®æ‡Œæ‡Šæ‡‰æ‡·æ‡ˆæ‡ƒæ‡†æ†ºæ‡‹ç½¹æ‡æ‡¦æ‡£æ‡¶æ‡ºæ‡´æ‡¿æ‡½æ‡¼æ‡¾æˆ€æˆˆæˆ‰æˆæˆŒæˆ”æˆ›?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  æˆžæˆ¡æˆªæˆ®æˆ°æˆ²æˆ³æ‰æ‰Žæ‰žæ‰£æ‰›æ‰ æ‰¨æ‰¼æŠ‚æŠ‰æ‰¾æŠ’æŠ“æŠ–æ‹”æŠƒæŠ”æ‹—æ‹‘æŠ»æ‹æ‹¿æ‹†æ“”æ‹ˆæ‹œæ‹Œæ‹Šæ‹‚æ‹‡æŠ›æ‹‰æŒŒæ‹®æ‹±æŒ§æŒ‚æŒˆæ‹¯æ‹µææŒ¾ææœææŽ–æŽŽæŽ€æŽ«æ¶æŽ£æŽæŽ‰æŽŸæŽµæ«?  æ©æŽ¾æ©æ€æ†æ£æ‰æ’æ¶æ„æ–æ´æ†æ“æ¦æ¶æ”æ—æ¨ææ‘§æ‘¯æ‘¶æ‘Žæ”ªæ’•æ’“æ’¥æ’©æ’ˆæ’¼æ“šæ“’æ“…æ“‡æ’»æ“˜æ“‚æ“±æ“§èˆ‰æ“ æ“¡æŠ¬æ“£æ“¯æ”¬æ“¶æ“´æ“²æ“ºæ”€æ“½æ”˜æ”œæ”…æ”¤æ”£æ”«æ”´æ”µæ”·æ”¶æ”¸ç•‹æ•ˆæ•–æ••æ•æ•˜æ•žæ•æ•²æ•¸æ–‚æ–ƒè®Šæ–›æ–Ÿæ–«æ–·æ—ƒæ—†æ—æ—„æ—Œæ—’æ—›æ—™æ— æ—¡æ—±æ²æ˜Šæ˜ƒæ—»æ³æ˜µæ˜¶æ˜´æ˜œæ™æ™„æ™‰æ™æ™žæ™æ™¤æ™§æ™¨æ™Ÿæ™¢æ™°æšƒæšˆæšŽæš‰æš„æš˜æšæ›æš¹æ›‰æš¾æš¼?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  æ›„æš¸æ›–æ›šæ› æ˜¿æ›¦æ›©æ›°æ›µæ›·æœæœ–æœžæœ¦æœ§éœ¸æœ®æœ¿æœ¶ææœ¸æœ·æ†æžæ æ™æ£æ¤æž‰æ°æž©æ¼æªæžŒæž‹æž¦æž¡æž…æž·æŸ¯æž´æŸ¬æž³æŸ©æž¸æŸ¤æŸžæŸæŸ¢æŸ®æž¹æŸŽæŸ†æŸ§æªœæ žæ¡†æ ©æ¡€æ¡æ ²æ¡Ž?  æ¢³æ «æ¡™æ¡£æ¡·æ¡¿æ¢Ÿæ¢æ¢­æ¢”æ¢æ¢›æ¢ƒæª®æ¢¹æ¡´æ¢µæ¢ æ¢ºæ¤æ¢æ¡¾æ¤æ£Šæ¤ˆæ£˜æ¤¢æ¤¦æ£¡æ¤Œæ£æ£”æ£§æ£•æ¤¶æ¤’æ¤„æ£—æ££æ¤¥æ£¹æ£ æ£¯æ¤¨æ¤ªæ¤šæ¤£æ¤¡æ£†æ¥¹æ¥·æ¥œæ¥¸æ¥«æ¥”æ¥¾æ¥®æ¤¹æ¥´æ¤½æ¥™æ¤°æ¥¡æ¥žæ¥æ¦æ¥ªæ¦²æ¦®æ§æ¦¿æ§æ§“æ¦¾æ§Žå¯¨æ§Šæ§æ¦»æ§ƒæ¦§æ¨®æ¦‘æ¦ æ¦œæ¦•æ¦´æ§žæ§¨æ¨‚æ¨›æ§¿æ¬Šæ§¹æ§²æ§§æ¨…æ¦±æ¨žæ§­æ¨”æ§«æ¨Šæ¨’æ«æ¨£æ¨“æ©„æ¨Œæ©²æ¨¶æ©¸æ©‡æ©¢æ©™æ©¦æ©ˆæ¨¸æ¨¢æªæªæª æª„æª¢æª£?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  æª—è˜—æª»æ«ƒæ«‚æª¸æª³æª¬æ«žæ«‘æ«Ÿæªªæ«šæ«ªæ«»æ¬…è˜–æ«ºæ¬’æ¬–é¬±æ¬Ÿæ¬¸æ¬·ç›œæ¬¹é£®æ­‡æ­ƒæ­‰æ­æ­™æ­”æ­›æ­Ÿæ­¡æ­¸æ­¹æ­¿æ®€æ®„æ®ƒæ®æ®˜æ®•æ®žæ®¤æ®ªæ®«æ®¯æ®²æ®±æ®³æ®·æ®¼æ¯†æ¯‹æ¯“æ¯Ÿæ¯¬æ¯«æ¯³æ¯¯?  éº¾æ°ˆæ°“æ°”æ°›æ°¤æ°£æ±žæ±•æ±¢æ±ªæ²‚æ²æ²šæ²æ²›æ±¾æ±¨æ±³æ²’æ²æ³„æ³±æ³“æ²½æ³—æ³…æ³æ²®æ²±æ²¾æ²ºæ³›æ³¯æ³™æ³ªæ´Ÿè¡æ´¶æ´«æ´½æ´¸æ´™æ´µæ´³æ´’æ´Œæµ£æ¶“æµ¤æµšæµ¹æµ™æ¶Žæ¶•æ¿¤æ¶…æ·¹æ¸•æ¸Šæ¶µæ·‡æ·¦æ¶¸æ·†æ·¬æ·žæ·Œæ·¨æ·’æ·…æ·ºæ·™æ·¤æ·•æ·ªæ·®æ¸­æ¹®æ¸®æ¸™æ¹²æ¹Ÿæ¸¾æ¸£æ¹«æ¸«æ¹¶æ¹æ¸Ÿæ¹ƒæ¸ºæ¹Žæ¸¤æ»¿æ¸æ¸¸æº‚æºªæº˜æ»‰æº·æ»“æº½æº¯æ»„æº²æ»”æ»•æºæº¥æ»‚æºŸæ½æ¼‘çŒæ»¬æ»¸æ»¾æ¼¿æ»²æ¼±æ»¯æ¼²æ»Œ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  æ¼¾æ¼“æ»·æ¾†æ½ºæ½¸æ¾æ¾€æ½¯æ½›æ¿³æ½­æ¾‚æ½¼æ½˜æ¾Žæ¾‘æ¿‚æ½¦æ¾³æ¾£æ¾¡æ¾¤æ¾¹æ¿†æ¾ªæ¿Ÿæ¿•æ¿¬æ¿”æ¿˜æ¿±æ¿®æ¿›ç€‰ç€‹æ¿ºç€‘ç€ç€æ¿¾ç€›ç€šæ½´ç€ç€˜ç€Ÿç€°ç€¾ç€²ç‘ç£ç‚™ç‚’ç‚¯çƒ±ç‚¬ç‚¸ç‚³ç‚®çƒŸçƒ‹çƒ?  çƒ™ç„‰çƒ½ç„œç„™ç…¥ç…•ç†ˆç…¦ç…¢ç…Œç…–ç…¬ç†ç‡»ç†„ç†•ç†¨ç†¬ç‡—ç†¹ç†¾ç‡’ç‡‰ç‡”ç‡Žç‡ ç‡¬ç‡§ç‡µç‡¼ç‡¹ç‡¿çˆçˆçˆ›çˆ¨çˆ­çˆ¬çˆ°çˆ²çˆ»çˆ¼çˆ¿ç‰€ç‰†ç‰‹ç‰˜ç‰´ç‰¾çŠ‚çŠçŠ‡çŠ’çŠ–çŠ¢çŠ§çŠ¹çŠ²ç‹ƒç‹†ç‹„ç‹Žç‹’ç‹¢ç‹ ç‹¡ç‹¹ç‹·å€çŒ—çŒŠçŒœçŒ–çŒçŒ´çŒ¯çŒ©çŒ¥çŒ¾çŽçé»˜ç—çªç¨ç°ç¸çµç»çºçˆçŽ³çŽçŽ»ç€ç¥ç®çžç’¢ç…ç‘¯ç¥ç¸ç²çºç‘•ç¿ç‘Ÿç‘™ç‘ç‘œç‘©ç‘°ç‘£ç‘ªç‘¶ç‘¾ç’‹ç’žç’§ç“Šç“ç“”ç±?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ç“ ç“£ç“§ç“©ç“®ç“²ç“°ç“±ç“¸ç“·ç”„ç”ƒç”…ç”Œç”Žç”ç”•ç”“ç”žç”¦ç”¬ç”¼ç•„ç•ç•Šç•‰ç•›ç•†ç•šç•©ç•¤ç•§ç•«ç•­ç•¸ç•¶ç–†ç–‡ç•´ç–Šç–‰ç–‚ç–”ç–šç–ç–¥ç–£ç—‚ç–³ç—ƒç–µç–½ç–¸ç–¼ç–±ç—ç—Šç—’ç—™ç—£ç—žç—¾ç—¿?  ç—¼ç˜ç—°ç—ºç—²ç—³ç˜‹ç˜ç˜‰ç˜Ÿç˜§ç˜ ç˜¡ç˜¢ç˜¤ç˜´ç˜°ç˜»ç™‡ç™ˆç™†ç™œç™˜ç™¡ç™¢ç™¨ç™©ç™ªç™§ç™¬ç™°ç™²ç™¶ç™¸ç™¼çš€çšƒçšˆçš‹çšŽçš–çš“çš™çššçš°çš´çš¸çš¹çšºç›‚ç›ç›–ç›’ç›žç›¡ç›¥ç›§ç›ªè˜¯ç›»çœˆçœ‡çœ„çœ©çœ¤çœžçœ¥çœ¦çœ›çœ·çœ¸ç‡çšç¨ç«ç›ç¥ç¿ç¾ç¹çžŽçž‹çž‘çž çžžçž°çž¶çž¹çž¿çž¼çž½çž»çŸ‡çŸçŸ—çŸšçŸœçŸ£çŸ®çŸ¼ç Œç ’ç¤¦ç  ç¤ªç¡…ç¢Žç¡´ç¢†ç¡¼ç¢šç¢Œç¢£ç¢µç¢ªç¢¯ç£‘ç£†ç£‹ç£”ç¢¾ç¢¼ç£…ç£Šç£¬?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ç£§ç£šç£½ç£´ç¤‡ç¤’ç¤‘ç¤™ç¤¬ç¤«ç¥€ç¥ ç¥—ç¥Ÿç¥šç¥•ç¥“ç¥ºç¥¿ç¦Šç¦ç¦§é½‹ç¦ªç¦®ç¦³ç¦¹ç¦ºç§‰ç§•ç§§ç§¬ç§¡ç§£ç¨ˆç¨ç¨˜ç¨™ç¨ ç¨Ÿç¦€ç¨±ç¨»ç¨¾ç¨·ç©ƒç©—ç©‰ç©¡ç©¢ç©©é¾ç©°ç©¹ç©½çªˆçª—çª•çª˜çª–çª©ç«ˆçª°?  çª¶ç«…ç«„çª¿é‚ƒç«‡ç«Šç«ç«ç«•ç«“ç«™ç«šç«ç«¡ç«¢ç«¦ç«­ç«°ç¬‚ç¬ç¬Šç¬†ç¬³ç¬˜ç¬™ç¬žç¬µç¬¨ç¬¶ç­ç­ºç¬„ç­ç¬‹ç­Œç­…ç­µç­¥ç­´ç­§ç­°ç­±ç­¬ç­®ç®ç®˜ç®Ÿç®ç®œç®šç®‹ç®’ç®ç­ç®™ç¯‹ç¯ç¯Œç¯ç®´ç¯†ç¯ç¯©ç°‘ç°”ç¯¦ç¯¥ç± ç°€ç°‡ç°“ç¯³ç¯·ç°—ç°ç¯¶ç°£ç°§ç°ªç°Ÿç°·ç°«ç°½ç±Œç±ƒç±”ç±ç±€ç±ç±˜ç±Ÿç±¤ç±–ç±¥ç±¬ç±µç²ƒç²ç²¤ç²­ç²¢ç²«ç²¡ç²¨ç²³ç²²ç²±ç²®ç²¹ç²½ç³€ç³…ç³‚ç³˜ç³’ç³œç³¢é¬»ç³¯ç³²ç³´ç³¶ç³ºç´†?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ç´‚ç´œç´•ç´Šçµ…çµ‹ç´®ç´²ç´¿ç´µçµ†çµ³çµ–çµŽçµ²çµ¨çµ®çµçµ£ç¶“ç¶‰çµ›ç¶çµ½ç¶›ç¶ºç¶®ç¶£ç¶µç·‡ç¶½ç¶«ç¸½ç¶¢ç¶¯ç·œç¶¸ç¶Ÿç¶°ç·˜ç·ç·¤ç·žç·»ç·²ç·¡ç¸…ç¸Šç¸£ç¸¡ç¸’ç¸±ç¸Ÿç¸‰ç¸‹ç¸¢ç¹†ç¹¦ç¸»ç¸µç¸¹ç¹ƒç¸·?  ç¸²ç¸ºç¹§ç¹ç¹–ç¹žç¹™ç¹šç¹¹ç¹ªç¹©ç¹¼ç¹»çºƒç·•ç¹½è¾®ç¹¿çºˆçº‰çºŒçº’çºçº“çº”çº–çºŽçº›çºœç¼¸ç¼ºç½…ç½Œç½ç½Žç½ç½‘ç½•ç½”ç½˜ç½Ÿç½ ç½¨ç½©ç½§ç½¸ç¾‚ç¾†ç¾ƒç¾ˆç¾‡ç¾Œç¾”ç¾žç¾ç¾šç¾£ç¾¯ç¾²ç¾¹ç¾®ç¾¶ç¾¸è­±ç¿…ç¿†ç¿Šç¿•ç¿”ç¿¡ç¿¦ç¿©ç¿³ç¿¹é£œè€†è€„è€‹è€’è€˜è€™è€œè€¡è€¨è€¿è€»èŠè†è’è˜èšèŸè¢è¨è³è²è°è¶è¹è½è¿è‚„è‚†è‚…è‚›è‚“è‚šè‚­å†è‚¬èƒ›èƒ¥èƒ™èƒèƒ„èƒšèƒ–è„‰èƒ¯èƒ±è„›è„©è„£è„¯è…‹?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  éš‹è…†è„¾è…“è…‘èƒ¼è…±è…®è…¥è…¦è…´è†ƒè†ˆè†Šè†€è†‚è† è†•è†¤è†£è…Ÿè†“è†©è†°è†µè†¾è†¸è†½è‡€è‡‚è†ºè‡‰è‡è‡‘è‡™è‡˜è‡ˆè‡šè‡Ÿè‡ è‡§è‡ºè‡»è‡¾èˆèˆ‚èˆ…èˆ‡èˆŠèˆèˆèˆ–èˆ©èˆ«èˆ¸èˆ³è‰€è‰™è‰˜è‰è‰šè‰Ÿè‰¤?  è‰¢è‰¨è‰ªè‰«èˆ®è‰±è‰·è‰¸è‰¾èŠèŠ’èŠ«èŠŸèŠ»èŠ¬è‹¡è‹£è‹Ÿè‹’è‹´è‹³è‹ºèŽ“èŒƒè‹»è‹¹è‹žèŒ†è‹œèŒ‰è‹™èŒµèŒ´èŒ–èŒ²èŒ±è€èŒ¹èè…èŒ¯èŒ«èŒ—èŒ˜èŽ…èŽšèŽªèŽŸèŽ¢èŽ–èŒ£èŽŽèŽ‡èŽŠè¼èŽµè³èµèŽ èŽ‰èŽ¨è´è“è«èŽè½èƒè˜è‹èè·è‡è è²èè¢è èŽ½è¸è”†è»è‘­èªè¼è•šè’„è‘·è‘«è’­è‘®è’‚è‘©è‘†è¬è‘¯è‘¹èµè“Šè‘¢è’¹è’¿è’Ÿè“™è“è’»è“šè“è“è“†è“–è’¡è”¡è“¿è“´è”—è”˜è”¬è”Ÿè”•è””è“¼è•€è•£è•˜è•ˆ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  è•è˜‚è•‹è••è–€è–¤è–ˆè–‘è–Šè–¨è•­è–”è–›è—ªè–‡è–œè•·è•¾è–è—‰è–ºè—è–¹è—è—•è—è—¥è—œè—¹è˜Šè˜“è˜‹è—¾è—ºè˜†è˜¢è˜šè˜°è˜¿è™ä¹•è™”è™Ÿè™§è™±èš“èš£èš©èšªèš‹èšŒèš¶èš¯è›„è›†èš°è›‰è £èš«è›”è›žè›©è›¬?  è›Ÿè››è›¯èœ’èœ†èœˆèœ€èœƒè›»èœ‘èœ‰èœè›¹èœŠèœ´èœ¿èœ·èœ»èœ¥èœ©èœšè èŸè¸èŒèŽè´è—è¨è®è™è“è£èªè …èž¢èžŸèž‚èž¯èŸ‹èž½èŸ€èŸé›–èž«èŸ„èž³èŸ‡èŸ†èž»èŸ¯èŸ²èŸ è è èŸ¾èŸ¶èŸ·è ŽèŸ’è ‘è –è •è ¢è ¡è ±è ¶è ¹è §è »è¡„è¡‚è¡’è¡™è¡žè¡¢è¡«è¢è¡¾è¢žè¡µè¡½è¢µè¡²è¢‚è¢—è¢’è¢®è¢™è¢¢è¢è¢¤è¢°è¢¿è¢±è£ƒè£„è£”è£˜è£™è£è£¹è¤‚è£¼è£´è£¨è£²è¤„è¤Œè¤Šè¤“è¥ƒè¤žè¤¥è¤ªè¤«è¥è¥„è¤»è¤¶è¤¸è¥Œè¤è¥ è¥ž?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  è¥¦è¥¤è¥­è¥ªè¥¯è¥´è¥·è¥¾è¦ƒè¦ˆè¦Šè¦“è¦˜è¦¡è¦©è¦¦è¦¬è¦¯è¦²è¦ºè¦½è¦¿è§€è§šè§œè§è§§è§´è§¸è¨ƒè¨–è¨è¨Œè¨›è¨è¨¥è¨¶è©è©›è©’è©†è©ˆè©¼è©­è©¬è©¢èª…èª‚èª„èª¨èª¡èª‘èª¥èª¦èªšèª£è«„è«è«‚è«šè««è«³è«§?  è«¤è«±è¬”è« è«¢è«·è«žè«›è¬Œè¬‡è¬šè«¡è¬–è¬è¬—è¬ è¬³éž«è¬¦è¬«è¬¾è¬¨è­è­Œè­è­Žè­‰è­–è­›è­šè­«è­Ÿè­¬è­¯è­´è­½è®€è®Œè®Žè®’è®“è®–è®™è®šè°ºè±è°¿è±ˆè±Œè±Žè±è±•è±¢è±¬è±¸è±ºè²‚è²‰è²…è²Šè²è²Žè²”è±¼è²˜æˆè²­è²ªè²½è²²è²³è²®è²¶è³ˆè³è³¤è³£è³šè³½è³ºè³»è´„è´…è´Šè´‡è´è´è´é½Žè´“è³è´”è´–èµ§èµ­èµ±èµ³è¶è¶™è·‚è¶¾è¶ºè·è·šè·–è·Œè·›è·‹è·ªè·«è·Ÿè·£è·¼è¸ˆè¸‰è·¿è¸è¸žè¸è¸Ÿè¹‚è¸µè¸°è¸´è¹Š?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  è¹‡è¹‰è¹Œè¹è¹ˆè¹™è¹¤è¹ è¸ªè¹£è¹•è¹¶è¹²è¹¼èºèº‡èº…èº„èº‹èºŠèº“èº‘èº”èº™èºªèº¡èº¬èº°è»†èº±èº¾è»…è»ˆè»‹è»›è»£è»¼è»»è»«è»¾è¼Šè¼…è¼•è¼’è¼™è¼“è¼œè¼Ÿè¼›è¼Œè¼¦è¼³è¼»è¼¹è½…è½‚è¼¾è½Œè½‰è½†è½Žè½—è½œ?  è½¢è½£è½¤è¾œè¾Ÿè¾£è¾­è¾¯è¾·è¿šè¿¥è¿¢è¿ªè¿¯é‚‡è¿´é€…è¿¹è¿ºé€‘é€•é€¡é€é€žé€–é€‹é€§é€¶é€µé€¹è¿¸ééé‘é’é€Žé‰é€¾é–é˜éžé¨é¯é¶éš¨é²é‚‚é½é‚é‚€é‚Šé‚‰é‚é‚¨é‚¯é‚±é‚µéƒ¢éƒ¤æ‰ˆéƒ›é„‚é„’é„™é„²é„°é…Šé…–é…˜é…£é…¥é…©é…³é…²é†‹é†‰é†‚é†¢é†«é†¯é†ªé†µé†´é†ºé‡€é‡é‡‰é‡‹é‡é‡–é‡Ÿé‡¡é‡›é‡¼é‡µé‡¶éˆžé‡¿éˆ”éˆ¬éˆ•éˆ‘é‰žé‰—é‰…é‰‰é‰¤é‰ˆéŠ•éˆ¿é‰‹é‰éŠœéŠ–éŠ“éŠ›é‰šé‹éŠ¹éŠ·é‹©éŒé‹ºé„éŒ®?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  éŒ™éŒ¢éŒšéŒ£éŒºéŒµéŒ»éœé é¼é®é–éŽ°éŽ¬éŽ­éŽ”éŽ¹é–é—é¨é¥é˜éƒéééˆé¤éšé”é“éƒé‡éé¶é«éµé¡éºé‘é‘’é‘„é‘›é‘ é‘¢é‘žé‘ªéˆ©é‘°é‘µé‘·é‘½é‘šé‘¼é‘¾é’é‘¿é–‚é–‡é–Šé–”é––é–˜é–™?  é– é–¨é–§é–­é–¼é–»é–¹é–¾é—Šæ¿¶é—ƒé—é—Œé—•é—”é—–é—œé—¡é—¥é—¢é˜¡é˜¨é˜®é˜¯é™‚é™Œé™é™‹é™·é™œé™žé™é™Ÿé™¦é™²é™¬éšéš˜éš•éš—éšªéš§éš±éš²éš°éš´éš¶éš¸éš¹é›Žé›‹é›‰é›è¥é›œéœé›•é›¹éœ„éœ†éœˆéœ“éœŽéœ‘éœéœ–éœ™éœ¤éœªéœ°éœ¹éœ½éœ¾é„é†éˆé‚é‰éœé é¤é¦é¨å‹’é«é±é¹éž…é¼éžéºéž†éž‹éžéžéžœéž¨éž¦éž£éž³éž´éŸƒéŸ†éŸˆéŸ‹éŸœéŸ­é½éŸ²ç«ŸéŸ¶éŸµé é Œé ¸é ¤é ¡é ·é ½é¡†é¡é¡‹é¡«é¡¯é¡°?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  é¡±é¡´é¡³é¢ªé¢¯é¢±é¢¶é£„é£ƒé£†é£©é£«é¤ƒé¤‰é¤’é¤”é¤˜é¤¡é¤é¤žé¤¤é¤ é¤¬é¤®é¤½é¤¾é¥‚é¥‰é¥…é¥é¥‹é¥‘é¥’é¥Œé¥•é¦—é¦˜é¦¥é¦­é¦®é¦¼é§Ÿé§›é§é§˜é§‘é§­é§®é§±é§²é§»é§¸é¨é¨é¨…é§¢é¨™é¨«é¨·é©…é©‚é©€é©ƒ?  é¨¾é©•é©é©›é©—é©Ÿé©¢é©¥é©¤é©©é©«é©ªéª­éª°éª¼é«€é«é«‘é«“é«”é«žé«Ÿé«¢é«£é«¦é«¯é««é«®é«´é«±é«·é«»é¬†é¬˜é¬šé¬Ÿé¬¢é¬£é¬¥é¬§é¬¨é¬©é¬ªé¬®é¬¯é¬²é­„é­ƒé­é­é­Žé­‘é­˜é­´é®“é®ƒé®‘é®–é®—é®Ÿé® é®¨é®´é¯€é¯Šé®¹é¯†é¯é¯‘é¯’é¯£é¯¢é¯¤é¯”é¯¡é°ºé¯²é¯±é¯°é°•é°”é°‰é°“é°Œé°†é°ˆé°’é°Šé°„é°®é°›é°¥é°¤é°¡é°°é±‡é°²é±†é°¾é±šé± é±§é±¶é±¸é³§é³¬é³°é´‰é´ˆé³«é´ƒé´†é´ªé´¦é¶¯é´£é´Ÿéµ„é´•é´’éµé´¿é´¾éµ†éµˆ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  éµéµžéµ¤éµ‘éµéµ™éµ²é¶‰é¶‡é¶«éµ¯éµºé¶šé¶¤é¶©é¶²é·„é·é¶»é¶¸é¶ºé·†é·é·‚é·™é·“é·¸é·¦é·­é·¯é·½é¸šé¸›é¸žé¹µé¹¹é¹½éºéºˆéº‹éºŒéº’éº•éº‘éºéº¥éº©éº¸éºªéº­é¡é»Œé»Žé»é»é»”é»œé»žé»é» é»¥é»¨é»¯?  é»´é»¶é»·é»¹é»»é»¼é»½é¼‡é¼ˆçš·é¼•é¼¡é¼¬é¼¾é½Šé½’é½”é½£é½Ÿé½ é½¡é½¦é½§é½¬é½ªé½·é½²é½¶é¾•é¾œé¾ å ¯æ§‡é™ç‘¤å‡œç†™?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  çºŠè¤œéˆéŠˆè“œä¿‰ç‚»æ˜±æ£ˆé‹¹æ›»å½…ä¸¨ä»¡ä»¼ä¼€ä¼ƒä¼¹ä½–ä¾’ä¾Šä¾šä¾”ä¿å€å€¢ä¿¿å€žå†å°å‚å‚”åƒ´åƒ˜å…Šå…¤å†å†¾å‡¬åˆ•åŠœåŠ¦å‹€å‹›åŒ€åŒ‡åŒ¤å²åŽ“åŽ²åï¨Žå’œå’Šå’©å“¿å–†å™å¥åž¬åŸˆåŸ‡ï¨?  ï¨å¢žå¢²å¤‹å¥“å¥›å¥å¥£å¦¤å¦ºå­–å¯€ç”¯å¯˜å¯¬å°žå²¦å²ºå³µå´§åµ“ï¨‘åµ‚åµ­å¶¸å¶¹å·å¼¡å¼´å½§å¾·å¿žææ‚…æ‚Šæƒžæƒ•æ„ æƒ²æ„‘æ„·æ„°æ†˜æˆ“æŠ¦æµæ‘ æ’æ“Žæ•Žæ˜€æ˜•æ˜»æ˜‰æ˜®æ˜žæ˜¤æ™¥æ™—æ™™ï¨’æ™³æš™æš æš²æš¿æ›ºæœŽï¤©æ¦æž»æ¡’æŸ€æ æ¡„æ£ï¨“æ¥¨ï¨”æ¦˜æ§¢æ¨°æ©«æ©†æ©³æ©¾æ«¢æ«¤æ¯–æ°¿æ±œæ²†æ±¯æ³šæ´„æ¶‡æµ¯æ¶–æ¶¬æ·æ·¸æ·²æ·¼æ¸¹æ¹œæ¸§æ¸¼æº¿æ¾ˆæ¾µæ¿µç€…ç€‡ç€¨ç‚…ç‚«ç„ç„„ç…œç…†ç…‡ï¨•ç‡ç‡¾çŠ±?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  çŠ¾çŒ¤ï¨–ç·çŽ½ç‰ç–ç£ç’ç‡çµç¦çªç©ç®ç‘¢ç’‰ç’Ÿç”ç•¯çš‚çšœçšžçš›çš¦ï¨—ç†åŠ¯ç ¡ç¡Žç¡¤ç¡ºç¤°ï¨˜ï¨™ï¨šç¦”ï¨›ç¦›ç«‘ç«§ï¨œç««ç®žï¨çµˆçµœç¶·ç¶ ç·–ç¹’ç½‡ç¾¡ï¨žèŒè¢è¿è‡è¶è‘ˆè’´è•“è•™?  è•«ï¨Ÿè–°ï¨ ï¨¡è ‡è£µè¨’è¨·è©¹èª§èª¾è«Ÿï¨¢è«¶è­“è­¿è³°è³´è´’èµ¶ï¨£è»ï¨¤ï¨¥é§éƒžï¨¦é„•é„§é‡šé‡—é‡žé‡­é‡®é‡¤é‡¥éˆ†éˆéˆŠéˆºé‰€éˆ¼é‰Žé‰™é‰‘éˆ¹é‰§éŠ§é‰·é‰¸é‹§é‹—é‹™é‹ï¨§é‹•é‹ é‹“éŒ¥éŒ¡é‹»ï¨¨éŒžé‹¿éŒéŒ‚é°é—éŽ¤é†éžé¸é±é‘…é‘ˆé–’ï§œï¨©éšéš¯éœ³éœ»éƒééé‘é•é¡—é¡¥ï¨ªï¨«é¤§ï¨¬é¦žé©Žé«™é«œé­µé­²é®é®±é®»é°€éµ°éµ«ï¨­é¸™é»‘?  ?  â…°â…±â…²â…³â…´â…µâ…¶â…·â…¸â…¹ï¿¢ï¿¤ï¼‡ï¼‚?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  â…°â…±â…²â…³â…´â…µâ…¶â…·â…¸â…¹â… â…¡â…¢â…£â…¤â…¥â…¦â…§â…¨â…©ï¿¢ï¿¤ï¼‡ï¼‚ãˆ±â„–â„¡âˆµçºŠè¤œéˆéŠˆè“œä¿‰ç‚»æ˜±æ£ˆé‹¹æ›»å½…ä¸¨ä»¡ä»¼ä¼€ä¼ƒä¼¹ä½–ä¾’ä¾Šä¾šä¾”ä¿å€å€¢ä¿¿å€žå†å°å‚å‚”åƒ´åƒ˜å…Š?  å…¤å†å†¾å‡¬åˆ•åŠœåŠ¦å‹€å‹›åŒ€åŒ‡åŒ¤å²åŽ“åŽ²åï¨Žå’œå’Šå’©å“¿å–†å™å¥åž¬åŸˆåŸ‡ï¨ï¨å¢žå¢²å¤‹å¥“å¥›å¥å¥£å¦¤å¦ºå­–å¯€ç”¯å¯˜å¯¬å°žå²¦å²ºå³µå´§åµ“ï¨‘åµ‚åµ­å¶¸å¶¹å·å¼¡å¼´å½§å¾·å¿žææ‚…æ‚Šæƒžæƒ•æ„ æƒ²æ„‘æ„·æ„°æ†˜æˆ“æŠ¦æµæ‘ æ’æ“Žæ•Žæ˜€æ˜•æ˜»æ˜‰æ˜®æ˜žæ˜¤æ™¥æ™—æ™™ï¨’æ™³æš™æš æš²æš¿æ›ºæœŽï¤©æ¦æž»æ¡’æŸ€æ æ¡„æ£ï¨“æ¥¨ï¨”æ¦˜æ§¢æ¨°æ©«æ©†æ©³æ©¾æ«¢æ«¤æ¯–æ°¿æ±œæ²†æ±¯æ³šæ´„æ¶‡æµ¯?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  æ¶–æ¶¬æ·æ·¸æ·²æ·¼æ¸¹æ¹œæ¸§æ¸¼æº¿æ¾ˆæ¾µæ¿µç€…ç€‡ç€¨ç‚…ç‚«ç„ç„„ç…œç…†ç…‡ï¨•ç‡ç‡¾çŠ±çŠ¾çŒ¤ï¨–ç·çŽ½ç‰ç–ç£ç’ç‡çµç¦çªç©ç®ç‘¢ç’‰ç’Ÿç”ç•¯çš‚çšœçšžçš›çš¦ï¨—ç†åŠ¯ç ¡ç¡Žç¡¤ç¡ºç¤°ï¨˜ï¨™?  ï¨šç¦”ï¨›ç¦›ç«‘ç«§ï¨œç««ç®žï¨çµˆçµœç¶·ç¶ ç·–ç¹’ç½‡ç¾¡ï¨žèŒè¢è¿è‡è¶è‘ˆè’´è•“è•™è•«ï¨Ÿè–°ï¨ ï¨¡è ‡è£µè¨’è¨·è©¹èª§èª¾è«Ÿï¨¢è«¶è­“è­¿è³°è³´è´’èµ¶ï¨£è»ï¨¤ï¨¥é§éƒžï¨¦é„•é„§é‡šé‡—é‡žé‡­é‡®é‡¤é‡¥éˆ†éˆéˆŠéˆºé‰€éˆ¼é‰Žé‰™é‰‘éˆ¹é‰§éŠ§é‰·é‰¸é‹§é‹—é‹™é‹ï¨§é‹•é‹ é‹“éŒ¥éŒ¡é‹»ï¨¨éŒžé‹¿éŒéŒ‚é°é—éŽ¤é†éžé¸é±é‘…é‘ˆé–’ï§œï¨©éšéš¯éœ³éœ»éƒééé‘é•é¡—é¡¥ï¨ªï¨«é¤§ï¨¬é¦žé©Žé«™?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  é«œé­µé­²é®é®±é®»é°€éµ°éµ«ï¨­é¸™é»‘?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?  ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿¢Ÿó¿¢ ó¿¢¡ó¿¢¢ó¿¢£ó¿¢¤ó¿¢¥ó¿¢¦ó¿¢§ó¿¢¨ó¿¢©ó¿¢ªó¿¢«ó¿¢¬ó¿¢­ó¿¢®ó¿¢¯ó¿¢°ó¿¢±ó¿¢²ó¿¢³ó¿¢´ó¿¢µó¿¢¶ó¿¢·ó¿¢¸ó¿¢¹ó¿¢ºó¿¢»ó¿¢¼ó¿¢½ó¿¢¾ó¿¢¿ó¿£€ó¿£ó¿£‚ó¿£ƒó¿£„ó¿£…ó¿£†ó¿£‡ó¿£ˆó¿£‰ó¿£Šó¿£‹ó¿£Œó¿£ó¿£Žó¿£ó¿£ó¿£‘ó¿£’ó¿£“ó¿£”ó¿£•ó¿£–ó¿£—ó¿£˜ó¿£™ó¿£šó¿£›ó¿£œó¿£ó¿£žó¿£Ÿó¿£ ó¿£¡ó¿£¢ó¿££ó¿£¤ó¿£¥ó¿£¦ó¿£§ó¿£¨ó¿£©ó¿£ªó¿£«ó¿£¬ó¿£­ó¿£®ó¿£¯ó¿£°ó¿£±ó¿£²ó¿£³ó¿£´ó¿£µó¿£¶ó¿£·ó¿£¸ó¿£¹ó¿£ºó¿£»ó¿£¼?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿¥€ó¿¥ó¿¥‚ó¿¥ƒó¿¥„ó¿¥…ó¿¥†ó¿¥‡ó¿¥ˆó¿¥‰?   ?   ?   ?   ?   ?   ó¿¥ó¿¥‘ó¿¥’?   ?   ó¿¥•ó¿¥–ó¿¥—?   ?   ?   ó¿¥›ó¿¥œó¿¥ó¿¥ž?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿¥²ó¿¥³ó¿¥´ó¿¥µó¿¥¶ó¿¥·ó¿¥¸ó¿¥¹ó¿¥ºó¿¥»ó¿¥¼ó¿¥½ó¿¥¾?   ó¿¦€ó¿¦ó¿¦‚ó¿¦ƒó¿¦„ó¿¦…ó¿¦†ó¿¦‡ó¿¦ˆó¿¦‰ó¿¦Šó¿¦‹ó¿¦Œó¿¦ó¿¦Žó¿¦ó¿¦ó¿¦‘ó¿¦’ó¿¦“ó¿¦”ó¿¦•ó¿¦–ó¿¦—ó¿¦˜ó¿¦™ó¿¦šó¿¦›ó¿¦œó¿¦ó¿¦žó¿¦Ÿó¿¦ ó¿¦¡ó¿¦¢ó¿¦£ó¿¦¤ó¿¦¥ó¿¦¦ó¿¦§ó¿¦¨ó¿¦©ó¿¦ªó¿¦«ó¿¦¬ó¿¦­ó¿¦®ó¿¦¯ó¿¦°?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ùù‡ùˆù‰ùŠù‹ùŒùùŽù101112ù‡ùˆù‰ùŠù‹ùŒùùŽù10‰cZŒð‹x”NEÈŽwù†‚`“Á”é’´‹}”ƒ”„Å‘SŒn‘°? ? ? ? ? ? ? ? ùE? ø§ø¨ø©øªø«ø¬ø­ø®? ø¯? ø°ø±ø²ùF? ? ? ? ? ? ? ùHù? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øÀøÁø¼? ø¾øÃøÂ? ? øÐøËøÔ? øÓøÓøÒøÑøÐ? ? ? ø×øÊøÊ? øÚ? øØøÝ? ? ? ? ? ? ? ? ? ? ? ? ? ø´ø·ø¹ø¶øµø¸ø¸? øÍøÌ? øÐ? ? øÇ? ùœøÈ? ? ? øáøàøŸø ø¡ø¢ø£? ©¨? ù~? ? ? ? ? øôøõøöùž? ù‘ù”øîøð? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øñøïù©ù¨? ? ? ŒŒ? ù›? ? ? ? ? ? ? ? ? ? ? ? øúøÕ? ? ? ? ? øãøãøûøû? ? ø°øéøèøèø»ùt? ? ? ? ù^øâù øìøë? øÛ? øí? ùR? øêøä? ? ? øÆ? ùwùwù? ? øÄøÅ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ù£? ? ? ? ? ? ? ùQù}? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øßøæ? ? ? ø¡? ? ? ? ? ? ? ùV? ? ? ? ? ? ? øÓ? ? ? t‰ÄH“~? ù•ù—ù–? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ù…ù? ? ùù‡ùˆù‰ùŠù‹ùŒùùŽù10? ? ? ? ? ? ? ? ? ? ? ? ? ? ? {? ~€›? ? ? ? ? ? ? ? ? ù°NG“¾Š„‚‚‚‚ƒ‚„‚…‚†‚‡‚ˆ‚‰‚Š‚‹‚Œ‚‚Ž‚‚‚‘‚’‚“‚”‚•‚–‚—‚˜‚™‚š? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ‚`‚a‚b‚c‚d‚e‚f‚g‚h‚i‚j‚k‚l‚m‚n‚o‚p‚q‚r‚s‚t‚u‚v‚w‚x‚y‚Ÿ‚ ‚¡‚¢‚£‚¤‚¥‚¦‚§‚¨‚©‚ª‚«‚¬‚­‚®‚¯‚°‚±‚²‚³‚´‚µ‚¶‚·‚¸‚¹‚º‚»‚¼‚½‚¾‚¿‚À‚Á‚Â‚Ã? ‚Ä‚Å‚Æ‚Ç‚È‚É‚Ê‚Ë‚Ì‚Í‚Î‚Ï‚Ð‚Ñ‚Ò‚Ó‚Ô‚Õ‚Ö‚×‚Ø‚Ù‚Ú‚Û‚Ü‚Ý‚Þ‚ß‚à‚á‚â‚ã‚ä‚å‚æ‚ç‚è‚é‚ê‚ë‚í‚ð‚ñƒ@ƒAƒBƒCƒDƒEƒFƒGƒHƒIƒJƒKƒLƒMƒNƒOƒPƒQƒRƒSƒTƒUƒVƒWƒXƒYƒZƒ[ƒ\ƒ]ƒ^ƒ_ƒ`ƒaƒbƒcƒdƒeƒfƒgƒhƒiƒjƒkƒlƒmƒnƒoƒpƒqƒrƒsƒtƒuƒvƒwƒxƒyƒzƒ{ƒ|ƒ}ƒ~ƒ€ƒƒ‚ƒƒƒ„ƒ…ƒ†ƒ‡ƒˆƒ‰ƒŠƒ‹ƒŒƒƒƒ’ƒ“? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øùøù? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ø½ø¿ø¿? ùGøº? ? øÎ? ? ? øÉøÏøü? ø¤ø¦ùCùDùŸ? ? ? øÙø÷øøùIÌ? ? ? ù‚ù§? ? ? ? ù’ù„? ? ? ? ? ? ? ? ? ? ? ? ? ? ùw? ? ? ? ? ? ? ? ? ? ? ? ? øó? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ù§ù§Hù†©¨áâ? ? ùuøÒ? ? ø£? ? ? ? ? ? ? ? ? {|ùŸª«‹Ö¥£? ? ? ? ? ? ? ? øøø÷øŸø´ù^ùC? ? ? øîøÒ? ? ~? ? ? ? ø¢~? ©¨øÓ€? ù•ùŸøÙùI? ? ùEùW? ? ? ? ? ? ? øã? øè? ? £¥? øêøêøÑøâø¡? øä‹ÖøÎøäøäøä? ? ? øßø ùwøØ? øÄ? ? ? øû? ? ùù}øêøê? øÕø¿? ? ? ? ? ? ? ? ùE? ? ? ? ? ? ? øê? øæ? øÐøä? ùR? ùs? ? ? øè? ? ? ? ? øé? ? ? ? ùt? øÃùG? ? ø¼@  ? øàøáøü? ù‡ùˆù‰ùŠù‹ùŒùùŽù10ø¤ø¢ø§ø¨ø©øªø«ø¬ø­ø®ø¯ø°ø±ø²? øÉøËøÏøÍ? ? ? øÈøÌ? ? øÁø¾? ø·ø¶ø¸øºøÚ? ? øØ? ? ? ? ? øì? ùH? ? ? ? ? ? ? ? ? ? øÔ? ? ? ? ? ùF? ? ? ? ? ù•ù–ù—? ù¦ù¡ù¬? ù“ù”ùŸù£? ? ? ù‘ùž? ? øù? ”é? øôù­? ? “¾? ? øëø×? ù›? ? øÛ? ? ? Ezù{øí? ? UP? ø¥øµø¹? ? ? øÞøå? øïøðøñøòøóøõøöù@? ? ù€ùù°ù™ù‘? ù«? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øŸø ø¡ø¢ø£ø¤ø¥ø¦ø§ø¨ø©øªø«ø¬ø­ø®ø¯ø°ø±ø²ø³ø´øµø¶ø·ø¸ø¹øºø»ø¼ø½ø¾ø¿øÀøÁøÂøÃøÄøÅøÆøÇøÈøÉøÊøËøÌøÍøÎøÏøÐøÑøÒøÓøÔøÕøÖø×øØøÙøÚøÛøÜøÝøÞøßøàøáøâøãøäøåøæøçøèøéøêøëøìøíøîøïøðøñøòøóøôøõøöø÷øøøùøúøûøü? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ù@ùAùBùCùDùEùFùGùHùI? ? ? ? ? ? ùPùQùR? ? ùUùVùW? ? ? ù[ù\ù]ù^? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ùrùsùtùuùvùwùxùyùzù{ù|ù}ù~? ù€ùù‚ùƒù„ù…ù†ù‡ùˆù‰ùŠù‹ùŒùùŽùùù‘ù’ù“ù”ù•ù–ù—ù˜ù™ùšù›ùœùùžùŸù ù¡ù¢ù£ù¤ù¥ù¦ù§ù¨ù©ùªù«ù¬ù­ù®ù¯ù°? ? ? ? ? ? ø¸? ? ùQ? ùw? ùR? ? ? ? øÑ? ? ? ù¬ù¬ù–? ù”? ? ? ù•? ? ù—? NG? ? ? ? ”é? ? ù§‹Ö‹ó‡–žÌ? ? ? ? ? ? ? ? ? ? ? ? ? ? øÓ? ? ? ? ? ? ? ? ? ? øÒ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ùwùr? ù”? ù¬? ? ? ? ? ? ù ? ? øæ? ù? ? ? ? ? ? ? ? ? øã? øÔ? ? ùœøÚøßøí? ? øâøë? ? ? VSùQ? ? øº? ? ? ? ? ? ? ? ? ù¦ø£øÕùœøÏ? ? ? ? ? ? ? øä? ? ? ? øÈøÎøÍ? øÏ? øÆøÉøÇøË? øÊøÁø¿? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øê? ? ? ? ? ? ? øÏøÛøÓøÓjøà? ? ù£? ? øå”é? ? ? ? øÕøú? ? ? øÖøÖ? ? øãùP? ù›ù‘ù‘ù‘ù‘ù‘ù‘ù‘ùŸùŸù­ù«›~ù¡ùŸHù§øÑ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øÂ? ? ? ? ? øá? øü? øîøðøïøñù…ù„ù‚UP? ùzù{ŒŽ\? ? ? ù‡ùˆù‰ùŠù‹ùŒùùŽùù“¾Š„ƒTù|–ž‹óŽw‰c? ? ? ? ª«©¨øÙøøø÷ùI¨©âá? ø§ø¨ø©øªø«ø¬ø­ø®ø¯ø°ø±ø²? ? ù°? ? ? ? ù§? ‚i? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ù¬? ? ? ? ? ù˜? ? ? ? ? ? ? ? ? ? ? ? ? ? ù–? ? øò? øó? ? ? ? ? ? ? ? ? ? ? ? ? ? ø¹? ? ? øÀ? ? ? ? øÚø½ø¾? ? ? ? ? ? ø¦? ? ? ? ? ? ø¤? ? ? ? ? ? ? ùW? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ùž? ? ? øúøâøèøéùt? ù¢? ? øôøõøöø¸øµø¶ø´? ø·? ? ø¿ùGøÃø¼ø¾Hù§ù‘ù“? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ùH? ? øÄ? øÅ? øÌ? ø×øØù›ù}? ? ? øÐøÒøÑ? øÓø¢ø øŸø¡ùC? ? ùF? ? ùE? ? ? ù•ù•ù—ù–? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øØ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ùE? ? ? ? ? ? ? ‚`‚aAB‚nøù? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿¢Ÿó¿¢ ó¿¢¡ó¿¢¢ó¿¢£ó¿¢¤ó¿¢¥ó¿¢¦ó¿¢§ó¿¢¨ó¿¢©ó¿¢ªó¿¢«ó¿¢¬ó¿¢­ó¿¢®ó¿¢¯ó¿¢°ó¿¢±ó¿¢²ó¿¢³ó¿¢´ó¿¢µó¿¢¶ó¿¢·ó¿¢¸ó¿¢¹ó¿¢ºó¿¢»ó¿¢¼ó¿¢½ó¿¢¾ó¿¢¿ó¿£€ó¿£ó¿£‚ó¿£ƒó¿£„ó¿£…ó¿£†ó¿£‡ó¿£ˆó¿£‰ó¿£Šó¿£‹ó¿£Œó¿£ó¿£Žó¿£ó¿£ó¿£‘ó¿£’ó¿£“ó¿£”ó¿£•ó¿£–ó¿£—ó¿£˜ó¿£™ó¿£šó¿£›ó¿£œó¿£ó¿£žó¿£Ÿó¿£ ó¿£¡ó¿£¢ó¿££ó¿£¤ó¿£¥ó¿£¦ó¿£§ó¿£¨ó¿£©ó¿£ªó¿£«ó¿£¬ó¿£­ó¿£®ó¿£¯ó¿£°ó¿£±ó¿£²ó¿£³ó¿£´ó¿£µó¿£¶ó¿£·ó¿£¸ó¿£¹ó¿£ºó¿£»ó¿£¼?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿¥€ó¿¥ó¿¥‚ó¿¥ƒó¿¥„ó¿¥…ó¿¥†ó¿¥‡ó¿¥ˆó¿¥‰?   ?   ?   ?   ?   ?   ó¿¥ó¿¥‘ó¿¥’?   ?   ó¿¥•ó¿¥–ó¿¥—?   ?   ?   ó¿¥›ó¿¥œó¿¥ó¿¥ž?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿¥²ó¿¥³ó¿¥´ó¿¥µó¿¥¶ó¿¥·ó¿¥¸ó¿¥¹ó¿¥ºó¿¥»ó¿¥¼ó¿¥½ó¿¥¾?   ó¿¦€ó¿¦ó¿¦‚ó¿¦ƒó¿¦„ó¿¦…ó¿¦†ó¿¦‡ó¿¦ˆó¿¦‰ó¿¦Šó¿¦‹ó¿¦Œó¿¦ó¿¦Žó¿¦ó¿¦ó¿¦‘ó¿¦’ó¿¦“ó¿¦”ó¿¦•ó¿¦–ó¿¦—ó¿¦˜ó¿¦™ó¿¦šó¿¦›ó¿¦œó¿¦ó¿¦žó¿¦Ÿó¿¦ ó¿¦¡ó¿¦¢ó¿¦£ó¿¦¤ó¿¦¥ó¿¦¦ó¿¦§ó¿¦¨ó¿¦©ó¿¦ªó¿¦«ó¿¦¬ó¿¦­ó¿¦®ó¿¦¯ó¿¦°ó¿¦±ó¿¦²ó¿¦³ó¿¦´ó¿¦µó¿¦¶ó¿¦·ó¿¦¸ó¿¦¹ó¿¦ºó¿¦»ó¿¦¼ó¿¦½ó¿¦¾ó¿¦¿ó¿§€ó¿§ó¿§‚ó¿§ƒó¿§„ó¿§…ó¿§†ó¿§‡ó¿§ˆó¿§‰ó¿§Šó¿§‹ó¿§Œó¿§ó¿§Žó¿§ó¿§ó¿§‘ó¿§’ó¿§“ó¿§”ó¿§•ó¿§–ó¿§—ó¿§˜ó¿§™ó¿§šó¿§›ó¿§œó¿§ó¿§žó¿§Ÿó¿§ ó¿§¡ó¿§¢ó¿§£ó¿§¤ó¿§¥ó¿§¦ó¿§§ó¿§¨ó¿§©ó¿§ªó¿§«ó¿§¬ó¿§­ó¿§®ó¿§¯ó¿§°ó¿§±ó¿§²ó¿§³ó¿§´ó¿§µó¿§¶ó¿§·ó¿§¸ó¿§¹ó¿§ºó¿§»ó¿§¼?   ?   ?   ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ùù‡ùˆù‰ùŠù‹ùŒùùŽù101112ù‡ùˆù‰ùŠù‹ùŒùùŽù10‰cZŒð‹x”NEÈŽwù†‚`“ÁùÙ’´‹}”ƒ”„Å‘SŒn‘°? ? ? ? ? ùù? ? ùE? ø§ø¨ø©øªø«ø¬ø­ø®? ø¯? ø°ø±ø²ùF? ùöùö? ? ? ? ùHùùè? ùí? ? ùêùé? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øÀøÁø¼? ø¾øÃøÂùÂ? øÐøËøÔùñùðøÓøÒøÑøÐ? ? ? ø×øÊøÊ? øÚ? øØøÝ? ? ùå? ? ? ? ? ? ? ? ? ? ø´ø·ø¹ø¶øµø¸ù·? øÍøÌ? øÐ? ? øÇ? ùœøÈ? ? ùãøáøàøŸø ø¡ø¢ø£? ©¨ùâù~? ? ? ? ? øôøõøöùž? ù‘ù”øîøð? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øñøïù©ù¨? ? ? ŒŒ? ù›ùæ? ? ? ? ? ? ù³? ù¶? ? øúøÕ? ? ? ? ? øãøãøûøû? ùÀø°øéøèøèø»ùtù»ù»? ? ù^øâù øìøë? øÛ? øí? ù¾? øêøä? ? ùÕøÆ? ù¼ùwù? ? øÄøÅ? ? ? ? ù¹? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ù£? ? ? ? ? ù¿ùÀùºù}? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øßøæùµ? ? ø¡? ? ? ? ? ? ? ùV? ? ? ùï? ? ? øÓ? ? ? t‰ÄH“~ùÓùÏùÒù–? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ùØùØùØùØ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ù…ù? ? ùù‡ùˆù‰ùŠù‹ùŒùùŽù10? ? ? ? ? ? ? ? ? ? ? ? ? ? ? {? ~€›? ? ? ? ? ? ? ? ? ù°ùÔ“¾Š„‚‚‚‚ƒ‚„‚…‚†‚‡‚ˆ‚‰‚Š‚‹‚Œ‚‚Ž‚‚‚‘‚’‚“‚”‚•‚–‚—‚˜‚™‚š? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ‚`‚a‚b‚c‚d‚e‚f‚g‚h‚i‚j‚k‚l‚m‚n‚o‚p‚q‚r‚s‚t‚u‚v‚w‚x‚y‚Ÿ‚ ‚¡‚¢‚£‚¤‚¥‚¦‚§‚¨‚©‚ª‚«‚¬‚­‚®‚¯‚°‚±‚²‚³‚´‚µ‚¶‚·‚¸‚¹‚º‚»‚¼‚½‚¾‚¿‚À‚Á‚Â‚Ã? ‚Ä‚Å‚Æ‚Ç‚È‚É‚Ê‚Ë‚Ì‚Í‚Î‚Ï‚Ð‚Ñ‚Ò‚Ó‚Ô‚Õ‚Ö‚×‚Ø‚Ù‚Ú‚Û‚Ü‚Ý‚Þ‚ß‚à‚á‚â‚ã‚ä‚å‚æ‚ç‚è‚é‚ê‚ë‚í‚ð‚ñƒ@ƒAƒBƒCƒDƒEƒFƒGƒHƒIƒJƒKƒLƒMƒNƒOƒPƒQƒRƒSƒTƒUƒVƒWƒXƒYƒZƒ[ƒ\ƒ]ƒ^ƒ_ƒ`ƒaƒbƒcƒdƒeƒfƒgƒhƒiƒjƒkƒlƒmƒnƒoƒpƒqƒrƒsƒtƒuƒvƒwƒxƒyƒzƒ{ƒ|ƒ}ƒ~ƒ€ƒƒ‚ƒƒƒ„ƒ…ƒ†ƒ‡ƒˆƒ‰ƒŠƒ‹ƒŒƒƒƒ’ƒ“? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øùøù? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ø½ø¿ø¿? ùGøºùî? øÎ? ? ? øÉøÏøü? ø¤ø¦ùCùDùŸ? ? ? øÙø÷øøùIùá? ? ? ù‚ù§? ? ? ? ù’ù„? ? ? ? ? ? ? ? ? ? ? ? ? ? ùw? ? ? ? ? ? ? ? ? ? ? ? ? øó? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ùÜù§Hù†©¨áâ? ? ùuùû? ? ø£? ? ? ? ? ? ? ? ùÄ{|ùŸª«ùÝ¥£? ? ? ? ? ? ? ? øøø÷øŸø´ù^ùCù¸? ? øîøÒùëù×~? ùÁùÁ? ø¢~? ©¨øÓ€? ùÏùŸøÙùIùÀ? ùEùW? ? ùô? ? ùÖùÛøã? øè? ? £¥? øêøêøÑøâø¡? øäùÝøÎøäøäøä? ? ? øßø ùwøØ? øÄùè? ? øû? ? ùù}øêøê? øÕø¿? ? ? ? ? ? ? ùìùE? ? ? ? ? ? ? øêùÕøæ? øÐøä? ù¾? ùsù½? ? ñf? ? ? ? ? øé? ? ? ? ùt? øÃùG? ? ø¼@  ? øàøáøü? ù‡ùˆù‰ùŠù‹ùŒùùŽù10ø¤ø¢ø§ø¨ø©øªø«ø¬ø­ø®ø¯ø°ø±ø²? øÉøËøÏøÍ? ? ? øÈøÌ? ùÂøÁø¾? ø·ø¶ù·øºøÚ? ? øØ? ? ? ? ? øì? ùHùí? ? ? ùï? ùçùö? ùîøÔùö? ùù? ? ùFùõ? ùú? ? ùÏù–ùÒ? ù¦ù¡ù¬ùÍù“ù”ùŸù£? ? ? ù‘ùž? ? øù? ùÙ? øôù­? ? “¾? ùÌøëø×? ù›? ? øÛùµ? ? Ezù{øí? ? UP? ø¥øµø¹? ? ? øÞøå? øïøðøñøòøóøõøöù@? ? ù€ùù°ù™ù‘? ù«? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øŸø ø¡ø¢ø£ø¤ø¥ø¦ø§ø¨ø©øªø«ø¬ø­ø®ø¯ø°ø±ø²ø³ø´øµø¶ø·ø¸ø¹øºø»ø¼ø½ø¾ø¿øÀøÁøÂøÃøÄøÅøÆøÇøÈøÉøÊøËøÌøÍøÎøÏøÐøÑøÒøÓøÔøÕøÖø×øØøÙøÚøÛøÜøÝøÞøßøàøáøâøãøäøåøæøçøèøéøêøëøìøíøîøïøðøñøòøóøôøõøöø÷øøøùøúøûøü? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ù@ùAùBùCùDùEùFùGùHùI? ? ? ? ? ? ùPùQùR? ? ùUùVùW? ? ? ù[ù\ù]ù^? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ùrùsùtùuùvùwùxùyùzù{ù|ù}ù~? ù€ùù‚ùƒù„ù…ù†ù‡ùˆù‰ùŠù‹ùŒùùŽùùù‘ù’ù“ù”ùÏù–ùÒù˜ù™ùšù›ùœùùžùŸù ù¡ù¢ù£ù¤ù¥ù¦ù§ù¨ù©ùªù«ù¬ù­ù®ù¯ù°ù±ù²ù³ù´ùµù¶ù·ù¸ù¹ùºù»ù¼ù½ù¾ù¿ùÀùÁùÂùÃùÄùÅùÆùÇùÈùÉùÊùËùÌùÍùÎùÏùÐùÑùÒùÓùÔùÕùÖù×ùØùÙùÚùÛùÜùÝùÞùßùàùáùâùãùäùåùæùçùèùéùêùëùìùíùîùïùðùñùòùóùôùõùöù÷ùøùùùúùûùü? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ùwùrùÍùË? ùÇ? ? ùú? ? ù¿ù ùæ? øæ? ùùØ? ? ùì? ? ? ? ? øã? øÔ? ? ùœøÚøßøí? ? øâøë? ? ? VSùº? ? øº? ? ? ? ? ? ? ? ? ù¦ø£øÕùœøÏ? ? ? ? ? ? ? øä? ? ? ? øÈøÎøÍ? øÏ? øÆøÉøÇøËùãøÊøÁø¿? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øê? ? ùè? ? ? ? øÏøÛùðøÓjøà? ? ù£? ? øåùÙ? ? ? ? øÕøúùµ? ? øÖøÖ? ? øãùPù¸ù›ù‘ù‘ù‘ù‘ù‘ù‘ù‘ùŸùŸù­ù«›~ù¡ùŸHù§ùÃùò? ? ? ? ? ? ùñ? ùî? ? ùê? ? ? ? ? ? ? ùñ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øÂ? ? ? ? ? øá? øü? øîøðøïøñù…ù„ù‚UP? ùzù{ŒŽ\? ? ? ù‡ùˆù‰ùŠù‹ùŒùùŽùù“¾Š„ƒTù|ùàùÞŽw‰c? ? ? ? ª«©¨øÙøøø÷ùI¨©âá? ø§ø¨ø©øªø«ø¬ø­ø®ø¯ø°ø±ø²? ? ù°ùÖùÛ? ? ùÜ? ‚i? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ùÇ? ? ? ùÎùÐù˜ùÓ? ? ? ? ? ? ? ? ? ? ? ? ? ù–? ? øò? øó? ? ? ? ? ? ? ? ? ? ? ? ? ? ø¹? ? ? øÀ? ? ? ? øÚø½ø¾? ? ? ? ? ? ø¦? ùä? ? ? ? ø¤? ? ? ? ? ? ? ùW? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ùž? ? ù³øúøâøèøéùtù»ù¢ùÌ? øôøõøöø¸øµø¶ø´? ø·ùöùùø¿ùGøÃø¼ø¾Hù§ù‘ù“? ? ? ? ? ? ? ? ? ? ? ? ùí? ? ùHùÀùÀøÄù¿øÅ? øÌùåø×øØù›ù}? ? ? øÐøÒøÑùïøÓø¢ø øŸø¡ùC? ? ùF? ? ùE? ùöùõùÏùÏùÒù–? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? øØ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ùö? ùöùô? ? ? ùú? ? ùE? ? ? ? ? ? ? ‚`‚aAB‚nøùù×? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿¬¡ó¿¬¢ó¿¬£ó¿¬¤ó¿¬¥ó¿¬¦ó¿¬§ó¿¬¨ó¿¬©ó¿¬ªó¿¬«ó¿¬¬ó¿¬­ó¿¬®ó¿¬¯ó¿¬°ó¿¬±ó¿¬²ó¿¬³ó¿¬´ó¿¬µó¿¬¶ó¿¬·ó¿¬¸ó¿¬¹ó¿¬ºó¿¬»ó¿¬¼ó¿¬½ó¿¬¾ó¿¬¿ó¿­€ó¿­ó¿­‚ó¿­ƒó¿­„ó¿­…ó¿­†ó¿­‡ó¿­ˆó¿­‰ó¿­Šó¿­‹ó¿­Œó¿­ó¿­Žó¿­ó¿­ó¿­‘ó¿­’ó¿­“ó¿­”ó¿­•ó¿­–ó¿­—ó¿­˜ó¿­™ó¿­šó¿­›ó¿­œó¿­ó¿­žó¿­Ÿó¿­ ó¿­¡ó¿­¢ó¿­£ó¿­¤ó¿­¥ó¿­¦ó¿­§ó¿­¨ó¿­©ó¿­ªó¿­«ó¿­¬ó¿­­ó¿­®ó¿­¯ó¿­°ó¿­±ó¿­²ó¿­³ó¿­´ó¿­µó¿­¶ó¿­·ó¿­¸ó¿­¹ó¿­º?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿°¡ó¿°¢ó¿°£ó¿°¤ó¿°¥ó¿°¦ó¿°§ó¿°¨ó¿°©ó¿°ªó¿°«ó¿°¬ó¿°­ó¿°®ó¿°¯ó¿°°ó¿°±ó¿°²ó¿°³ó¿°´ó¿°µó¿°¶ó¿°·ó¿°¸ó¿°¹ó¿°ºó¿°»ó¿°¼ó¿°½ó¿°¾ó¿°¿ó¿±€ó¿±ó¿±‚ó¿±ƒó¿±„ó¿±…ó¿±†ó¿±‡ó¿±ˆó¿±‰ó¿±Šó¿±‹ó¿±Œó¿±ó¿±Žó¿±ó¿±ó¿±‘ó¿±’ó¿±“ó¿±”ó¿±•ó¿±–ó¿±—ó¿±˜ó¿±™ó¿±šó¿±›ó¿±œó¿±ó¿±žó¿±Ÿó¿± ó¿±¡ó¿±¢ó¿±£ó¿±¤ó¿±¥ó¿±¦ó¿±§ó¿±¨ó¿±©ó¿±ªó¿±«ó¿±¬ó¿±­ó¿±®ó¿±¯ó¿±°ó¿±±ó¿±²ó¿±³ó¿±´ó¿±µó¿±¶ó¿±·ó¿±¸ó¿±¹ó¿±º?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿´¡ó¿´¢ó¿´£ó¿´¤ó¿´¥ó¿´¦ó¿´§ó¿´¨ó¿´©ó¿´ªó¿´«ó¿´¬ó¿´­ó¿´®ó¿´¯ó¿´°ó¿´±ó¿´²ó¿´³ó¿´´ó¿´µó¿´¶ó¿´·ó¿´¸ó¿´¹ó¿´ºó¿´»ó¿´¼ó¿´½ó¿´¾ó¿´¿ó¿µ€ó¿µó¿µ‚ó¿µƒó¿µ„ó¿µ…ó¿µ†ó¿µ‡ó¿µˆó¿µ‰ó¿µŠó¿µ‹ó¿µŒó¿µó¿µŽó¿µó¿µó¿µ‘ó¿µ’ó¿µ“ó¿µ”ó¿µ•ó¿µ–ó¿µ—ó¿µ˜ó¿µ™ó¿µšó¿µ›ó¿µœó¿µó¿µžó¿µŸó¿µ ó¿µ¡ó¿µ¢ó¿µ£ó¿µ¤ó¿µ¥ó¿µ¦ó¿µ§ó¿µ¨ó¿µ©ó¿µªó¿µ«ó¿µ¬ó¿µ­ó¿µ®ó¿µ¯ó¿µ°ó¿µ±ó¿µ²ó¿µ³ó¿µ´ó¿µµó¿µ¶ó¿µ·ó¿µ¸ó¿µ¹ó¿µº?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $FE$F<$F=$F>$F?$F@$FA$FB$FC$FD10   11   12   $F<$F=$F>$F?$F@$FA$FB$FC$FD10   $FMZ   Œð   ‹x   ”N   E   È   $FL‚p   ‚`   “Á   ”é   ’´   ‹}   ”ƒ   ”„   Å   ‘S   Œn   ‘°   $Gs$Gp?    ?    ?    $G:$E)?    $Gr?    $F_$F`$Fa$Fb$Fc$Fd$Fe$Ff$Fk$Fg?    $Fh$Fi$Fj$Go?    $Gt$G9$E*?    ?    ?    $GS?    ?    ?    $GP$E9?    ?    ?    ?    ?    ?    ?    $G$$G%?    ?    $G!$G"$EZ?    ?    $E,$Gn$E:$Ez$Ey$G>$F!$G?$G=$F"?    ?    $Gc$Ev$E@?    $Gg$Gg$Gd$Ge$Gc?    ?    ?    $G\$Ex$Eg?    $ED?    $G]?    ?    ?    $G[?    ?    ?    $El$ES$EM$ET$EV$EU?    $G6$G8?    $G5$G4$G3$G3?    $Eo$GZ$Ep$Gc?    ?    $Eu$EA$EC$Em$Er?    $Ew$F(?    $Gj$Gi$Gk$Gh$E]?    $F[$FZ?    ?    ?    $FQ$FP$FO$FN$G0$G1$G2$G#$E<$GB$GB$F,$F-?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $F/$F.!!   !?   ?    ?    ?    ŒŒ   ?    $G^$E0?    ?    ?    $G&?    ?    $G&?    ?    ?    ?    $G'$E^?    ?    ?    ?    ?    $E>$E>?    ?    ?    $GT$G*$G*$G)$G)?    $G+$G,$G,?    ?    ?    $G($E/?    $EJ$EH$G^?    $EF$E-?    ?    $Eh$Eh?    ?    ?    $Es?    $E#$E#$E4?    ?    $GV$GX?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E3?    ?    ?    ?    ?    ?    $E.$GU$EO$G_$Ed?    $E6?    ?    ?    ?    ?    ?    ?    ?    ?    $Ga?    $Eb$EE$E2?    ?    ?    $Gk?    ?    ?    ?    ?    ?    ?    ?    $Gz?    ?    $Gf?    ?    ?    $Gg?    ?    ?    t   ‰Ä   H   “~   ?    $Gw$Gx$Gy?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E5$E5$E5$E5?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $F0$FE?    ?    $FE$F<$F=$F>$F?$F@$FA$FB$FC$FD10   ?    ?    ?    ?       ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    {   ?    ~   €   ›      ?    ?    ?    ?    ?    ?    ?    ?    ?    $FmNG   $FF$FG‚   ‚‚   ‚ƒ   ‚„   ‚…   ‚†   ‚‡   ‚ˆ   ‚‰   ‚Š   ‚‹   ‚Œ   ‚   ‚Ž   ‚   ‚   ‚‘   ‚’   ‚“   ‚”   ‚•   ‚–   ‚—   ‚˜   ‚™   ‚š   ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ‚`   ‚a   ‚b   ‚c   ‚d   ‚e   ‚f   ‚g   ‚h   ‚i   ‚j   ‚k   ‚l   ‚m   ‚n   ‚o   ‚p   ‚q   ‚r   ‚s   ‚t   ‚u   ‚v   ‚w   ‚x   ‚y   ‚Ÿ   ‚    ‚¡   ‚¢   ‚£   ‚¤   ‚¥   ‚¦   ‚§   ‚¨   ‚©   ‚ª   ‚«   ‚¬   ‚­   ‚®   ‚¯   ‚°   ‚±   ‚²   ‚³   ‚´   ‚µ   ‚¶   ‚·   ‚¸   ‚¹   ‚º   ‚»   ‚¼   ‚½   ‚¾   ‚¿   ‚À   ‚Á   ‚Â   ‚Ã   ?    ‚Ä   ‚Å   ‚Æ   ‚Ç   ‚È   ‚É   ‚Ê   ‚Ë   ‚Ì   ‚Í   ‚Î   ‚Ï   ‚Ð   ‚Ñ   ‚Ò   ‚Ó   ‚Ô   ‚Õ   ‚Ö   ‚×   ‚Ø   ‚Ù   ‚Ú   ‚Û   ‚Ü   ‚Ý   ‚Þ   ‚ß   ‚à   ‚á   ‚â   ‚ã   ‚ä   ‚å   ‚æ   ‚ç   ‚è   ‚é   ‚ê   ‚ë   ‚í   ‚ð   ‚ñ   ƒ@   ƒA   ƒB   ƒC   ƒD   ƒE   ƒF   ƒG   ƒH   ƒI   ƒJ   ƒK   ƒL   ƒM   ƒN   ƒO   ƒP   ƒQ   ƒR   ƒS   ƒT   ƒU   ƒV   ƒW   ƒX   ƒY   ƒZ   ƒ[   ƒ\   ƒ]   ƒ^   ƒ_   ƒ`   ƒa   ƒb   ƒc   ƒd   ƒe   ƒf   ƒg   ƒh   ƒi   ƒj   ƒk   ƒl   ƒm   ƒn   ƒo   ƒp   ƒq   ƒr   ƒs   ƒt   ƒu   ƒv   ƒw   ƒx   ƒy   ƒz   ƒ{   ƒ|   ƒ}   ƒ~   ƒ€   ƒ   ƒ‚   ƒƒ   ƒ„   ƒ…   ƒ†   ƒ‡   ƒˆ   ƒ‰   ƒŠ   ƒ‹   ƒŒ   ƒ   ƒ   ƒ’   ƒ“   ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $G$$G%?    ?    ?    $Ez$Ez?    $G<$ER?    ?    $En?    ?    ?    $Et$Eq$F*?    ?    ?    $Gl?    ™   ?    ?    ?    $FV$FX$FW$FYÌ   ?    ?    ?    $F2$GA?    ?    $F)?    $GB$F1?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E#?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $Fr$GA$G@‚p   $F[$FZ$F]$F\?    ?    ‚‰   $Gd$Eb   ?    $E]?    ?    ?    ?    ?    ?    ?    ?    ?    {   |   ™   $FR$FS‹Ö   ¥   £   ?    ?    ?    ?    ?    ?    ?    ?    $FW$FX$Gj$G6?    $Gl?    ?    $G"$F,$Gd?    ?    ~   ?    ?    ?    ?    $Gh~   ?    $FT$FU$Gg€   ?    $Gv™   $FV$FY$GU?    $Gr?    $E7$E7?    ?    $G!$Fn$Fo$E>?    $G)?    ?    £   ¥   ?    $Eh$Eh$Ge$G($Gk?    $Eh‹Ö   $En$Eh$Eh$Eh?    ?    ?    $EE$Gi$E#   $G]?    $GV?    ?    ?    ?    ?    ?    $E4$G_$Eh$Eh?    $E^$Ez?    ?    ?    $E!?    ?    ?    $E8$Gr?    ?    ?    $Ee?    $FP$FQ$Eh?    $E2?    $Gc$Eh?    ?    ?    $E#?    ?    ?    $G)?    ?    ?    ?    ?    $G*?    ?    ?    ?    $G+?    $G=$G<?    ?    $G>@        ?    ?    $F($F*$F)$F<$F=$F>$F?$F@$FA$FB$FC$FD10   ?    $Gh$F_$F`$Fa$Fb$Fc$Fd$Fe$Ff$Fg$Fh$Fi$Fj$Fk$Et$Ev$Eq$Eo$Ep$Ek?    $Em$GZ?    ?    $Ey$G??    $G8$G5$G3$ER$ED?    ?    $G]?    ?    ?    ?    $EP?    ?    $GS$GP$E;?    ?    $Gf?    ?    $G9?    ?    $E@$Gt?    $G:$E)?    $Go$Gu?    $E+?    ?    $Gw$Gy$Gx?    $E\$Gy$E($E%$GC$GB™   ?    $E=?    $El$GB$G#$E,?    ?    $E:   ”é   ?    $G0?    ?    ?    $FF$E<$G.$EJ$G\?    $G^$Ga?    $G^?    $E3?    $Ez$F6$EF?    ?    $F3$E[?    $G4?    ?    ?    ?    ?    ?    ?    $F.$F-$F/?    ?    $G1$G2?    ?    ?    ?    $FE$Fm?    $GB?    $E(?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $Gj$Gi$Gk$Gh$E]?    ?    ?    $F_$F`$Fa$Fb$Fc$Fd$Fe$Ff$Fg$Fh$Fi$Fj?    $G6$G4$G5$G8$G3?    $ER?    $G>?    $G?$Ez$Ez$Ey$F"$G=$GV$GX$Es$Eu$Em$Et$Ex$Ev$GZ$Eo$En$Eq$Gc$Ge$Gd$Gg$E@$E^?    $G\$G]$FV$ED$G^?    ?    ?    $EE?    $F($G($E>$Eh?    $E2$E2$G)$G*$Eh$EJ?    $EF$F,$F.$F-$F/?    ?    $G0$G1$G2$FX$FW?    $G'?    $F*?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $Gl?    $Gr$Go$G<$GS$FY?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $ON?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E$$E#$G+‚‰   ‚‰   $E#?    ?    $F5$F6$FI$G_?    ?    ?    $E4$F2?    $F1$F0‚p   $F<$F=$F>$F?$F@$FA$FB$FC$FD$FE$GB$GB$GC$GB$Gw$Gy$Gx$Gx?    $FV$G^$EC?    $G#™   $E/$Gy$G-?    ?    $FX$E\$GA!?   !!   ?    $E($E(?    `   `   $Fm?    ?    $G&?    ?    ?    $G3?    ?    $EO$G,$E#?    ?    $E.$GT?    ?    ÷e   ?    ?    ?    $E($E($Gy?    $E&$G.$E%?    $Gw?    ?    $Gx?    NG   ?    $Fn?    $E5”é   ?    $Fo$Fr‹Ö   $FK‡   $FJÌ   ?    $Ew?    $G[$E0?    ?    ?    ?    ?    $E8$GP?    $Gf$Gg?    ?    ?    ?    $Gu$G9?    ?    $G:$E+$Gd?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E!$E"$E#$E$$E%$E&$E'$E($E)$E*$E+$E,$E-$E.$E/$E0$E1$E2$E3$E4$E5$E6$E7$E8$E9$E:$E;$E<$E=$E>$E?$E@$EA$EB$EC$ED$EE$EF$EG$EH$EI$EJ$EK$EL$EM$EN$EO$EP$EQ$ER$ES$ET$EU$EV$EW$EX$EY$EZ$E[$E\$E]$E^$E_$E`$Ea$Eb$Ec$Ed$Ee$Ef$Eg$Eh$Ei$Ej$Ek$El$Em$En$Eo$Ep$Eq$Er$Es$Et$Eu$Ev$Ew$Ex$Ey$Ez?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $Eh?    ?    ?    ?    ?    ?    ?    $E`$G^$Gg$Ggj   ?    ?    ?    ?    ?    ?    ?    ”é   ?    $Eb?    ?    $E^$G'?    ?    ?    ?    ?    ?    ?    $E>?    ?    $G^$GB$GB$GB$GB$GB$GB$GB™   ™   ?    $E(›   ~   $Gy™   $G@$GA÷e   ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $F!$F"$F#$F$$F%$F&$F'$F($F)$F*$F+$F,$F-$F.$F/$F0$F1$F2$F3$F4$F5$F6$F7$F8$F9$F:$F;$F<$F=$F>$F?$F@$FA$FB$FC$FD$FE$FF$FG$FH$FI$FJ$FK$FL$FM$FN$FO$FP$FQ$FR$FS$FT$FU$FV$FW$FX$FY$FZ$F[$F\$F]$F^$F_$F`$Fa$Fb$Fc$Fd$Fe$Ff$Fg$Fh$Fi$Fj$Fk$Fl$Fm$Fn$Fo$Fp$Fq$Fr$Fs$Ft$Fu$Fv$Fw$Fx$Fy$Fz?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E(?    ?    ?    ?    ?    $Gx?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $Gy?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $Ez?    ?    ?    ?    $ED?    $G??    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E9?    $Gm$Ef?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $G!$G"$G#$G$$G%$G&$G'$G($G)$G*$G+$G,$G-$G.$G/$G0$G1$G2$G3$G4$G5$G6$G7$G8$G9$G:$G;$G<$G=$G>$G?$G@$GA$GB$GC$GD$GE$GF$GG$GH$GI$GJ$GK$GL$GM$GN$GO$GP$GQ$GR$GS$GT$GU$GV$GW$GX$GY$GZ$G[$G\$G]$G^$G_$G`$Ga$Gb$Gc$Gd$Ge$Gf$Gg$Gh$Gi$Gj$Gk$Gl$Gm$Gn$Go$Gp$Gq$Gr$Gs$Gt$Gu$Gv$Gw$Gx$Gy$Gz?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $G]?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $EZ?    ?    ?    ?    ?    $G9?    $G9?    ?    ?    ?    $E+$E)?    $Gr?    ?    ?    ?    ?    ?    ?    ‚`   ‚a   AB   ‚n   ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿®¡ó¿®¢ó¿®£ó¿®¤ó¿®¥ó¿®¦ó¿®§ó¿®¨ó¿®©ó¿®ªó¿®«ó¿®¬ó¿®­ó¿®®ó¿®¯ó¿®°ó¿®±ó¿®²ó¿®³ó¿®´ó¿®µó¿®¶ó¿®·ó¿®¸ó¿®¹ó¿®ºó¿®»ó¿®¼ó¿®½ó¿®¾ó¿®¿ó¿¯€ó¿¯ó¿¯‚ó¿¯ƒó¿¯„ó¿¯…ó¿¯†ó¿¯‡ó¿¯ˆó¿¯‰ó¿¯Šó¿¯‹ó¿¯Œó¿¯ó¿¯Žó¿¯ó¿¯ó¿¯‘ó¿¯’ó¿¯“ó¿¯”ó¿¯•ó¿¯–ó¿¯—ó¿¯˜ó¿¯™ó¿¯šó¿¯›ó¿¯œó¿¯ó¿¯žó¿¯Ÿó¿¯ ó¿¯¡ó¿¯¢ó¿¯£ó¿¯¤ó¿¯¥ó¿¯¦ó¿¯§ó¿¯¨ó¿¯©ó¿¯ªó¿¯«ó¿¯¬ó¿¯­?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿²¡ó¿²¢ó¿²£ó¿²¤ó¿²¥ó¿²¦ó¿²§ó¿²¨ó¿²©ó¿²ªó¿²«ó¿²¬ó¿²­ó¿²®ó¿²¯ó¿²°ó¿²±ó¿²²ó¿²³?   ?   ó¿²¶ó¿²·ó¿²¸ó¿²¹ó¿²ºó¿²»ó¿²¼ó¿²½ó¿²¾ó¿²¿ó¿³€ó¿³ó¿³‚ó¿³ƒó¿³„ó¿³…ó¿³†ó¿³‡ó¿³ˆó¿³‰ó¿³Šó¿³‹ó¿³Œó¿³ó¿³Žó¿³ó¿³ó¿³‘ó¿³’ó¿³“ó¿³”ó¿³•ó¿³–ó¿³—ó¿³˜ó¿³™ó¿³šó¿³›ó¿³œó¿³ó¿³žó¿³Ÿó¿³ ó¿³¡ó¿³¢ó¿³£ó¿³¤ó¿³¥ó¿³¦ó¿³§ó¿³¨ó¿³©ó¿³ªó¿³«ó¿³¬?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿¶¡ó¿¶¢ó¿¶£ó¿¶¤ó¿¶¥ó¿¶¦ó¿¶§ó¿¶¨ó¿¶©ó¿¶ªó¿¶«ó¿¶¬ó¿¶­ó¿¶®ó¿¶¯ó¿¶°ó¿¶±ó¿¶²ó¿¶³ó¿¶´ó¿¶µó¿¶¶ó¿¶·ó¿¶¸ó¿¶¹ó¿¶ºó¿¶»ó¿¶¼ó¿¶½ó¿¶¾ó¿¶¿ó¿·€ó¿·ó¿·‚ó¿·ƒó¿·„ó¿·…ó¿·†ó¿·‡ó¿·ˆó¿·‰ó¿·Šó¿·‹ó¿·Œó¿·ó¿·Žó¿·ó¿·ó¿·‘ó¿·’ó¿·“ó¿·”ó¿·•ó¿·–ó¿·—ó¿·˜ó¿·™?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $FE$F<$F=$F>$F?$F@$FA$FB$FC$FD10   11   12   $F<$F=$F>$F?$F@$FA$FB$FC$FD10   $FMZ   Œð   ‹x   ”N   E   È   $FL‚p   ‚`   “Á   $O5’´   ‹}   ”ƒ   ”„   Å   ‘S   Œn   ‘°   $Gs$Gp$QL?    $QM$G:$E)$QN$Gr$QO$F_$F`$Fa$Fb$Fc$Fd$Fe$Ff$Fk$Fg?    $Fh$Fi$Fj$Go$QF$Gt$Q@$E*?    ?    ?    $GS?    $O$$O%$GP$Pg$Of$Oe?    $Og?    ?    ?    $G$$G%?    ?    $G!$G"$Q:?    $Ph$E,$Gn$E:$PN$Ey$G>$F!$PU$G=$F"?    ?    $Gc$Ev$E@$O`$O+$Gg$Gd$Ge$Gc?    $Od?    $G\$Ex$Eg?    $ED?    $Q'?    ?    ?    $G[?    ?    ?    $El$ES$EM$ET$EV$EU?    $G6$G8$PJ$G5$G4$G3$G3?    $Eo$GZ$Ep$Gc?    ?    $Eu$EA$EC$Em$Er?    $Ew$F($O.$Gj$Gi$Gk$Gh$E]?    $F[$FZ?    ?    ?    $FQ$FP$FO$FN$G0$G1$G2$G#$E<$GB$GB$F,$F-?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $F/$F.!!   !?   ?    ?    ?    ŒŒ   ?    $G^$E0$QE$PY?    $G&?    ?    $G&?    ?    ?    ?    $G'$E^?    $O"$O8$Q#$O8$E>$OC?    ?    ?    $GT$G*$G*$G)$G)?    $G+$G,$G,?    ?    ?    $G($E/?    $EJ$EH$O*?    $EF$E-?    ?    $O!$Eh?    $O3?    $Es?    $E#$E#$E4?    ?    $GV$GX$P]$Q&?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E3$O1?    ?    ?    ?    ?    $E.$GU$EO$G_$Ed?    $E6?    ?    ?    $OZ?    ?    ?    ?    ?    $Ga?    $O7$EE$E2$O<?    ?    $Gk?    ?    $O]?    ?    ?    ?    ?    $Gz?    ?    $Gf?    ?    ?    $O,?    $O2?    t   ‰Ä   H   “~   $P($P5$Gx$P6?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E5$E5$E5$E5?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $F0$FE?    ?    $FE$F<$F=$F>$F?$F@$FA$FB$FC$FD10   ?    ?    ?    ?       ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    {   ?    ~   €   $OR   ?    ?    ?    ?    ?    ?    ?    ?    ?    $FmNG   $FF$FG‚   ‚‚   ‚ƒ   ‚„   ‚…   ‚†   ‚‡   ‚ˆ   ‚‰   ‚Š   ‚‹   ‚Œ   ‚   ‚Ž   ‚   ‚   ‚‘   ‚’   ‚“   ‚”   ‚•   ‚–   ‚—   ‚˜   ‚™   ‚š   ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ‚`   ‚a   ‚b   ‚c   ‚d   ‚e   ‚f   ‚g   ‚h   ‚i   ‚j   ‚k   ‚l   ‚m   ‚n   ‚o   ‚p   ‚q   ‚r   ‚s   ‚t   ‚u   ‚v   ‚w   ‚x   ‚y   ‚Ÿ   ‚    ‚¡   ‚¢   ‚£   ‚¤   ‚¥   ‚¦   ‚§   ‚¨   ‚©   ‚ª   ‚«   ‚¬   ‚­   ‚®   ‚¯   ‚°   ‚±   ‚²   ‚³   ‚´   ‚µ   ‚¶   ‚·   ‚¸   ‚¹   ‚º   ‚»   ‚¼   ‚½   ‚¾   ‚¿   ‚À   ‚Á   ‚Â   ‚Ã   ?    ‚Ä   ‚Å   ‚Æ   ‚Ç   ‚È   ‚É   ‚Ê   ‚Ë   ‚Ì   ‚Í   ‚Î   ‚Ï   ‚Ð   ‚Ñ   ‚Ò   ‚Ó   ‚Ô   ‚Õ   ‚Ö   ‚×   ‚Ø   ‚Ù   ‚Ú   ‚Û   ‚Ü   ‚Ý   ‚Þ   ‚ß   ‚à   ‚á   ‚â   ‚ã   ‚ä   ‚å   ‚æ   ‚ç   ‚è   ‚é   ‚ê   ‚ë   ‚í   ‚ð   ‚ñ   ƒ@   ƒA   ƒB   ƒC   ƒD   ƒE   ƒF   ƒG   ƒH   ƒI   ƒJ   ƒK   ƒL   ƒM   ƒN   ƒO   ƒP   ƒQ   ƒR   ƒS   ƒT   ƒU   ƒV   ƒW   ƒX   ƒY   ƒZ   ƒ[   ƒ\   ƒ]   ƒ^   ƒ_   ƒ`   ƒa   ƒb   ƒc   ƒd   ƒe   ƒf   ƒg   ƒh   ƒi   ƒj   ƒk   ƒl   ƒm   ƒn   ƒo   ƒp   ƒq   ƒr   ƒs   ƒt   ƒu   ƒv   ƒw   ƒx   ƒy   ƒz   ƒ{   ƒ|   ƒ}   ƒ~   ƒ€   ƒ   ƒ‚   ƒƒ   ƒ„   ƒ…   ƒ†   ƒ‡   ƒˆ   ƒ‰   ƒŠ   ƒ‹   ƒŒ   ƒ   ƒ   ƒ’   ƒ“   ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $QV$QV?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $QQ?    ?    ?    $G$$G%?    ?    $PT$Ez$Ez?    $G<$ER$Ob?    $En?    ?    ?    $Et$O)$F*?    $Pc$P\$Gl?    $OO?    ?    ?    $FV$FX$FW$FYÌ   ?    ?    ?    $F2$OW?    ?    $F)?    $GB$F1?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E#?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $P;?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $Fr$OW$OV‚p   $F[$FZ$F]$F\?    ?    ‚‰   $Gd$O7   ?    $E]?    ?    ?    ?    ?    ?    ?    ?    ?    {   |   $OO$FR$FS‹Ö   ¥   £   ?    ?    ?    ?    ?    ?    ?    ?    $FW$FX$Gj$G6?    $Gl$OE?    $G"$F,$Gd?    $QW~   ?    ?    ?    ?    $Gh$OS?    $FT$FU$Gg€   ?    $P4$OO$FV$FY$GU?    $Gr$Pk$E7$E7$QC?    $G!$Fn$Fo$OC?    $G)?    ?    £   ¥   $Q,$O!$O!$Ge$G($Gk$PK$Eh‹Ö   $En$Eh$Eh$Eh?    $O3?    $EE$Gi$E#   $Q'?    $GV$O$?    ?    ?    ?    ?    $E4$G_$O!$O!?    $O:$Ez?    ?    ?    $E!?    ?    ?    $E8$QJ?    ?    ?    $Ee?    $FP$FQ$O!?    $E2?    $Gc$Eh$PO?    ?    $E#?    ?    ?    $G)?    ?    ?    ?    ?    $G*?    ?    ?    ?    $G+?    $G=$G<?    ?    $G>@        ?    $O.$F($F*$F)$F<$F=$F>$F?$F@$FA$FB$FC$FD10   $Pc$Gh$F_$F`$Fa$Fb$Fc$Fd$Fe$Ff$Fg$Fh$Fi$Fj$Fk$Et$Ev$O)$Eo$Ep$Ek?    $Em$GZ?    ?    $Ey$PU?    $G8$G5$G3$ER$ED?    ?    $Q'?    $Q)?    ?    $EP?    ?    $GS$GP$E;$Q+$Oh$Gf?    ?    $G9$Og$Ob$E@$Gt$QL$G:$E)$QQ$Go$Gu?    $E+$O'$O%$P5$P6$Gx$Q:$E\$OT$E($E%$GC$GB$OO$O1$E=?    $El$OI$G#$E,?    $QV$E:   $O5?    $G0$OP?    ?    $FF$E<$G.$EJ$G\?    $G^$Ga?    $O*$O<$E3$O>$Ez$F6$EF$O9?    $F3$E[?    $G4$PJ?    ?    ?    ?    $O4$Ok$F.$F-$F/$P9$P;$G1$G2?    ?    ?    ?    $FE$Fm?    $GB?    $OQ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $Gj$Gi$Gk$Gh$E]$Pc?    $P\$F_$F`$Fa$Fb$Fc$Fd$Fe$Ff$Fg$Fh$Fi$Fj?    $G6$G4$G5$G8$G3$PJ$ER?    $G>$PT$PU$Ez$PN$Ey$F"$G=$GV$GX$Es$Eu$Em$Et$Ex$Ev$GZ$Eo$En$O)$Gc$Ge$Gd$Gg$E@$E^$O?$G\$Q'$FV$ED$O*?    ?    ?    $EE$O.$F($G($OC$Eh$O4$E2$E2$G)$G*$O!$EJ?    $EF$F,$F.$F-$F/$P9$P;$G0$G1$G2$FX$FW$QV$G'?    $F*?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $Gl?    $Gr$Go$G<$GS$FY?    ?    ?    ?    ?    ?    $OD?    ?    ?    ?    ?    ?    $Pk?    ?    ?    ?    $ON?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E$$E#$G+‚‰   ‚‰   $E#?    ?    $F5$F6$FI$G_?    ?    ?    $E4$F2?    $F1$F0‚p   $F<$F=$F>$F?$F@$FA$FB$FC$FD$FE$GB$GB$GC$GB$P5$P6$Gx$P'?    $FV$G^$EC?    $G#$ON$E/$OT$G-$O1?    $FX$E\$OW!?   !!   ?    $OQ$E($OP`   `   $Fm?    ?    $G&?    $O<?    $G3$OE?    $EO$G,$E#?    ?    $E.$GT?    ?    $OX?    ?    ?    $P!$P!$Gy?    $E&$G.$E%$P%$P5$P&?    $Gx$P(NG   ?    $Fn$QW$E5$O5?    $Fo$Fr‹Ö   $FK‡   $FJÌ   ?    $Ew$P^$G[$E0?    $O$?    $Oe?    $E8$GP$Ob$Gf$O+$Om$OY?    $QC$Gu$G9?    ?    $G:$E+$Gd?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $E!$E"$E#$E$$E%$E&$E'$P!$E)$E*$E+$E,$E-$E.$E/$E0$E1$E2$E3$E4$E5$E6$E7$E8$Pg$E:$E;$E<$E=$E>$E?$E@$EA$EB$EC$ED$EE$EF$EG$EH$EI$EJ$EK$EL$EM$EN$EO$EP$EQ$ER$ES$ET$EU$EV$EW$EX$EY$Q:$E[$E\$E]$E^$E_$O)$Ea$O7$Ec$Ed$Ee$Pj$Eg$Eh$Ei$Ej$Ek$El$Em$En$Eo$Ep$O)$Er$Es$Et$Eu$Ev$Ew$Ex$Ey$Ez?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $O!$O"$O#$O$$O%$O&$O'$O($O)$O*$O+$O,$O-$O.$O/$O0$O1$O2$O3$O4$O5$O6$O7$O8$O9$O:$O;$O<$O=$O>$O?$O@$OA$OB$OC$OD$OE$OF$OG$OH$OI$OJ$OK$OL$OM$ON$OO$OP$OQ$OR$OS$OT$OU$OV$OW$OX$OY$OZ$O[$O\$O]$O^$O_$O`$Oa$Ob$Oc$Od$Oe$Of$Og$Oh$Oi$Oj$Ok$Ol$Om?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $F!$F"$F#$F$$F%$F&$F'$F($F)$F*$F+$F,$F-$F.$F/$F0$F1$F2$F3$F4$F5$F6$F7$F8$F9$F:$F;$F<$F=$F>$F?$F@$FA$FB$FC$FD$FE$FF$FG$FH$FI$FJ$FK$FL$FM$FN$FO$FP$FQ$FR$FS$FT$FU$FV$FW$FX$FY$FZ$F[$F\$F]$F^$F_$F`$Fa$Fb$Fc$Fd$Fe$Ff$Fg$Fh$Fi$Fj$Fk$Fl$Fm$Fn$Fo$Fp$Fq$Fr$Fs$Ft$Fu$Fv$Fw$Fx$Fy$Fz?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $P!$P"$P#$P$$P%$P&$P'$P($P)$P*$P+$P,$P-$P.$P/$P0$P1$P2$P3?    ?    $P6$P7$P8$P9$P:$P;$P<$P=$P>$P?$P@$PA$PB$PC$PD$PE$PF$PG$PH$PI$PJ$PK$PL$PM$PN$PO$PP$PQ$PR$PS$PT$PU$PV$PW$PX$PY$PZ$P[$P\$P]$P^$P_$P`$Pa$Pb$Pc$Pd$Pe$Pf$Pg$Ph$Pi$Pj$Pk$Pl?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $G!$G"$G#$G$$G%$G&$G'$G($G)$G*$G+$G,$G-$G.$G/$G0$G1$G2$G3$G4$G5$G6$G7$G8$G9$G:$G;$G<$G=$G>$PU$OV$OW$GB$GC$GD$GE$GF$GG$GH$GI$GJ$GK$GL$GM$GN$GO$GP$GQ$GR$GS$GT$GU$GV$GW$GX$GY$GZ$G[$G\$Q'$G^$G_$G`$Ga$Gb$Gc$Gd$Ge$Gf$Gg$Gh$Gi$Gj$Gk$Gl$Pi$Gn$Go$Gp$Gq$Gr$Gs$Gt$Gu$P4$P5$Gx$P6$Gz?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    $Q!$Q"$Q#$Q$$Q%$Q&$Q'$Q($Q)$Q*$Q+$Q,$Q-$Q.$Q/$Q0$Q1$Q2$Q3$Q4$Q5$Q6$Q7$Q8$Q9$Q:$Q;$Q<$Q=$Q>$Q?$Q@$QA$QB$QC$QD$QE$QF$QG$QH$QI$QJ$QK$QL$QM$QN$QO$QP$QQ$QR$QS$QT$QU$QV$QW$QX$QY?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?    ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿€ó¿ó¿‚ó¿ƒó¿„ó¿…ó¿†ó¿‡ó¿ˆó¿‰ó¿Šó¿‹ó¿Œó¿ó¿Žó¿ó¿ó¿‘ó¿’ó¿“ó¿”ó¿•ó¿–ó¿—ó¿˜ó¿™ó¿šó¿›ó¿œó¿ó¿žó¿Ÿó¿ ó¿¡ó¿¢ó¿£ó¿¤ó¿¥ó¿¦ó¿§ó¿¨ó¿©ó¿ªó¿«ó¿¬ó¿­ó¿®ó¿¯ó¿°ó¿±ó¿²ó¿³ó¿´ó¿µó¿¶ó¿·ó¿¸ó¿¹ó¿ºó¿»ó¿¼ó¿½ó¿¾?   ó¿‚€ó¿‚ó¿‚‚ó¿‚ƒó¿‚„ó¿‚…ó¿‚†ó¿‚‡ó¿‚ˆó¿‚‰ó¿‚Šó¿‚‹ó¿‚Œó¿‚ó¿‚Žó¿‚ó¿‚ó¿‚‘ó¿‚’ó¿‚“ó¿‚”ó¿‚•ó¿‚–ó¿‚—ó¿‚˜ó¿‚™ó¿‚šó¿‚›ó¿‚œó¿‚ó¿‚žó¿‚Ÿó¿‚ ó¿‚¡ó¿‚¢ó¿‚£ó¿‚¤ó¿‚¥ó¿‚¦ó¿‚§ó¿‚¨ó¿‚©ó¿‚ªó¿‚«ó¿‚¬ó¿‚­ó¿‚®ó¿‚¯ó¿‚°ó¿‚±ó¿‚²ó¿‚³ó¿‚´ó¿‚µó¿‚¶ó¿‚·ó¿‚¸ó¿‚¹ó¿‚ºó¿‚»ó¿‚¼ó¿‚½ó¿‚¾ó¿‚¿ó¿ƒ€ó¿ƒó¿ƒ‚ó¿ƒƒó¿ƒ„ó¿ƒ…ó¿ƒ†ó¿ƒ‡ó¿ƒˆó¿ƒ‰ó¿ƒŠó¿ƒ‹ó¿ƒŒó¿ƒó¿ƒŽó¿ƒó¿ƒó¿ƒ‘ó¿ƒ’ó¿ƒ“ó¿ƒ”ó¿ƒ•ó¿ƒ–ó¿ƒ—ó¿ƒ˜ó¿ƒ™ó¿ƒšó¿ƒ›ó¿ƒœó¿ƒó¿ƒžó¿ƒŸó¿ƒ ó¿ƒ¡ó¿ƒ¢ó¿ƒ£ó¿ƒ¤ó¿ƒ¥ó¿ƒ¦ó¿ƒ§ó¿ƒ¨ó¿ƒ©ó¿ƒªó¿ƒ«ó¿ƒ¬ó¿ƒ­ó¿ƒ®ó¿ƒ¯ó¿ƒ°ó¿ƒ±ó¿ƒ²ó¿ƒ³ó¿ƒ´ó¿ƒµó¿ƒ¶ó¿ƒ·ó¿ƒ¸ó¿ƒ¹ó¿ƒºó¿ƒ»ó¿ƒ¼?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿…€ó¿…ó¿…‚ó¿…ƒó¿…„ó¿……ó¿…†ó¿…‡ó¿…ˆó¿…‰ó¿…Šó¿…‹ó¿…Œó¿…ó¿…Žó¿…ó¿…ó¿…‘ó¿…’ó¿…“ó¿…”ó¿…•ó¿…–ó¿…—ó¿…˜ó¿…™ó¿…šó¿…›ó¿…œó¿…ó¿…žó¿…Ÿó¿… ó¿…¡ó¿…¢ó¿…£ó¿…¤ó¿…¥ó¿…¦ó¿…§ó¿…¨ó¿…©ó¿…ªó¿…«ó¿…¬ó¿…­ó¿…®ó¿…¯ó¿…°ó¿…±ó¿…²ó¿…³ó¿…´ó¿…µó¿…¶ó¿…·ó¿…¸ó¿…¹ó¿…ºó¿…»ó¿…¼ó¿…½ó¿…¾?   ó¿†€ó¿†ó¿†‚ó¿†ƒó¿†„ó¿†…ó¿††ó¿†‡ó¿†ˆó¿†‰ó¿†Šó¿†‹ó¿†Œó¿†ó¿†Žó¿†ó¿†ó¿†‘ó¿†’ó¿†“ó¿†”ó¿†•ó¿†–ó¿†—ó¿†˜ó¿†™ó¿†šó¿†›ó¿†œó¿†ó¿†žó¿†Ÿó¿† ó¿†¡ó¿†¢ó¿†£ó¿†¤ó¿†¥ó¿†¦ó¿†§ó¿†¨ó¿†©ó¿†ªó¿†«ó¿†¬ó¿†­ó¿†®ó¿†¯ó¿†°ó¿†±ó¿†²ó¿†³ó¿†´ó¿†µó¿†¶ó¿†·ó¿†¸ó¿†¹ó¿†ºó¿†»ó¿†¼ó¿†½ó¿†¾ó¿†¿ó¿‡€ó¿‡ó¿‡‚ó¿‡ƒó¿‡„ó¿‡…ó¿‡†ó¿‡‡ó¿‡ˆó¿‡‰ó¿‡Šó¿‡‹ó¿‡Œó¿‡ó¿‡Žó¿‡ó¿‡ó¿‡‘ó¿‡’ó¿‡“ó¿‡”ó¿‡•ó¿‡–?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿‰€ó¿‰ó¿‰‚ó¿‰ƒó¿‰„ó¿‰…ó¿‰†ó¿‰‡ó¿‰ˆó¿‰‰ó¿‰Šó¿‰‹ó¿‰Œó¿‰ó¿‰Žó¿‰ó¿‰ó¿‰‘ó¿‰’ó¿‰“ó¿‰”ó¿‰•ó¿‰–ó¿‰—ó¿‰˜ó¿‰™ó¿‰šó¿‰›ó¿‰œó¿‰ó¿‰žó¿‰Ÿó¿‰ ó¿‰¡ó¿‰¢ó¿‰£ó¿‰¤ó¿‰¥ó¿‰¦ó¿‰§ó¿‰¨ó¿‰©ó¿‰ªó¿‰«ó¿‰¬ó¿‰­ó¿‰®ó¿‰¯ó¿‰°ó¿‰±ó¿‰²ó¿‰³ó¿‰´ó¿‰µó¿‰¶ó¿‰·ó¿‰¸ó¿‰¹ó¿‰ºó¿‰»ó¿‰¼ó¿‰½ó¿‰¾?   ó¿Š€ó¿Šó¿Š‚ó¿Šƒó¿Š„ó¿Š…ó¿Š†ó¿Š‡ó¿Šˆó¿Š‰ó¿ŠŠó¿Š‹ó¿ŠŒó¿Šó¿ŠŽó¿Šó¿Šó¿Š‘ó¿Š’ó¿Š“ó¿Š”ó¿Š•ó¿Š–ó¿Š—ó¿Š˜ó¿Š™ó¿Ššó¿Š›ó¿Šœó¿Šó¿Šžó¿ŠŸó¿Š ó¿Š¡ó¿Š¢ó¿Š£ó¿Š¤ó¿Š¥ó¿Š¦ó¿Š§ó¿Š¨ó¿Š©ó¿Šªó¿Š«?   ?   ?   ?   ó¿Š°ó¿Š±ó¿Š²ó¿Š³ó¿Š´ó¿Šµó¿Š¶ó¿Š·ó¿Š¸ó¿Š¹ó¿Šºó¿Š»ó¿Š¼ó¿Š½ó¿Š¾ó¿Š¿ó¿‹€ó¿‹ó¿‹‚ó¿‹ƒó¿‹„ó¿‹…ó¿‹†ó¿‹‡ó¿‹ˆó¿‹‰ó¿‹Šó¿‹‹ó¿‹Œó¿‹ó¿‹Žó¿‹ó¿‹ó¿‹‘ó¿‹’ó¿‹“ó¿‹”ó¿‹•?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿‹Ÿó¿‹ ó¿‹¡ó¿‹¢ó¿‹£ó¿‹¤ó¿‹¥ó¿‹¦ó¿‹§ó¿‹¨ó¿‹©ó¿‹ªó¿‹«ó¿‹¬ó¿‹­ó¿‹®ó¿‹¯ó¿‹°ó¿‹±ó¿‹²ó¿‹³ó¿‹´ó¿‹µó¿‹¶ó¿‹·ó¿‹¸ó¿‹¹ó¿‹ºó¿‹»ó¿‹¼?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿€ó¿ó¿‚ó¿ƒó¿„ó¿…ó¿†ó¿‡ó¿ˆó¿‰ó¿Šó¿‹ó¿Œó¿ó¿Žó¿ó¿ó¿‘ó¿’ó¿“ó¿”ó¿•ó¿–ó¿—ó¿˜ó¿™ó¿šó¿›ó¿œó¿ó¿žó¿Ÿó¿ ó¿¡ó¿¢ó¿£ó¿¤ó¿¥ó¿¦ó¿§ó¿¨ó¿©ó¿ªó¿«ó¿¬ó¿­ó¿®ó¿¯ó¿°ó¿±ó¿²ó¿³ó¿´ó¿µó¿¶ó¿·ó¿¸ó¿¹ó¿ºó¿»ó¿¼ó¿½ó¿¾?   ó¿Ž€ó¿Žó¿Ž‚ó¿Žƒó¿Ž„ó¿Ž…ó¿Ž†ó¿Ž‡ó¿Žˆó¿Ž‰ó¿ŽŠó¿Ž‹ó¿ŽŒó¿Žó¿ŽŽó¿Žó¿Žó¿Ž‘ó¿Ž’ó¿Ž“ó¿Ž”ó¿Ž•ó¿Ž–ó¿Ž—ó¿Ž˜ó¿Ž™ó¿Žšó¿Ž›ó¿Žœó¿Žó¿Žžó¿ŽŸó¿Ž ó¿Ž¡ó¿Ž¢ó¿Ž£ó¿Ž¤ó¿Ž¥ó¿Ž¦ó¿Ž§ó¿Ž¨ó¿Ž©ó¿Žªó¿Ž«ó¿Ž¬ó¿Ž­ó¿Ž®ó¿Ž¯ó¿Ž°ó¿Ž±ó¿Ž²ó¿Ž³ó¿Ž´ó¿Žµó¿Ž¶ó¿Ž·ó¿Ž¸ó¿Ž¹ó¿Žºó¿Ž»ó¿Ž¼ó¿Ž½ó¿Ž¾ó¿Ž¿ó¿€ó¿ó¿‚ó¿ƒó¿„ó¿…ó¿†ó¿‡ó¿ˆó¿‰ó¿Šó¿‹ó¿Œó¿ó¿Žó¿ó¿ó¿‘ó¿’ó¿“ó¿”ó¿•ó¿–ó¿—ó¿˜ó¿™ó¿šó¿›ó¿œó¿ó¿žó¿Ÿó¿ ó¿¡ó¿¢ó¿£ó¿¤ó¿¥ó¿¦ó¿§ó¿¨ó¿©ó¿ªó¿«ó¿¬ó¿­ó¿®ó¿¯ó¿°ó¿±ó¿²ó¿³ó¿´ó¿µó¿¶ó¿·ó¿¸ó¿¹ó¿º?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿‘€ó¿‘ó¿‘‚ó¿‘ƒó¿‘„ó¿‘…ó¿‘†ó¿‘‡ó¿‘ˆó¿‘‰ó¿‘Šó¿‘‹ó¿‘Œó¿‘ó¿‘Žó¿‘?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ó¿’€?   ?   ?   ó¿’„ó¿’…ó¿’†ó¿’‡ó¿’ˆó¿’‰ó¿’Š?   ó¿’Œó¿’ó¿’Ž?   ó¿’?   ?   ?   ó¿’”ó¿’•ó¿’–?   ó¿’˜ó¿’™ó¿’šó¿’›ó¿’œ?   ?   ?   ó¿’ ó¿’¡ó¿’¢ó¿’£ó¿’¤?   ?   ?   ó¿’¨ó¿’©ó¿’ªó¿’«ó¿’¬ó¿’­ó¿’®ó¿’¯?   ?   ?   ?   ó¿’´ó¿’µ?   ?   ?   ?   ?   ?   ó¿’¼ó¿’½ó¿’¾?   ?   ?   ?   ?   ó¿“„ó¿“…?   ?   ó¿“ˆ?   ?   ?   ó¿“Œ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ?   ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ð@ðAðBðCðDðEðFðGðHðIðJðKðLðMðNðOðPðQðRðSðTðUðVðWðXðYðZð[ð\ð]ð^ð_ð`ðaðbðcðdðeðfðgðhðiðjðkðlðmðnðoðpðqðrðsðtðuðvðwðxðyðzð{ð|ð}ð~? ð€ðð‚ðƒð„ð…ð†ð‡ðˆð‰ðŠð‹ðŒððŽððð‘ð’ð“ð”ð•ð–ð—ð˜ð™ðšð›ðœððžðŸð ð¡ð¢ð£ð¤ð¥ð¦ð§ð¨ð©ðªð«ð¬ð­ð®ð¯ð°ð±ð²ð³ð´ðµð¶ð·ð¸ð¹ðºð»ð¼ð½ð¾ð¿ðÀðÁðÂðÃðÄðÅðÆðÇðÈðÉðÊðËðÌðÍðÎðÏðÐðÑðÒðÓðÔðÕðÖð×ðØðÙðÚðÛðÜðÝðÞðßðàðáðâðãðäðåðæðçðèðéðêðëðìðíðîðïðððñðòðóðôðõðöð÷ðøðùðúðûðü? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ñ@ñAñBñCñDñEñFñGñHñIñJñKñLñMñNñOñPñQñRñSñTñUñVñWñXñYñZñ[ñ\ñ]ñ^ñ_ñ`ñañbñcñdñeñfñgñhñiñjñkñlñmñnñoñpñqñrñsñtñuñvñwñxñyñzñ{ñ|ñ}ñ~? ñ€ññ‚ñƒñ„ñ…ñ†ñ‡ñˆñ‰ñŠñ‹ñŒññŽñññ‘ñ’ñ“ñ”ñ•ñ–ñ—ñ˜ñ™ñšñ›ñœññžñŸñ ñ¡ñ¢ñ£ñ¤ñ¥ñ¦ñ§ñ¨ñ©ñªñ«ñ¬ñ­ñ®ñ¯ñ°ñ±ñ²ñ³ñ´ñµñ¶ñ·ñ¸ñ¹ñºñ»ñ¼ñ½ñ¾ñ¿ñÀñÁñÂñÃñÄñÅñÆñÇñÈñÉñÊñËñÌñÍñÎñÏñÐñÑñÒñÓñÔñÕñÖ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ò@òAòBòCòDòEòFòGòHòIòJòKòLòMòNòOòPòQòRòSòTòUòVòWòXòYòZò[ò\ò]ò^ò_ò`òaòbòcòdòeòfògòhòiòjòkòlòmònòoòpòqòròsòtòuòvòwòxòyòzò{ò|ò}ò~? ò€òò‚òƒò„ò…ò†ò‡òˆò‰òŠò‹òŒòòŽòòò‘ò’ò“ò”ò•ò–ò—ò˜ò™òšò›òœòòžòŸò ò¡ò¢ò£ò¤ò¥ò¦ò§ò¨ò©òªò«? ? ? ? ò°ò±ò²ò³ò´òµò¶ò·ò¸ò¹òºò»ò¼ò½ò¾ò¿òÀòÁòÂòÃòÄòÅòÆòÇòÈòÉòÊòËòÌòÍòÎòÏòÐòÑòÒòÓòÔòÕ? ? ? ? ? ? ? ? ? òßòàòáòâòãòäòåòæòçòèòéòêòëòìòíòîòïòðòñòòòóòôòõòöò÷òøòùòúòûòü? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ó@óAóBóCóDóEóFóGóHóIóJóKóLóMóNóOóPóQóRóSóTóUóVóWóXóYóZó[ó\ó]ó^ó_ó`óaóbócódóeófógóhóiójókólómónóoópóqórósótóuóvówóxóyózó{ó|ó}ó~? ó€óó‚óƒó„ó…ó†ó‡óˆó‰óŠó‹óŒóóŽóóó‘ó’ó“ó”ó•ó–ó—ó˜ó™óšó›óœóóžóŸó ó¡ó¢ó£ó¤ó¥ó¦ó§ó¨ó©óªó«ó¬ó­ó®ó¯ó°ó±ó²ó³ó´óµó¶ó·ó¸ó¹óºó»ó¼ó½ó¾ó¿óÀóÁóÂóÃóÄóÅóÆóÇóÈóÉóÊóËóÌóÍóÎóÏóÐóÑóÒóÓóÔóÕóÖó×óØóÙóÚóÛóÜóÝóÞóßóàóáóâóãóäóåóæóçóèóéóêóëóìóíóîóïóðóñóòóóóôóõóöó÷óøóùóú? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ô@ôAôBôCôDôEôFôGôHôIôJôKôLôMôNôO? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ô€? ? ? ô„ô…ô†ô‡ôˆô‰ôŠ? ôŒôôŽ? ô? ? ? ô”ô•ô–? ô˜ô™ôšô›ôœ? ? ? ô ô¡ô¢ô£ô¤? ? ? ô¨ô©ôªô«ô¬ô­ô®ô¯? ? ? ? ô´ôµ? ? ? ? ? ? ô¼ô½ô¾? ? ? ? ? ôÄôÅ? ? ôÈ? ? ? ôÌ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ô©ô©Hð_ðëðìáâ? ? ‚‰ð³ñ´òÄ? ðé? ? ? ? ? ? ? ? ? òÐ|Oœª«‹Ö¥£? ? ? ? ? ? ? ? ô¢ô¡ðåðÎñmôš? ñ„ððûð³? ? òÒô¼? ? ? ðè~ô½©¨ð²òÓñƒñÓôœô ô£ñ£? ðsôœ? ? ? ? ðœ? ? ñ^? ñe? ñ³£¥? ñyñyð´ñnñº? ñz‹Öôñzñzñzô¼ñ|ñƒñµðæñòÕð¿? ñ…ð? ? ñ`? ? ñ‚ñ¥ñyñyñ©ñWô‰? ôªô«? ? ? ? ? ðsñk? ñ„ñ¦? ðñððñyñ}ñ¶? ðµñz? ñw? ñ? ? ? ñe? ñ{ñ{? ñ°ñdôµ? ? ? ñh? ð©ôŒ? ? ð¦@  ? ðäðãô–ô¬ðMðNðOðPðQðRðSðTðUðVô˜ðèðuðvðwðxðyðzð{ð|ð~ð€ðð‚ð}ô”ð®ô•ðÖðØ? ðÚðßð×? ð«ð¥ð¨? ðÏðÑðÔôð½? ? ð¿ðÅ? ? ? ? ñp? ð‹ð? ? ? ñÆ? ? ð†ð”ôŽð¯ð…ðmðpðqô€ðƒ? ? ? ? ðŽñÓñÕñÔðž? ñÕ? ? ? ðúOœñœ? ñDðÇðùð÷ð¡? ôEð£ðb? ðô? ? ? òáðø? ñqð¹? ñIñ²? ñsñ·ñ›? Ez? ñu? ? UP? ? ðÒðÐ? ? ? ? ? ? ñAðüñ@? ôÌðõðö? ? ? ? ò²òß? ðù? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ðåðæñºðèðéô˜? ô™ðuðvðwðxðyðzð{ð|ð~ð€ðð‚? ðÎðÒðÑðÏðÓðÐôñgð¦ôˆð¨ô‰ð¤ð¥ðªð©ñ…ñ†ñ~ðÜðßô”ðºð®ð×ðÖôô•ðµð´ð³ð²ð¯ñW? ð¹ð¿ô ð½ñs? ðÀ? ñµðäðãñnñ^ñz? ñ¶ñ¶ñeñdñyñqñpñuðûñAðüñ@? ôÌðôðõðöô¡ô¢ôEñVñ`ô–? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ôšô›ðsðƒôŒð‹ô£? ? ? ? ? ? ? ? ñw? ? ? ñÂôœ? ? ? ? ON? ñm? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ñcññh‚‰‚‰ñ? ? ? IDñ¥ðî? ? ñ‚ô¨? ô¯ò±ð_ò¶ò·ò¸ò¹òºò»ò¼ò½ò¾òµðùô®? ðúñÓñÕñÔ? ? ô ñIðÞðŒð÷ôœñoñÕðôñœ? ô¡? ô©ñCñB? ? ? ? ``òß? ? ñO? ñ·ñSðÔ? ñ‹ñ¤ñiñ€? ñwñ¢ñb? ð«ð´? ? ? ? ? ñÕ? ðú? ? ? ñÓ? ? ñÔñÒòàñ}? ? òLðb? ? ô©‹Ö‹ó‡–žô¤ðíðâ? ðÃñJ? ðð“ð’? ? ðôŽñÆð±? ? ? ? ? ð†? ? ðp? ð³? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ññc? ðú? ? ðqð‡? ð¡ñvñ¢ñoñJð÷ñ¶ñ›ñ‚òLñ¨? ? ðð£? ðø? ñ^? ð¯ðÝ? ðÞð½ñµñu? ñrñnñq? ? ðÉVSñ¤? ? ôðÈðÊðÌðË? ? ? ðž? ? ðéñWðÞô•ñ´ñ´? ñ¦ñ¦? ? ñz? ? ? ðÇðßôðÖðØô•ðàñ~ô”ðÜð®ðâðºð¥ôŠ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ñyñY? ððŽ? ? ? ô•ñsð±ñÊjðä? ? ñœñÌñ|? ðb? ñ´ñZ? ñWñVñ·? ? ? ? ? ? ñ^? ? ñIðùðùðùðùðùðùðùôœôœ? ? òÔ~ñÕOœHô©ð´? ñ¬? ? ñ½? ? ð°? ôŽ? ð·ð’ð‘ð”? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ð§ðª? ? ? ? ? ðãô¬ô–? ðûðüñAñ@ò±ô¯ô¨UP? ? ŒŽ\? ? ? ðMðNðOðPðQðRðSðTðUò²òáòâƒTID–ž‹óð^ðWðóðòðñððª«©¨ô ô¢ô¡ô£ðìðëâá? ðuðvðwðxðyðzð{ð|ð~ð€ðð‚ð}? òß? ? ? ? ô©? ‚i? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ñÒ? ? ? ? ? ? ? ? ? ? ? ? ? ñÕ? ? ? ? ôÌ? ? ? ? ? ? ? ? ? ? ? ? ? ? ðÐ? ? ? ð¤? ? ? ? ð½ôˆð¨? ? ? ñL? ? ô™ñ‡? ? ? ? ? ô˜? ? ? ðð ? ? ôœ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ðœðð÷ð˜ð™ñOñVñnñeñdñhñiðô? ? ðôðõðöðÓðÒðÑðÎ? ðÏð†ðpð¤ôŒð©ð¦ð¨Hô©ðù? ? ? ? ? ? ? ? ? ? ? ? ? ð? ? ð‹ñbñ£ñ…ñ¢ñ†? ð×ðÃð¹ð¿ñIñ¥? ñ²? ðµð³ð´ñÆð²ðèðæðåñºôš? ð¢ðƒðl? ðsðkð…? ñÓñÓñÔñÕñÃ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ñ[? ? ñˆð¿? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ðž? ? ? ? ? ð†? ð†? ? ñKð„? ðq? ðs? ðmðoðrðt? ô€‚`‚aAB‚nôE? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? 