## ----------------------------------------------------------------------------
# Makefile.PL
# -----------------------------------------------------------------------------
# Makefile.PL for Unicode-Japanese.
# -----------------------------------------------------------------------------
# $Id: Makefile.PL,v 1.58 2007/09/03 07:47:19 hio Exp $
# -----------------------------------------------------------------------------
package Unicode::Japanese::MakeMaker;

use strict;
use ExtUtils::Manifest;
use ExtUtils::MakeMaker;
use ExtUtils::Embed;
use File::Spec;
use inc::ExtUtils::MY_Metafile qw(my_metafile);

my $MANIFEST_bak = $ExtUtils::Manifest::MANIFEST;

my %argv = map{ /^(\w+)=(.*)$/ } @ARGV;

my $useXS; # 0:PurePerl,1:useXS,undef:not specified

unlink(qw(medaite.h mediate.c));

# --------------------------------------------------------------------
# create default parameter
my %param = (
    'NAME'		=> 'Unicode::Japanese',
    'VERSION_FROM'	=> 'lib/Unicode/Japanese.pm', # finds $VERSION
    'ABSTRACT_FROM'     => 'lib/Unicode/Japanese.pm', #
    'AUTHOR'		=> 'SANO Taku (SAWATARI Mikage) and YAMASHINA Hio',

    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
    'PL_FILES'          => {},
    'EXE_FILES'         => ['bin/ujconv','bin/ujguess',],

    'CONFIGURE'         => \&configure,	 
    'clean'    => { FILES => 't/pureperl.flag mediate.c mediate.h' },
  );
my %param_xs = (
    'OBJECT' => join(' ',qw( Japanese.o memmap_common.o memmap_unix.o
                             conv.o ucs2_utf8.o utf8.o
			     getcode.o getcode_map.o sjis.o eucjp.o jis.o
			     sjis_imode1.o sjis_imode2.o sjis_jsky1.o sjis_jsky2.o sjis_doti.o utf16.o
			     mediate.o 
			     ) ),
    'XS' => {'Japanese.xs'=>'Japanese.c',},
    'XSOPT'=>'-C++',
    'XSPROTOARG'=>'-noprototypes',

    'LIBS'		=> [''], # e.g., '-lm'
    'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
    'INC'		=> '', # e.g., '-I/usr/include/other'
  );
my @CCFLAGS;

# --------------------------------------------------------------------
# add CCFLAGS
#add_ccflags('-Wall');

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
#   and hints, configure().

