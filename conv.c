/* ----------------------------------------------------------------------------
 * conv.c
 * convert sjis <=> utf8
 * ----------------------------------------------------------------------------
 * Mastering programed by YAMASHINA Hio
 * ----------------------------------------------------------------------------
 * $Id: conv.c,v 1.6 2004/11/04 06:08:04 hio Exp $
 * ------------------------------------------------------------------------- */

#ifdef _MSC_VER
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <windows.h>
#include <winsock.h>
#define snprintf _snprintf
#endif

#include "Japanese.h"
#include <stdio.h>
#ifndef _MSC_VER
#include <netinet/in.h>
#endif

#define DISP_S2U 0
#define DISP_U2S 0

#if DISP_U2S
#define ECHO_U2S(arg) fprintf arg
#define ON_U2S(cmd) cmd
#else
#define ECHO_U2S(arg)
#define ON_U2S(cmd)
#endif

#ifndef __cplusplus
#undef bool
#undef true
#undef false
typedef enum bool { false, true, } bool;
#endif

/* ----------------------------------------------------------------------------
 * SV* sv_utf8 = xs_sjis_utf8(SV* sv_sjis)
 * convert sjis into utf8.
 * ------------------------------------------------------------------------- */
EXTERN_C
SV*
xs_sjis_utf8(SV* sv_str)
{
  STRLEN src_len;
  unsigned char* src;
  int len;
  
  SV_Buf result;
  const unsigned char* src_end;
  
  if( sv_str==&PL_sv_undef )
  {
    return newSVsv(&PL_sv_undef);
  }
  
  src = (unsigned char*)SvPV(sv_str,src_len);
  len = sv_len(sv_str);
#if DISP_S2U
  fprintf(stderr,"Unicode::Japanese::(xs)sjis_utf8\n",len);
  bin_dump("in ",src,len);
#endif
  SV_Buf_init(&result,len*3/2+4);
  src_end = src+len;

  while( src<src_end )
  {
    const unsigned char* ptr;
    if( src[0]<0x80 )
    { /* ASCII */
      /*fprintf(stderr,"ascii: %02x\n",src[0]); */
      SV_Buf_append_ch(&result,*src);
      ++src;
      continue;
    }else if( 0xa1<=src[0] && src[0]<=0xdf )
    { /* half-width katakana (ja:半角カナ) */
      /*fprintf(stderr,"kana": %02x\n",src[0]); */
      ptr = (unsigned char*)&g_s2u_table[src[0]];
      ++src;
    }else if( ((0x81<=src[0] && src[0]<=0x9f) || (0xe0<=src[0] && src[0]<=0xfc) )
              && (0x40<=src[1] && src[1]<=0xfc && src[1]!=0x7f) )
    { /* a double-byte letter (ja:2バイト文字) */
      register const unsigned short sjis = ntohs(*(unsigned short*)src);
      /*fprintf(stderr,"sjis: %04x\n",sjis); */
      ptr = (unsigned char*)&g_s2u_table[sjis];
      src += 2;
    }else
    { /* unknown */
      /*fprintf(stderr,"unknown: %02x\n",src[0]); */
      SV_Buf_append_ch(&result,'?');
      ++src;
      continue;
    }

    /*fprintf(stderr,"utf8-char : %02x %02x %02x %02x\n",ptr[0],ptr[1],ptr[2],ptr[3]); */
    if( ptr[3] )
    {
      /*fprintf(stderr,"utf8-len: [%d]\n",4); */
      SV_Buf_append_ch4(&result,*(int*)ptr);
    }else if( ptr[2] )
    {
      /*fprintf(stderr,"utf8-len: [%d]\n",3); */
      SV_Buf_append_ch3(&result,*(int*)ptr);
    }else if( ptr[1] )
    {
      /*fprintf(stderr,"utf8-len: [%d]\n",2); */
      SV_Buf_append_ch2(&result,*(short*)ptr);
    }else if( ptr[0] )
    {
      /*fprintf(stderr,"utf8-len: [%d]\n",1); */
      SV_Buf_append_ch(&result,*ptr);
    }else
    {
      SV_Buf_append_ch(&result,'?');
    }
  }
#if DISP_S2U
  bin_dump("out",result.getBegin(),result.getLength());
#endif
  SV_Buf_setLength(&result);

  return SV_Buf_getSv(&result);
}

