
/* $Id: memmap_win32.c,v 1.3 2002/10/31 11:08:50 hio Exp $ */

#include "Japanese.h"
#include <windows.h>

  /* SJIS <=> UTF8 変換テーブル */
  unsigned short const* g_u2s_table;
  unsigned long  const* g_s2u_table;

  /* i-mode/j-sky/dot-i絵文字 <=> UTF8 変換テーブル */
  unsigned long  const* g_ei2u1_table;
  unsigned long  const* g_ei2u2_table;
  unsigned short const* g_eu2i1_table;
  unsigned short const* g_eu2i2_table;
  unsigned long  const* g_ej2u1_table;
  unsigned long  const* g_ej2u2_table;
  unsigned char  const* g_eu2j1_table; /* char [][5] */
  unsigned char  const* g_eu2j2_table; /* char [][5] */
  unsigned long  const* g_ed2u_table;
  unsigned short const* g_eu2d_table;

  /* i-mode/j-sky/dot-i絵文字 <=> UTF8 変換テーブルの要素数 */
  /* バイト数でなく要素数                                   */
  int g_ei2u1_size;
  int g_ei2u2_size;
  int g_eu2i1_size;
  int g_eu2i2_size;
  int g_ej2u1_size;
  int g_ej2u2_size;
  int g_eu2j1_size;
  int g_eu2j2_size;
  int g_ed2u_size;
  int g_eu2d_size;

  /* メモリマップの情報 */
  static int   g_mmap_u2s_length;
  static char* g_mmap_u2s_start;
  static int   g_mmap_emj_length;
  static char* g_mmap_emj_start;

static HANDLE fd_u2s = INVALID_HANDLE_VALUE;
static HANDLE fd_emj = INVALID_HANDLE_VALUE;
static HANDLE hmap_u2s = INVALID_HANDLE_VALUE;
static HANDLE hmap_emj = INVALID_HANDLE_VALUE;

/* ----------------------------------------------------------------------------
 * 指定のファイルを @INC から探す.
 * オープンしてファイルハンドルを返す.
 */
static HANDLE
findfile(AV* INC, const char* filename)
{
  /*fprintf(stderr,"findfile [%s]\n",filename); */
  int i;
  char  path[MAX_PATH];
  int addlen = strlen(filename);
  for( i=0; i<av_len(INC); ++i )
  {
    SV** dir = av_fetch(INC,i,0);
    int len = sv_len(*dir);
    HANDLE fd;
    
    if( len==0 ) continue;
    if( len+addlen+2>=MAX_PATH ) continue;
    memcpy(path,SvPV(*dir,PL_na),len);
    if( path[len-1]!='\\' ) path[len++] = '\\';
    memcpy(path+len,filename,addlen);
    path[len+addlen] = '\0';
    /*fprintf(stderr,"  trying [%s] ...\n",path); */
    fd = CreateFile(path,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL|FILE_FLAG_RANDOM_ACCESS,NULL);
    if( fd!=INVALID_HANDLE_VALUE )
    {
      /*fprintf(stderr,"findfile [%s] found\n",filename); */
      return fd;
    }
  }
  /*fprintf(stderr,"findfile [%s] failed\n",filename); */
  return INVALID_HANDLE_VALUE;
}

/* ----------------------------------------------------------------------------
 * 必要なファイルをメモリにマッピング
 */
