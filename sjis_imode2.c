
/* $Id: sjis_imode2.c,v 1.2 2005/08/18 09:39:28 hio Exp $ */

#include "Japanese.h"
#include <stdio.h>

#ifndef __cplusplus
#undef bool
#undef true
#undef false
typedef enum bool { false, true, } bool;
#endif

#define DISP_U2S 0
#define DISP_S2U 0

#if DISP_U2S
#define ECHO_U2S(arg) fprintf arg
#define ON_U2S(cmd) cmd
#else
#define ECHO_U2S(arg)
#define ON_U2S(cmd)
#endif
#if DISP_S2U
#define ECHO_S2U(arg) fprintf arg
#define ON_S2U(cmd) cmd
#else
#define ECHO_S2U(arg)
#define ON_S2U(cmd)
#endif

/* ----------------------------------------------------------------------------
 * SV* sv_utf8 = xs_sjis_imode2_utf8(SV* sv_sjis)
 * convert sjis(imode2) into utf8.
 * ------------------------------------------------------------------------- */
EXTERN_C
SV*
xs_sjis_imode2_utf8(SV* sv_str)
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
  fprintf(stderr,"Unicode::Japanese::(xs)sjis_utf8_imode2\n",len);
  bin_dump("in ",src,len);
#endif
  SV_Buf_init(&result,len*3/2+4);
  src_end = src+len;

  while( src<src_end )
  {
    const unsigned char* ptr;
    if( src[0]<0x80 )
    { /* ASCII */
      ECHO_U2S((stderr,"ascii: %02x\n",src[0]));
      if( src[0]=='&' && src+3<src_end && src[1]=='#' )
      { /* check "&#ddddd;" */
	int num = 0;
	unsigned char* ptr = src+2;
	const unsigned char* ptr_end = ptr+8<src_end ? ptr+8 : src_end;
	for( ; ptr<ptr_end; ++ptr )
	{
	  if( *ptr==';' ) break;
	  if( *ptr<'0' || '9'<*ptr ) break;
	  num = num*10 + *ptr-'0';
	}
	if( ptr<ptr_end && *ptr==';' && 0xf800<=num && num<=0xf9ff )
	{ /* yes, this is "&#ddddd;" */
	  const unsigned char* emoji = (unsigned char*)&g_ei2u2_table[num&0x1ff];
	  if( emoji[3] )
	  {
	    /*fprintf(stderr,"utf8-len: [%d]\n",4); */
	    SV_Buf_append_ch4(&result,*(int*)emoji);
	    src = ptr+1;
	    continue;
	  }
	}
      }
      SV_Buf_append_ch(&result,*src);
      ++src;
      continue;
    }else if( 0xa1<=src[0] && src[0]<=0xdf )
    { /* half-width katakana (ja:半角カナ) */
      ECHO_U2S((stderr,"kana: %02x\n",src[0]));
      ptr = (unsigned char*)&g_s2u_table[(src[0]-0xa1)*3];
      ++src;
    }else if( src+1<src_end && 0x81<=src[0] && src[0]<=0x9f )
    { /* a double-byte letter (ja:2バイト文字) */
      const unsigned short sjis = ntohs(*(unsigned short*)src);
      ECHO_U2S((stderr,"sjis.dbcs#1: %04x\n",sjis));
      ptr = (unsigned char*)&g_s2u_table[(sjis - 0x8100 + 0x3f)*3];
      src += 2;
    }else if( src+1<src_end && ( src[0]==0xf8 || src[0]==0xf9 ) )
    { /* i-mode emoji */
      ECHO_S2U((stderr,"code: %02x %02x\n", src[0],src[1]));
      ptr = (unsigned char*)&g_ei2u2_table[((src[0]&1)<<8)|src[1]];
      if( *(UJ_UINT32*)ptr!=0 )
      {
        SV_Buf_append_ch4(&result,*(UJ_UINT32*)ptr);
        src += 2;
        continue;
      }else
      {
        const unsigned short sjis = ntohs(*(unsigned short*)src);
        ECHO_U2S((stderr,"sjis.dbcs#2: %04x\n",sjis));
        ptr = (unsigned char*)&g_s2u_table[(sjis- 0xe000 + 0x1f3f)*3];
        src += 2;
      }
    }else if( src+1<src_end && 0xe0<=src[0] && src[0]<=0xfc )
    { /* a double-byte letter (ja:2バイト文字) */
      const unsigned short sjis = ntohs(*(unsigned short*)src);
      ECHO_U2S((stderr,"sjis.dbcs#2: %04x\n",sjis));
      ptr = (unsigned char*)&g_s2u_table[(sjis- 0xe000 + 0x1f3f)*3];
      src += 2;
    }else
    { /* unknown */
      /*fprintf(stderr,"unknown: %02x\n",src[0]); */
      SV_Buf_append_ch(&result,'?');
      ++src;
      continue;
    }

    ECHO_U2S((stderr,"offset: 0x%04x\n",ptr-g_s2u_table));
    ECHO_U2S((stderr,"utf8-char : %02x %02x %02x\n",ptr[0],ptr[1],ptr[2]));
    if( ptr[2] )
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
  ON_S2U( bin_dump("out",SV_Buf_getBegin(&result),SV_Buf_getLength(&result)) );
#endif
  SV_Buf_setLength(&result);

  return SV_Buf_getSv(&result);
}


