
#ifndef UNICODE__JAPANESE
#define UNICODE__JAPANESE

/* $Id: Japanese.h,v 1.15 2002/07/20 06:41:52 hio Exp $ */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "mediate.h"

#ifndef assert
#include <assert.h>
#endif

#ifdef __cplusplus
#include "str.h"
#endif

#ifdef TEST
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
/*typedef unsigned char u_char;*/
#define u_char unsigned char
#endif

/* util */
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
  SV* xs_sjis_imode_utf8(SV* sv_str);
  SV* xs_utf8_sjis_imode(SV* sv_str);

  /* sjis(j-sky)<=>utf8 */
  SV* xs_sjis_jsky_utf8(SV* sv_str);
  SV* xs_utf8_sjis_jsky(SV* sv_str);

  /* sjis(dot-i)<=>utf8 */
  SV* xs_sjis_doti_utf8(SV* sv_str);
  SV* xs_utf8_sjis_doti(SV* sv_str);

  /* ucs_utf8 */
  SV* xs_ucs2_utf8(SV* sv_str);
  SV* xs_utf8_ucs2(SV* sv_str);

  /* メモリマップファイル関連 */
  void do_memmap();
  void do_memunmap();

  /* SJIS <=> UTF8 変換テーブル */
  /* indexは0..0xffff           */
  extern unsigned short const* g_u2s_table;
  extern unsigned long  const* g_s2u_table;

  /* i-mode/j-sky/dot-i絵文字 <=> UTF8 変換テーブル */
  extern unsigned long  const* g_ei2u_table;
  extern unsigned short const* g_eu2i_table;
  extern unsigned long  const* g_ej2u_table;
  extern unsigned char  const* g_eu2j_table; // char [][5]
  extern unsigned long  const* g_ed2u_table;
  extern unsigned short const* g_eu2d_table;

  /* i-mode/j-sky/dot-i絵文字 <=> UTF8 変換テーブルの要素数 */
  /* バイト数でなく要素数                                   */
  extern int g_ei2u_size;
  extern int g_eu2i_size;
  extern int g_ej2u_size;
  extern int g_eu2j_size;
  extern int g_ed2u_size;
  extern int g_eu2d_size;
#ifdef __cplusplus
}
#endif

#ifdef UNIJP__PERL_OLDER_THEN_5_006

#define aTHX_
#define pTHX_
#define dTHX_
#define get_av(var_name,create_flag) perl_get_av(var_name,create_flag);

#ifndef newSVpvn
#define newSVpvn(str,len) newSVpv(str,len)
#endif

#endif

#ifdef UNIJP__PERL_OLDER_THEN_5_005
#ifndef PL_sv_undef
#define PL_sv_undef sv_undef
#endif
#endif

#endif /* UNICODE__JAPANESE */