void
do_memmap(void)
{
  AV* INC;
  DWORD siz_u2s,siz_emj;

  /*fprintf(stderr,"* Unicode::Japanese::(xs)do_memmap *\n"); */

  INC = get_av("INC",0);
  if( INC==NULL )
  {
    Perl_croak(aTHX_ "do_memmap, cannot get @INC.");
    return;
  }
  fd_u2s = findfile(INC,"Unicode/Japanese/u2s-s2u.dat");
  fd_emj = findfile(INC,"Unicode/Japanese/emoji.dat");

  if( fd_u2s==INVALID_HANDLE_VALUE || fd_emj==INVALID_HANDLE_VALUE )
  {
    if( fd_u2s!=INVALID_HANDLE_VALUE )
    {
      CloseHandle(fd_u2s);
      fd_u2s = INVALID_HANDLE_VALUE;
      Perl_croak(aTHX_ "do_memmap, emoji table not found or could not  open.");
    }else if( fd_emj!=INVALID_HANDLE_VALUE )
    {
      CloseHandle(fd_emj);
      fd_emj = INVALID_HANDLE_VALUE;
      Perl_croak(aTHX_ "do_memmap, u2s table not found or could not open.");
    }else
    {
      Perl_croak(aTHX_ "do_memmap, u2s table and emoji table not found or could not open.");
    }
    return;
  }
  siz_u2s = GetFileSize(fd_u2s,NULL);
  siz_emj = GetFileSize(fd_emj,NULL);
  if( siz_u2s==-1 && siz_emj==-1 )
  {
    CloseHandle(fd_u2s);
    CloseHandle(fd_emj);
    fd_u2s = fd_emj = INVALID_HANDLE_VALUE;
    if( siz_u2s!=-1 )
    {
      Perl_croak(aTHX_ "do_memmap, GetFileSize emoji table (for mmap) failed.");
    }else if( siz_emj!=-1 )
    {
      Perl_croak(aTHX_ "do_memmap, GetFileSize u2s table (for mmap) failed.");
    }else
    {
      Perl_croak(aTHX_ "do_memmap, GetFileSize u2s and emoji tables (for mmap) failed.");
    }
    return;
  }

  /* サイズチェック */
  if( siz_u2s!=0x60000 )
  {
    CloseHandle(fd_u2s);
    CloseHandle(fd_emj);
    fd_u2s = fd_emj = INVALID_HANDLE_VALUE;
    Perl_croak(aTHX_ "do_memmap, u2s-s2u size != 0x60000, [got %#x].",siz_u2s);
    return;
  }
  if( siz_emj!=0x13c00 )
  {
    CloseHandle(fd_u2s);
    CloseHandle(fd_emj);
    fd_u2s = fd_emj = INVALID_HANDLE_VALUE;
    Perl_croak(aTHX_ "do_memmap, emoji.dat size != 0x13c00, [got %#x].",siz_emj);
    return;
  }
  
  /* マッピングの作成 */
  hmap_u2s = CreateFileMapping(fd_u2s,NULL,PAGE_READONLY,0,siz_u2s,"Unicode-Japanese-u2s");
  hmap_emj = CreateFileMapping(fd_emj,NULL,PAGE_READONLY,0,siz_emj,"Unicode-Japanese-emj");
  g_mmap_u2s_length  = siz_u2s;
  g_mmap_u2s_start = (char*)MapViewOfFile(hmap_u2s,FILE_MAP_READ,0,0,siz_u2s);
  g_mmap_emj_length  = siz_emj;
  g_mmap_emj_start = (char*)MapViewOfFile(hmap_emj,FILE_MAP_READ,0,0,siz_emj);
  
  if( g_mmap_u2s_start==NULL || g_mmap_emj_start==NULL )
  {
    const char* msg;
    if( g_mmap_u2s_start!=NULL )
    {
      msg = "do_memmap, mmap emoji table failed.";
      g_mmap_emj_start = NULL;
    }else if( g_mmap_emj_start!=NULL )
    {
      msg = "do_memmap, mmap u2s table failed.";
      g_mmap_u2s_start = NULL;
    }else
    {
      msg = "do_memmap, mmap u2s and emoji table failed.";
      g_mmap_u2s_start = NULL;
      g_mmap_emj_start = NULL;
    }
    do_memunmap();
    Perl_croak(aTHX_ msg);
    return;
  }

  /* u2s,s2uの設定 */
  g_u2s_table = (unsigned short*)(g_mmap_u2s_start +     0x0);
  g_s2u_table = (unsigned long *)(g_mmap_u2s_start + 0x20000);

  /* i-mode 1 */
  g_eu2i1_table = (unsigned short*)(g_mmap_emj_start +     0x0); /* +0x2000 */
  g_eu2i1_size  = 0x2000/2;
  g_ei2u1_table = (unsigned long *)(g_mmap_emj_start +  0x2000); /* +0x0800 */
  g_ei2u1_size  = 0x800/4;
  /* i-mode 2 */
  g_eu2i2_table = (unsigned short*)(g_mmap_emj_start +  0x2800); /* +0x2000 */
  g_eu2i2_size  = 0x2000/2;
  g_ei2u2_table = (unsigned long *)(g_mmap_emj_start +  0x4800); /* +0x0800 */
  g_ei2u2_size  = 0x800/4;
  /* jsky 1 */
  g_eu2j1_table = (unsigned char *)(g_mmap_emj_start +  0x5000); /* +0x5000 */
  g_eu2j1_size  = 0x5000/1;
  g_ej2u1_table = (unsigned long *)(g_mmap_emj_start +  0xa000); /* +0xc00 */
  g_ej2u1_size  = 0xc00/4;
  /* jsky 2 */
  g_eu2j2_table = (unsigned char *)(g_mmap_emj_start +  0xac00); /* +0x5000 */
  g_eu2j2_size  = 0x5000/1;
  g_ej2u2_table = (unsigned long *)(g_mmap_emj_start +  0xfc00); /* +0xc00 */
  g_ej2u2_size  = 0xc00/4;
  /* dot-i */
  g_eu2d_table  = (unsigned short*)(g_mmap_emj_start + 0x10800); /* +0x2000 */
  g_eu2d_size   = 0x2000/2;
  g_ed2u_table  = (unsigned long *)(g_mmap_emj_start + 0x12800); /* +0x1400 */
  g_ed2u_size   = 0x1400/4;

  return;
}

/* ----------------------------------------------------------------------------
 * メモリマップの解除
 */
void
do_memunmap(void)
{
  /* printf("* do_memunmap() *\n"); */

  /* u2s table */
  if( g_mmap_u2s_start!=NULL )
  {
    BOOL res = UnmapViewOfFile(g_mmap_u2s_start);
    if( !res )
    {
      Perl_warn(aTHX_ "do_memunmap, UnmapViewOfFile u2s table failed.");
    }
    g_mmap_u2s_start = NULL;
  }
  /* emoji table */
  if( g_mmap_emj_start!=NULL )
  {
    BOOL res = UnmapViewOfFile(g_mmap_emj_start);
    if( !res )
    {
      Perl_warn(aTHX_ "do_memunmap, UnmapViewOfFile emoji table failed.");
    }
    g_mmap_emj_start = NULL;
  }

  if( hmap_u2s!=INVALID_HANDLE_VALUE )
  {
     CloseHandle(hmap_u2s);
     hmap_u2s = NULL;
  }
  if( hmap_emj!=INVALID_HANDLE_VALUE )
  {
     CloseHandle(hmap_emj);
     hmap_emj = NULL;
  }

  if( fd_u2s!=INVALID_HANDLE_VALUE )
  {
    CloseHandle(fd_u2s);
    fd_u2s = NULL;
  }
  
  if( fd_emj!=INVALID_HANDLE_VALUE )
  {
    CloseHandle(fd_emj);
    fd_emj = NULL;
  }

  return;
}
