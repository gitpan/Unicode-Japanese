
#ifndef UNICODE__JAPANESE_H__
#define UNICODE__JAPANESE_H__

/* $Id: Japanese.h,v 1.19 2002/10/31 11:08:50 hio Exp $ */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "mediate.h"

#ifndef assert
#include <assert.h>
#endif

//#ifdef __cplusplus
//#include "str.h"
//#endif
#include "str.h"

#ifdef TEST
/* ``TEST'' is defined by devel.PL */
#include "test.h"
#define ONTEST(cmd) cmd
#else
#define ONTEST(cmd)
#endif

#ifndef EXTERN_C
#  ifdef __cplusplus
#    define EXTERN_C extern "C"
#  else
#    define EXTERN_C
#  endif
#endif

#ifndef u_char
/* typedef unsigned char u_char; */
#define u_char unsigned char
#endif

/* misc. */
#define new_SV_UNDEF() newSVsv(&PL_sv_undef)

/* -------------------------------------------------------------------
 * XS methods.
 */
#ifdef __cplusplus
extern "C"
{
#endif
  /* sjis <=> utf8  (conv.cpp) */
  SV* xs_sjis_utf8(SV* sv_str);
  SV* xs_utf8_sjis(SV* sv_str);

  /* getcode  (getcode.cpp) */
  SV* xs_getcode(SV* sv_str);

  /* sjis<=>eucjp, sjis<=>jis */
  SV* xs_sjis_eucjp(SV* sv_str);
  SV* xs_eucjp_sjis(SV* sv_str);
  SV* xs_sjis_jis(SV* sv_str);
  SV* xs_jis_sjis(SV* sv_str);

  /* sjis(i-mode)<=>utf8 */
  SV* xs_sjis_imode1_utf8(SV* sv_str);
  SV* xs_sjis_imode2_utf8(SV* sv_str);
  SV* xs_utf8_sjis_imode1(SV* sv_str);
  SV* xs_utf8_sjis_imode2(SV* sv_str);

  /* sjis(j-sky)<=>utf8 */
  SV* xs_sjis_jsky1_utf8(SV* sv_str);
  SV* xs_sjis_jsky2_utf8(SV* sv_str);
  SV* xs_utf8_sjis_jsky1(SV* sv_str);
  SV* xs_utf8_sjis_jsky2(SV* sv_str);

  /* sjis(dot-i)<=>utf8 */
  SV* xs_sjis_doti_utf8(SV* sv_str);
  SV* xs_utf8_sjis_doti(SV* sv_str);

  /* ucs_utf8 */
  SV* xs_ucs2_utf8(SV* sv_str);
  SV* xs_utf8_ucs2(SV* sv_str);
  
  /* for memory mapped file.        */
  /* (ja:) メモリマップファイル関連 */
  void do_memmap(void);
  void do_memunmap(void);

  /* SJIS <=> UTF8 mapping table      */
  /* (ja:) SJIS <=> UTF8 変換テーブル */
  /* index is in 0..0xffff            */
  extern unsigned short const* g_u2s_table;
  extern unsigned long  const* g_s2u_table;

  /* i-mode/j-sky/dot-i emoji <=> UTF8 mapping table */
  /* (ja:) i-mode/j-sky/dot-i 絵文字 <=> UTF8 変換テーブル */
  extern unsigned long  const* g_ei2u1_table;
  extern unsigned long  const* g_ei2u2_table;
  extern unsigned short const* g_eu2i1_table;
  extern unsigned short const* g_eu2i2_table;
  extern unsigned long  const* g_ej2u1_table;
  extern unsigned long  const* g_ej2u2_table;
  extern unsigned char  const* g_eu2j1_table; /* char [][5] */
  extern unsigned char  const* g_eu2j2_table; /* char [][5] */
  extern unsigned long  const* g_ed2u_table;
  extern unsigned short const* g_eu2d_table;

  /* i-mode/j-sky/dot-i絵文字 <=> UTF8 変換テーブルの要素数 */
  /* バイト数でなく要素数                                   */
  extern int g_ei2u1_size;
  extern int g_ei2u2_size;
  extern int g_eu2i1_size;
  extern int g_eu2i2_size;
  extern int g_ej2u1_size;
  extern int g_ej2u2_size;
  extern int g_eu2j1_size;
  extern int g_eu2j2_size;
  extern int g_ed2u_size;
  extern int g_eu2d_size;
#ifdef __cplusplus
}
#endif

#ifdef UNIJP__PERL_OLDER_THAN_5_006
/* above symbol is defined by Makefile.PL:sub configure. */

#define aTHX_
#define pTHX_
#define dTHX_
#define get_av(var_name,create_flag) perl_get_av(var_name,create_flag);

#ifndef newSVpvn
#define newSVpvn(str,len) newSVpv(str,len)
#endif

#endif /* UNIJP__PERL_OLDER_THAN_5_006 */

#ifdef UNIJP__PERL_OLDER_THAN_5_005
/* above symbol is defined by Makefile.PL:sub configure. */
#ifndef PL_sv_undef
#define PL_sv_undef sv_undef
#endif
#endif /* UNIJP__PERL_OLDER_THAN_5_005 */

#endif /* UNICODE__JAPANESE_H__ */