/* ----------------------------------------------------------------------------
 * SV* sv_sjis = xs_utf8_sjis(SV* sv_utf8)
 * convert utf8 into sjis.
 * ------------------------------------------------------------------------- */
EXTERN_C
SV*
xs_utf8_sjis(SV* sv_str)
{
  unsigned char* src;
  int len;
  SV_Buf result;
  const unsigned char* src_end;
  
  if( sv_str==&PL_sv_undef )
  {
    return newSVsv(&PL_sv_undef);
  }
  src = (unsigned char*)SvPV(sv_str,PL_na);
  len = sv_len(sv_str);

  ECHO_U2S((stderr,"Unicode::Japanese::(xs)utf8_sjis\n"));
  ON_U2S( bin_dump("in ",src,len) );

  SV_Buf_init(&result,len+4);
  src_end = src+len;

  while( src<src_end )
  {
    unsigned int ucs;
    
    if( *src<=0x7f )
    {
      /* ascii chars sequence (ja:ASCIIはまとめて追加〜) */
      int len = 1;
      while( src+len<src_end && src[len]<=0x7f )
      {
        ++len;
      }
      SV_Buf_append_str(&result,src,len);
      src+=len;
      continue;
    }
    
    /* non-ascii */
    if( 0xe0<=*src && *src<=0xef )
    {
      const int          utf8_len = 3;
      const unsigned int ucs_min  = 0x800;
      const unsigned int ucs_max  = 0xffff;
      /* check length */
      if( src+utf8_len<=src_end )
      { /* noop */
      }else
      { /* no enough sequence */
        SV_Buf_append_ch(&result,'?');
        ++src;
        continue;
      }
      /* check follow sequences */
      if( 0x80<=src[1] && src[1]<=0xbf && 0x80<=src[2] && src[2]<=0xbf )
      { /* noop */
      }else
      {
        SV_Buf_append_ch(&result,'?');
        ++src;
        continue;
      }
      
      /* compute code point */
      ucs = ((src[0] & 0x0F)<<12)|((src[1] & 0x3F)<<6)|(src[2] & 0x3F);
      src += utf8_len;
      if( ucs_min<=ucs && ucs<=ucs_max )
      { /* noop */
      }else
      { /* illegal sequence */
        SV_Buf_append_ch(&result,'?');
        continue;
      }
      /* ok. */
    }else if( 0xf0<=*src && *src<=0xf7 )
    {
      const int          utf8_len = 4;
      const unsigned int ucs_min  = 0x010000;
      const unsigned int ucs_max  = 0x10ffff;
      /* check length */
      if( src+utf8_len<=src_end )
      { /* noop */
      }else
      { /* no enough sequence */
        SV_Buf_append_ch(&result,'?');
        ++src;
        continue;
      }
      /* check follow sequences */
      if( 0x80<=src[1] && src[1]<=0xbf && 0x80<=src[2] && src[2]<=0xbf
          && 0x80<=src[3] && src[3]<=0xbf )
      { /* noop */
      }else
      {
        SV_Buf_append_ch(&result,'?');
        ++src;
        continue;
      }
      
      /* compute code point */
      ucs = ((src[0] & 0x07)<<18)|((src[1] & 0x3F)<<12)|
        ((src[2] & 0x3f) << 6)|(src[3] & 0x3F);
      src += utf8_len;
      if( ucs_min<=ucs && ucs<=ucs_max )
      { /* noop */
      }else
      { /* illegal sequence */
        SV_Buf_append_ch(&result,'?');
        continue;
      }
      /* private area: block emoji */ 
      if( 0x0f0000<=ucs && ucs<=0x0fffff )
      { 
        SV_Buf_append_ch(&result,'?');
        continue;
      }
      
      /* > U+FFFF not supported. */
      SV_Buf_append_ch(&result,'?');
      continue;
    }else if( 0xc0<=*src && *src<=0xdf )
    {
      const int          utf8_len = 2;
      const unsigned int ucs_min  =  0x80;
      const unsigned int ucs_max  = 0x7ff;
      if( src+utf8_len<=src_end )
      { /* noop */
      }else
      { /* no enough sequence */
        SV_Buf_append_ch(&result,'?');
        ++src;
        continue;
      }
      /* check follow sequences */
      if( 0x80<=src[1] && src[1]<=0xbf )
      { /* noop */
      }else
      {
        SV_Buf_append_ch(&result,'?');
        ++src;
        continue;
      }
      
      /* compute code point */
      ucs = ((src[0] & 0x1F)<<6)|(src[1] & 0x3F);
      src += utf8_len;
      if( ucs_min<=ucs && ucs<=ucs_max )
      { /* noop */
      }else
      { /* illegal sequence */
        SV_Buf_append_ch(&result,'?');
        continue;
      }
      
      /* ok. */
    }else if( 0xf8<=*src && *src<=0xfb )
    {
      const int          utf8_len = 5;
      if( src+utf8_len<=src_end )
      { /* noop */
      }else
      { /* no enough sequence */
        SV_Buf_append_ch(&result,'?');
        ++src;
        continue;
      }
      /* check follow sequences */
      if( 0x80<=src[1] && src[1]<=0xbf && 0x80<=src[2] && src[2]<=0xbf
          && 0x80<=src[3] && src[3]<=0xbf && 0x80<=src[4] && src[4]<=0xbf )
      { /* noop */
      }else
      {
        SV_Buf_append_ch(&result,'?');
        ++src;
        continue;
      }
      
      /* compute code point */
      src += utf8_len;
      SV_Buf_append_ch(&result,'?');
      continue;
    }else if( 0xfc<=*src && *src<=0xfd )
    {
      const int          utf8_len = 6;
      if( src+utf8_len<=src_end )
      { /* noop */
      }else
      { /* no enough sequence */
        SV_Buf_append_ch(&result,'?');
        ++src;
        continue;
      }
      /* check follow sequences */
      if( 0x80<=src[1] && src[1]<=0xbf && 0x80<=src[2] && src[2]<=0xbf
          && 0x80<=src[3] && src[3]<=0xbf && 0x80<=src[4] && src[4]<=0xbf
          && 0x80<=src[5] && src[5]<=0xbf )
      { /* noop */
      }else
      {
        SV_Buf_append_ch(&result,'?');
        ++src;
        continue;
      }
      
      /* compute code point */
      src += utf8_len;
      SV_Buf_append_ch(&result,'?');
      continue;
    }else
    {
      SV_Buf_append_ch(&result,'?');
      ++src;
      continue;
    }
    
    /* ucs => sjis */
    ECHO_U2S((stderr,"ucs2 [%04x]\n",ucs));
    ECHO_U2S((stderr,"sjis [%04x]\n",ntohs(g_u2s_table[ucs]) ));
    
    if( g_u2s_table[ucs] || !ucs )
    { /* 対応文字がある時とucs=='\0'の時 */
      if( g_u2s_table[ucs] & 0xff00 )
      {
        SV_Buf_append_ch2(&result,g_u2s_table[ucs]);
      }else
      {
        SV_Buf_append_ch(&result,(unsigned char)g_u2s_table[ucs]);
      }
    }else if( ucs<=0x7F )
    {
      SV_Buf_append_ch(&result,(unsigned char)ucs);
    }else
    {
      SV_Buf_append_entityref(&result,ucs);
    }
  } /* for */

  ON_U2S( bin_dump("out",result.getBegin(),result.getLength()) );
  SV_Buf_setLength(&result);

  return SV_Buf_getSv(&result);
}

/* ----------------------------------------------------------------------------
 * End Of File.
 * ------------------------------------------------------------------------- */
