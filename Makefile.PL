
package Unicode::Japanese::MakeMaker;

use strict;
use ExtUtils::Manifest;
use ExtUtils::MakeMaker;

my $MANIFEST_bak = $ExtUtils::Manifest::MANIFEST;

my %argv = map{ /^(\w+)=(.*)$/ } @ARGV;

my $useXS; # 0:PurePerl,1:useXS,undef:not specified

unlink(qw(medaite.h mediate.c));

# --------------------------------------------------------------------
# create default parameter
my %param = (
    'NAME'		=> 'Unicode::Japanese',
    'VERSION_FROM'	=> 'Japanese.pm', # finds $VERSION
    'ABSTRACT_FROM'     => 'Japanese.pm', #
    'AUTHOR'		=> 'SANO Taku (SAWATARI Mikage) and YAMASHINA Hio',

    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
    'PL_FILES'          => {},

    'CONFIGURE'         => \&configure,	 
  );
my %param_xs = (
    'PM'=>{'Japanese/u2s-s2u.dat'=>'$(INST_LIBDIR)/Japanese/u2s-s2u.dat',
	   'Japanese/emoji.dat'=>'$(INST_LIBDIR)/Japanese/emoji.dat',
	   'Japanese.pm'=>'$(INST_LIBDIR)/Japanese.pm',
	  },
    'CCFLAGS' => '-Wall',
    'OBJECT' => join(' ',qw( Japanese.o memmap.o conv.o ucs2_utf8.o
			     getcode.o getcode_map.o sjis.o eucjp.o jis.o
			     sjis_imode.o sjis_jsky.o sjis_doti.o
			     mediate.o 
			     ) ),
    'XS' => {'Japanese.xs'=>'Japanese.c',},
    'XSOPT'=>'-C++',
    'XSPROTOARG'=>'-noprototypes',

    'LIBS'		=> [''], # e.g., '-lm'
    'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
    'INC'		=> '', # e.g., '-I/usr/include/other'

    'clean'    => { FILES => 'mediate.{c,h}' },
  );

# --------------------------------------------------------------------
# check devel mode.
if( ! -e 'devel.PL' )
{
  # for Release.
  add_ccflags('-DNDEBUG');
}else
{
  # for Development Environment.
  print "for devel.\n";
  if( open DEVEL_PL,'devel.PL' )
  {
    my $code = join('',<DEVEL_PL>);
    eval $code;
    if( $@ )
    {
      die "'devel.PL' failed : $@";
    }
    close DEVEL_PL;
  }
  print " >> (devel mode) CCFLAGS = '$param_xs{'CCFLAGS'}'\n";
}

# --------------------------------------------------------------------
# check 'PurePerl'or'NoXS' from @ARGV, and remove if exists.
my @arg;
@ARGV = grep{ !(@arg-push(@arg,/^(PurePerl|NoXS)(=(0|1|yes|no|y|n))?$/i)) } @ARGV;
if( @arg )
{
  my $v = $arg[1] ? $arg[2] : '1';
  if( $v eq '1' || $v eq 'y' || $v eq 'yes' )
  {
    print "install with PurePerl mode\n";
    disableXS();
  }
}

# --------------------------------------------------------------------
# run MakerMaker :: WriteMakefile

WriteMakefile(%param);

$ExtUtils::Manifest::MANIFEST = $MANIFEST_bak;


# --------------------------------------------------------------------
# follows are subroutins only.

sub configure
{
  print "**** CONFIGURE ****\n";
  if( $] < 5.006 )
  {
    add_ccflags('-DUNIJP__PERL_OLDER_THAN_5_006');
  }
  if( $] < 5.005 )
  {
    add_ccflags('-DUNIJP__PERL_OLDER_THAN_5_005');
  }

  if( !defined($useXS) )
  {
    print " >> no hints ran ?\n";
    enableXS('(no hints)',undef,undef);
  }

  if( $useXS )
  {
    # compile check.
    use Config;
    use ExtUtils::Embed;
    my $cc = exists $argv{CC} ? $argv{CC} : $Config{cc};
    my $ccopts = ExtUtils::Embed::ccopts();
    my $xstest_src = $^O eq 'MSWin32' ? 'memmap_win32.c' : 'memmap.c';
    my $xstest_out = $^O eq 'MSWin32' ? 'memmap_win32.obj' : 'memmap.o';
    my $cmd = "$cc $ccopts -c $xstest_src -o $xstest_out";
    print "Checking XS Compiling... : $cmd\n";
    my $rc = 0xffff & system($cmd);
    unlink($xstest_out);
    if( $rc )
    {
      if( $rc == 0xffff )
      {
	print " >> Here environment cannot use XS.\n";
	print " >> Because : command failed : $!\n";
	return disableXS();
      }elsif( $rc > 0x80 )
      {
        print " >> Here environment cannot use XS.\n";
	print " >> Because : ran with non-zero exit status $rc\n";
	return disableXS();
      }elsif( $rc & 0x80 )
      {
	$rc &= ~0x80;
	print " >> Compile failed..\n";
	print " >> Because : ran with coredump from signal $rc\n";
	exit 1;
      }else
      {
        print " >> Compile failed..\n";
        print " >> Because : ran with signal $rc\n";
	exit 1;
      }
    }
    print " >> ok, test succeed.\n";
  }else
  {
    print "skip xs compile test\n";
  }
  
  \%param_xs;
}

sub disableXS
{
  print " >> disableXS...\n";
  $useXS = 0;  
  $ExtUtils::Manifest::MANIFEST = 'MANIFEST.noxs';
  $param{linkext} = { 'LINKTYPE'=>'' };
  %param_xs = ('linkext'=>{'LINKTYPE'=>''});
  \%param_xs;
}

sub enableXS
{
  my $type = shift;
  my $hdr  = shift || "/* nothing is needed. */\n";
  my $cpp  = shift || "/* nothing is needed. */\n";

  if( $type eq 'MSWin32' )
  {
    $param_xs{'OBJECT'} =~ s/\bmemmap.o\b/memmap_win32.o/;
  }

  !defined($useXS) and $useXS = 1;
  print " >> enableXS...\n";
  $useXS or print " >> but XS was disabled previously... (keep disabled)\n";
  $hdr = "/* from hints/$type.pl */\n\n".$hdr;
  $cpp = "/* from hints/$type.pl */\n\n".$cpp;

  use FileHandle;
  my $fh_hdr = new FileHandle('>mediate.h');
  my $fh_cpp = new FileHandle('>mediate.c');
  if( !$fh_hdr || !$fh_cpp )
  {
    die 'cannot open mediate.h or .c for output';
  }
  
  # write out 'mediate.h'
  print $fh_hdr <<EOF;
#ifndef MEDIATE_H__
#define MEDIATE_H__

/* This file was auto-generated by Makefile.PL */

$hdr

#endif
EOF

  # write out 'mediate.c'
  print $fh_cpp <<EOF;

/* This file was auto-generated by Makefile.PL */

$cpp;
EOF
  
  $fh_hdr->close();
  $fh_cpp->close();
  
  \%param_xs;
}

# --------------------------------------------------------------------
# misc.

sub add_ccflags
{
  $param_xs{'CCFLAGS'} = join(' ',$param_xs{'CCFLAGS'},@_);  
}

sub include_test
{
  $param_xs{'CCFLAGS'} .= '-g -DTEST=1';
  $param_xs{'OBJECT'}  .= ' test.o';
}
