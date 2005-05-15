
/* $Id: memmap_win32.c,v 1.7 2005/05/15 08:34:42 hio Exp $ */

#include "Japanese.h"
#include <windows.h>
#include "win32/resource.h"
#include <tchar.h>
#include <stdio.h>

static LPTSTR getLastErrorMessage(void);

#ifdef UNIJP_NO_DLLMAIN
extern HMODULE getDllHandle();
#else
static HMODULE Unicode_Japanese_hModule;
#define getDllHandle() Unicode_Japanese_hModule

/* ----------------------------------------------------------------------------
 * DllMain
 */
BOOL APIENTRY DllMain( HANDLE hDll, 
                       DWORD  ul_reason_for_call, 
                       LPVOID lpReserved
		       )
{
  switch (ul_reason_for_call)
  {
  case DLL_PROCESS_ATTACH:
    {
      Unicode_Japanese_hModule = hDll;
      break;
    }
  case DLL_THREAD_ATTACH:
  case DLL_THREAD_DETACH:
    {
      break;
    }
  case DLL_PROCESS_DETACH:
    {
      break;
    }
  }
  return TRUE;
}
#endif

  /* SJIS <=> UTF8 変換テーブル */
  UJ_UINT16 const* g_u2s_table;
  UJ_UINT32 const* g_s2u_table;

  /* i-mode/j-sky/dot-i絵文字 <=> UTF8 変換テーブル */
  UJ_UINT32 const* g_ei2u1_table;
  UJ_UINT32 const* g_ei2u2_table;
  UJ_UINT16 const* g_eu2i1_table;
  UJ_UINT16 const* g_eu2i2_table;
  UJ_UINT32 const* g_ej2u1_table;
  UJ_UINT32 const* g_ej2u2_table;
  UJ_UINT8  const* g_eu2j1_table; /* char [][5] */
  UJ_UINT8  const* g_eu2j2_table; /* char [][5] */
  UJ_UINT32 const* g_ed2u_table;
  UJ_UINT16 const* g_eu2d_table;

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

/* ----------------------------------------------------------------------------
 * 必要なファイルをメモリにマッピング
 */