/* ---------------------------------------------------------------------------
 * utf8 ==> imode2
 * ------------------------------------------------------------------------- */
EXTERN_C
SV*
xs_utf8_sjis_imode2(SV* sv_str)
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

  ECHO_U2S((stderr,"Unicode::Japanese::(xs)utf8_sjis_imode1\n"));
  ON_U2S( bin_dump("in ",src,len) );

  SV_Buf_init(&result,len+4);
  src_end = src+len;

  while( src<src_end )
  {
    UJ_UINT32 ucs;
    const UJ_UINT8* sjis_ptr;
    
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
    { /* 3byte range. mostly enter here. */
      const int          utf8_len = 3;
      const unsigned int ucs_min  = 0x800;
      const unsigned int ucs_max  = 0xffff;
      ECHO_U2S((stderr,"utf8-len: [%d]\n",utf8_len));
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
      ECHO_U2S((stderr,"utf8-len: [%d]\n",utf8_len));
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
        const unsigned char* sjis;
        if( ucs<0x0fe000 )
        { /* unknown area. */
	  SV_Buf_append_ch(&result,'?');
	  continue;
        }
        /* imode */
        sjis = (unsigned char*)&g_eu2i2_table[ucs - 0x0fe000];
        if( sjis[1]!=0 )
        { /* double-byte char */
	  SV_Buf_append_ch2(&result,*(const unsigned short*)(sjis));
        }else if( sjis[0]!=0 )
        { /* single-byte char, is it exists?? */
	  SV_Buf_append_ch(&result,*sjis);
        }else
        { /* no mapping */
	  SV_Buf_append_ch(&result,'?');
        }
        continue;
      }
      
      /* > U+10FFFF not supported by UTF-8 (RFC 3629). */
      if( ucs>0x10FFFF )
      {
        SV_Buf_append_ch(&result,'?');
        continue;
      }
    }else if( 0xc0<=*src && *src<=0xdf )
    {
      const int          utf8_len = 2;
      const unsigned int ucs_min  =  0x80;
      const unsigned int ucs_max  = 0x7ff;
      ECHO_U2S((stderr,"utf8-len: [%d]\n",utf8_len));
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
      ECHO_U2S((stderr,"utf8-len: [%d]\n",utf8_len));
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
          && 0x80<=src[3] && src[3]<=0xbf && 0x80<=src[4] && src[4]<=0xbf )
      { /* noop */
      }else
      {
        SV_Buf_append_ch(&result,'?');
        ++src;
        continue;
      }
      
      /* compute code point */
      /* > U+10FFFF not supported by UTF-8 (RFC 3629). */
      src += utf8_len;
      SV_Buf_append_ch(&result,'?');
      continue;
    }else if( 0xfc<=*src && *src<=0xfd )
    {
      const int          utf8_len = 6;
      ECHO_U2S((stderr,"utf8-len: [%d]\n",utf8_len));
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
      /* > U+10FFFF not supported by UTF-8 (RFC 3629). */
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
    ECHO_U2S((stderr,"ucs [%04x]\n",ucs));
    if( ucs<=0x9FFF ) 
    {
      sjis_ptr = g_u2s_table + ucs*2;
    }else if( 0xF900<=ucs && ucs<=0xFFFF )
    {
      sjis_ptr = g_u2s_table + (ucs - 0xF900 + 0xA000)*2;
    }else if( 0x0FE000<=ucs && ucs<=0x0FFFFF )
    {
      sjis_ptr = "?"; /* exactly 2byte: "?\0" */
    }else
    {
      sjis_ptr = "\0"; /* exactly 2byte: "\0\0" */
    }
    if( *(const UJ_UINT16*)sjis_ptr != 0 )
    { /* mapping dest exists. */
      if( sjis_ptr[1]!=0 )
      {
        SV_Buf_append_ch2(&result,*(UJ_UINT16*)sjis_ptr);
      }else
      {
        SV_Buf_append_ch(&result,sjis_ptr[0]);
      }
    }else if( ucs<=0x7F )
    {
      SV_Buf_append_ch(&result,(unsigned char)ucs);
    }else
    {
      SV_Buf_append_ch(&result,'?');
    }
  } /* while */

  ON_U2S( bin_dump("out",SV_Buf_getBegin(&result),SV_Buf_getLength(&result)) );
  SV_Buf_setLength(&result);

  return SV_Buf_getSv(&result);
}

/* ----------------------------------------------------------------------------
 * End of File.
 * ------------------------------------------------------------------------- */