print " >> invoke WriteMakefile\n";
my_metafile 'Unicode::Japanese' => {
	requires => {},
	build_requires => {
		'Test'       => 0,
		'Test::More' => 0,
	},
	license => 'Perl',
};
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
    print " >> no hints ran (maybe no info on this platform [$^O])\n";
    enableXS('(no hints)',undef,undef);
  }
  
  flush_ccflags();
  if( $useXS )
  {
    # compile check.
    use Config;
    use ExtUtils::Embed;
    my $cc = exists $argv{CC} ? $argv{CC} : $Config{cc};
    my $ccopts = exists $argv{CCFLAGS} ? $argv{CCFLAGS} : exists $param_xs{CCFLAGS} ? $param_xs{CCFLAGS} : ExtUtils::Embed::ccopts();
    
    my $xstest_src = $^O eq 'MSWin32' ? 'memmap_win32.c' : 'memmap_unix.c';
    my $xstest_out = $^O eq 'MSWin32' ? 'memmap_win32.obj' : 'memmap_unix.o';
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
    
    my %SIZES;
    print "check word sizes...\n";
    {
      my $exe_ext = $^O eq 'MSWin32' ? '.exe' : '';
      $xstest_src = 'wordsize.c';
      ($xstest_out = $xstest_src) =~ s/\.c$/$exe_ext/;
      $cmd = "$cc $ccopts $xstest_src -o $xstest_out";
      print "compile... : $cmd\n";
      my $rc = 0xffff & system($cmd);
      if( $rc==-1 )
      {
        print " >> compile failed: $!\n";
        return disableXS();
      }
      if( $rc!=0 )
      {
        print " >> compile failed, exit status is: $rc\n";
        return disableXS();
      }
      $cmd = File::Spec->catfile(".",$xstest_out);
      my @list  = `$cmd`;
      if( $? )
      {
        print " >> check execute failed, is: $?\n";
        return disableXS();
      }
      foreach(@list)
      {
        chomp;
        /^(.*?) = (\d+)/ or next;
        $SIZES{$1} = $2;
      }
    }
    foreach(qw(short int long void*))
    {
      $SIZES{$_} ||= 0;
    }
    my $int32 = $SIZES{int}*8==32 ? 'int' : 'long';
    my $int16 = $SIZES{int}*8==16 ? 'int' : 'short';
    my $int8  = 'char';
    $param_xs{DEFINE} .= qq| -DUJ_UINT32="unsigned $int32"|;
    $param_xs{DEFINE} .= qq| -DUJ_UINT16="unsigned $int16"|;
    $param_xs{DEFINE} .= qq| -DUJ_UINT8="unsigned $int8"|;
    $param_xs{DEFINE} =~s/^ //;
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
  %param_xs = ('linkext'=>{'LINKTYPE'=>''},
              );
  if( !-e "t/pureperl.flag" )
  {
    if( open(FILE,">t/pureperl.flag") )
    {
      close(FILE);
    }else
    {
      print "could not create file [t/pureperl.flag] : $!\n";
    }
  }
  \%param_xs;
}

sub enableXS
{
  my $type = shift;
  my $hdr  = shift || "/* nothing is needed. */\n";
  my $cpp  = shift;
  my $cpp_on = $cpp && 1;
  if( !$cpp_on )
  {
    $cpp = "/* nothing is needed, and will not be compiled. */\n";
  }

  if( $type eq 'MSWin32' )
  {
    $param_xs{'OBJECT'} =~ s/\bmemmap_unix.o\b/memmap_win32.o/;
    $param_xs{'PM'} and delete @{$param_xs{'PM'}}{qw(Japanese/u2s-s2u.dat Japanese/emoji.dat)};
  }

  !defined($useXS) and $useXS = 1;
  print " >> enableXS...\n";
  $useXS or print " >> but XS was disabled previously... (keep disabled)\n";
  $hdr = "/* from hints/$type.pl */\n\n".$hdr;
  $cpp = "/* from hints/$type.pl */\n\n".$cpp;

  print " >> write mediate.c, mediate.h\n";
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

$cpp
EOF
  
  $fh_hdr->close();
  $fh_cpp->close();
  
  if( $useXS && -e "t/pureperl.flag" )
  {
    unlink("t/pureperl.flag") or print "could not unlink file [t/pureperl.flag] : $!\n";
  }
  
  $cpp_on or $param_xs{OBJECT} =~ s/\bmediate.o\b//;
  \%param_xs;
}

# --------------------------------------------------------------------
# misc.

sub add_ccflags
{
  push(@CCFLAGS,@_);
  $param_xs{'CCFLAGS'} = join(' ',($param_xs{'CCFLAGS'}||ccopts()),@_);  
  #print "new-ccflags : $param_xs{'CCFLAGS'}\n";
}

sub remove_ccflags
{
  @CCFLAGS = grep{ $_ ne $_[0] } @CCFLAGS;
}

sub flush_ccflags
{
  if( @CCFLAGS )
  {
    $param_xs{'CCFLAGS'} = join(' ',ccopts(),@CCFLAGS);
    #$param_xs{'CCFLAGS'} =~ s/ -MD / -MDd /g or die $param_xs{'CCFLAGS'};
  }else
  {
    delete $param_xs{'CCFLAGS'};
  }
}

sub include_test
{
  $^O ne 'MSWin32' and add_ccflags('-g');
  add_ccflags('-DTEST=1');
  $param_xs{'OBJECT'}  .= ' test.o';
}
