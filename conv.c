
/* $Id: conv.c,v 1.4 2002/10/31 11:08:50 hio Exp $ */

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
    { /* 半角カナ. */
      /*fprintf(stderr,"kana": %02x\n",src[0]); */
      ptr = (unsigned char*)&g_s2u_table[src[0]];
      ++src;
    }else if( ((0x81<=src[0] && src[0]<=0x9f) || (0xe0<=src[0] && src[0]<=0xfc) )
	      && (0x40<=src[1] && src[1]<=0xfc && src[1]!=0x7f) )
    { /* 2バイト文字. */
      register const unsigned short sjis = ntohs(*(unsigned short*)src);
      /*fprintf(stderr,"sjis: %04x\n",sjis); */
      ptr = (unsigned char*)&g_s2u_table[sjis];
      src += 2;
    }else
    { /* 不明. */
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
    int i;
    int utf8_len;
    bool succ;
    unsigned int ucs;
    
    if( *src<=0x7f )
    {
      /* ASCIIはまとめて追加〜 */
      int len = 1;
      while( src+len<src_end && src[len]<=0x7f )
      {
	++len;
      }
      SV_Buf_append_str(&result,src,len);
      src+=len;
      continue;
    }
    /* utf8をucsに変換 */
    /* utf8の１文字の長さチェック */
    if( 0xc0<=*src && *src<=0xdf )
    {
      utf8_len = 2;
    }else if( 0xe0<=*src && *src<=0xef )
    {
      utf8_len = 3;
    }else if( 0xf0<=*src && *src<=0xf7 )
    {
      utf8_len = 4;
    }else if( 0xf8<=*src && *src<=0xfb )
    {
      utf8_len = 5;
    }else if( 0xfc<=*src && *src<=0xfd )
    {
      utf8_len = 6;
    }else
    {
      SV_Buf_append_ch(&result,'?');
      ++src;
      continue;
    }
    /* 長さ足りてるかチェック */
    if( src+utf8_len-1>=src_end )
    {
      ECHO_U2S((stderr,"  no enough buffer, here is %d, need %d\n",src_end-src,utf8_len));
      SV_Buf_append_ch(&result,'?');
      ++src;
      continue;
    }
    /* ２バイト目以降が正しい文字範囲か確認 */
    succ = true;
    for( i=1; i<utf8_len; ++i )
    {
      if( src[i]<0x80 || 0xbf<src[i] )
      {
	ECHO_U2S((stderr,"  at %d, char out of range\n",i));
	succ = false;
	break;
      }
    }
    if( !succ )
    {
      SV_Buf_append_ch(&result,'?');
      ++src;
      continue;
    }
    /* utf8からucsのコードを算出 */
    ECHO_U2S((stderr,"utf8-charlen: [%d]\n",utf8_len));
    switch(utf8_len)
    {
    case 2:
      {
	ucs = ((src[0] & 0x1F)<<6)|(src[1] & 0x3F);
	break;
      }
    case 3:
      {
	ucs = ((src[0] & 0x0F)<<12)|((src[1] & 0x3F)<<6)|(src[2] & 0x3F);
	break;
      }
    case 4:
      {
	ucs = ((src[0] & 0x07)<<18)|((src[1] & 0x3F)<<12)|
	  ((src[2] & 0x3f) << 6)|(src[3] & 0x3F);
	break;
      }
    case 5:
      {
	ucs = ((src[0] & 0x03) << 24)|((src[1] & 0x3F) << 18)|
	    ((src[2] & 0x3f) << 12)|((src[3] & 0x3f) << 6)|
	    (src[4] & 0x3F);
	break;
      }
    case 6:
      {
	ucs = ((src[0] & 0x03) << 30)|((src[1] & 0x3F) << 24)|
	    ((src[2] & 0x3f) << 18)|((src[3] & 0x3f) << 12)|
	    ((src[4] & 0x3f) << 6)|(src[5] & 0x3F);
	break;
      }
    default:
      {
        /* NOT REACH HERE */
	ECHO_U2S((stderr,"invalid utf8-length: %d\n",utf8_len));
	ucs = '?';
      }
    }

    if( 0x0f0000<=ucs && ucs<=0x0fffff )
    { /* 絵文字判定(sjis) */
      SV_Buf_append_ch(&result,'?');
      assert(utf8_len>=4);
      src += utf8_len;
      continue;
    }

    if( ucs & ~0xFFFF )
    { /* ucs2の範囲外 (ucs4の範囲) */
      SV_Buf_append_entityref(&result,ucs);
      src += utf8_len;
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
    src += utf8_len;
    /*bin_dump("now",dst_begin,dst-dst_begin); */
  } /* for */

  ON_U2S( bin_dump("out",result.getBegin(),result.getLength()) );
  SV_Buf_setLength(&result);

  return SV_Buf_getSv(&result);
}