void
do_memmap(void)
{
  HRSRC hResource;
  HGLOBAL hResourceChunk;
  LPVOID data_u2s, data_emj;
  DWORD siz_u2s, siz_emj;
  const HANDLE hModule = getDllHandle();
  
  /*fprintf(stderr,"* Unicode::Japanese::(xs)do_memmap *\n"); */
  
  hResource = FindResourceEx(hModule,RT_RCDATA,MAKEINTRESOURCE(RC_U2STABLE),LOCALE_INVARIANT);
  if( hResource==NULL )
  {
    LPTSTR msg = getLastErrorMessage();
    sv_setpv(ERRSV,"do_memmap(win32), FindResource(u2stable) failed : ");
    sv_catpv(ERRSV,msg);
    LocalFree(msg);
    croak(Nullch);
  }
  hResourceChunk = LoadResource(hModule,hResource);
  if( hResourceChunk==NULL )
  {
    Perl_croak(aTHX_ "do_memmap(win32), LoadResource(u2stable) failed.");
  }
  data_u2s = LockResource(hResourceChunk);
  if( data_u2s==NULL )
  {
    Perl_croak(aTHX_ "do_memmap(win32), LockResource(u2stable) failed.");
  }
  siz_u2s = SizeofResource(hModule,hResource);
  if( siz_u2s==0 )
  {
    LPTSTR msg = getLastErrorMessage();
    sv_setpv(ERRSV,"do_memmap(win32), SizeofResource(u2stable) failed : ");
    sv_catpv(ERRSV,msg);
    LocalFree(msg);
    croak(Nullch);
  }
  
  hResource = FindResourceEx(hModule,RT_RCDATA,MAKEINTRESOURCE(RC_EMJTABLE),LOCALE_INVARIANT);
  if( hResource==NULL )
  {
    Perl_croak(aTHX_ "do_memmap(win32), FindResource(emjtable) failed.");
  }
  hResourceChunk = LoadResource(hModule,hResource);
  if( hResourceChunk==NULL )
  {
    Perl_croak(aTHX_ "do_memmap(win32), LoadResource(emjtable) failed.");
  }
  data_emj = LockResource(hResourceChunk);
  if( data_emj==NULL )
  {
    Perl_croak(aTHX_ "do_memmap(win32), LockResource(emjtable) failed.");
  }
  siz_emj = SizeofResource(hModule,hResource);
  if( siz_emj==0 )
  {
    Perl_croak(aTHX_ "do_memmap(win32), SizeofResource(emjtable) failed.");
  }
  
  /* サイズチェック */
  if( siz_u2s!=0x60000 )
  {
    Perl_croak(aTHX_ "do_memmap, u2s-s2u size != 0x60000, [got %#x].",siz_u2s);
    return;
  }
  if( siz_emj!=0x13c00 )
  {
    Perl_croak(aTHX_ "do_memmap, emoji.dat size != 0x13c00, [got %#x].",siz_emj);
    return;
  }
  
  /* マッピングの作成 */
  g_mmap_u2s_length  = siz_u2s;
  g_mmap_u2s_start = (char*)data_u2s;
  g_mmap_emj_length  = siz_emj;
  g_mmap_emj_start = (char*)data_emj;
  
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
  g_u2s_table = (UJ_UINT16*)(g_mmap_u2s_start +     0x0);
  g_s2u_table = (UJ_UINT32*)(g_mmap_u2s_start + 0x20000);

  /* i-mode 1 */
  g_eu2i1_table = (UJ_UINT16*)(g_mmap_emj_start +     0x0); /* +0x2000 */
  g_eu2i1_size  = 0x2000/2;
  g_ei2u1_table = (UJ_UINT32*)(g_mmap_emj_start +  0x2000); /* +0x0800 */
  g_ei2u1_size  = 0x800/4;
  /* i-mode 2 */
  g_eu2i2_table = (UJ_UINT16*)(g_mmap_emj_start +  0x2800); /* +0x2000 */
  g_eu2i2_size  = 0x2000/2;
  g_ei2u2_table = (UJ_UINT32*)(g_mmap_emj_start +  0x4800); /* +0x0800 */
  g_ei2u2_size  = 0x800/4;
  /* jsky 1 */
  g_eu2j1_table = (UJ_UINT8*)(g_mmap_emj_start +  0x5000); /* +0x5000 */
  g_eu2j1_size  = 0x5000/1;
  g_ej2u1_table = (UJ_UINT32*)(g_mmap_emj_start +  0xa000); /* +0xc00 */
  g_ej2u1_size  = 0xc00/4;
  /* jsky 2 */
  g_eu2j2_table = (UJ_UINT8*)(g_mmap_emj_start +  0xac00); /* +0x5000 */
  g_eu2j2_size  = 0x5000/1;
  g_ej2u2_table = (UJ_UINT32*)(g_mmap_emj_start +  0xfc00); /* +0xc00 */
  g_ej2u2_size  = 0xc00/4;
  /* dot-i */
  g_eu2d_table  = (UJ_UINT16*)(g_mmap_emj_start + 0x10800); /* +0x2000 */
  g_eu2d_size   = 0x2000/2;
  g_ed2u_table  = (UJ_UINT32*)(g_mmap_emj_start + 0x12800); /* +0x1400 */
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

  return;
}

/* ----------------------------------------------------------------------------
 * LPTSTR message = getLastErrorMessage();
 * LPTSTR message = getErrorMessage(DWORD errorCode);
 *   エラーメッセージの取得 
 *   取得したメッセージは LocalFree で解放してね☆ 
 */
static LPTSTR getErrorMessage(DWORD errcode);
static LPTSTR getLastErrorMessage(void)
{
  return getErrorMessage(GetLastError());
}
static LPTSTR getErrorMessage(DWORD errcode)
{
  LPVOID lpMessage;
  DWORD msglen;
  lpMessage = NULL;
  msglen = FormatMessage( FORMAT_MESSAGE_ALLOCATE_BUFFER
			  | FORMAT_MESSAGE_FROM_SYSTEM
			  | FORMAT_MESSAGE_IGNORE_INSERTS,
			  NULL,
			  errcode,
			  MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), /* 既定の言語 */
			  (LPTSTR)&lpMessage,
			  0,
			  NULL
			  );
  if( msglen==0 )
  {
    if( lpMessage )
    {
      lpMessage = LocalReAlloc(lpMessage,64,0);
    }else
    {
      lpMessage = LocalAlloc(LMEM_FIXED,64);
    }
    if( lpMessage )
    {
      _sntprintf((LPTSTR)lpMessage,64,
		 TEXT("Unknown Error (%lu,0x%08x)\n"),
		 errcode, errcode
		 );
    }
  }
  return lpMessage;
}

