
// $Id: conv.cpp,v 1.9 2002/02/27 11:59:53 hio Exp $

#include <stdio.h>
#include "Japanese.h"
#include <netinet/in.h>

#define DISP_S2U 0
#define DISP_U2S 0

#if DISP_U2S
#define ECHO_U2S(arg) fprintf arg
#define ON_U2S(cmd) cmd
#else
#define ECHO_U2S(arg)
#define ON_U2S(cmd)
#endif

EXTERN_C
SV*
xs_sjis_utf8(SV* sv_str)
{
  if( sv_str==&PL_sv_undef )
  {
    return newSVsv(&PL_sv_undef);
  }
  STRLEN src_len;
  unsigned char* src = (unsigned char*)SvPV(sv_str,src_len);
  int len = sv_len(sv_str);

#if DISP_S2U
  fprintf(stderr,"Unicode::Japanese::(xs)sjis_utf8\n",len);
  bin_dump("in ",src,len);
#endif

  //asm volatile(".int 3");
  SV_Buf result(len*3/2+4);
  const unsigned char* src_end = src+len;

  while( src<src_end )
  {
    const unsigned char* ptr;
    if( src[0]<0x80 )
    { // ASCII
      //fprintf(stderr,"ascii: %02x\n",src[0]);
      result.append(*src++);
      continue;
    }else if( 0xa1<=src[0] && src[0]<=0xdf )
    { // 半角カナ
      //fprintf(stderr,"kana": %02x\n",src[0]);
      ptr = (unsigned char*)&g_s2u_table[src[0]];
      ++src;
    }else if( ((0x81<=src[0] && src[0]<=0x9f) || (0xe0<=src[0] && src[0]<=0xef) )
	      && (0x40<=src[1] && src[1]<=0xfc && src[1]!=0x7f) )
    { // 2バイト文字
      unsigned short sjis = ntohs(*(unsigned short*)src);
      //fprintf(stderr,"sjis: %04x\n",sjis);
      ptr = (unsigned char*)&g_s2u_table[sjis];
      src += 2;
    }else
    { // 不明
      //fprintf(stderr,"unknown: %02x\n",src[0]);
      result.append('?');
      ++src;
      continue;
    }

    //fprintf(stderr,"utf8-char : %02x %02x %02x\n",ptr[0],ptr[1],ptr[2]);
    if( ptr[2] )
    {
      //fprintf(stderr,"utf8-len: [%d]\n",3);
      result.append_ch3(*(int*)ptr);
    }else if( ptr[1] )
    {
      //fprintf(stderr,"utf8-len: [%d]\n",2);
      result.append_ch2(*(short*)ptr);
    }else
    {
      //fprintf(stderr,"utf8-len: [%d]\n",1);
      result.append(*ptr);
    }
  }
#if DISP_S2U
  bin_dump("out",result.getBegin(),result.getLength());
#endif
  result.setLength();

  return result.getSv();
}

EXTERN_C
SV*
xs_utf8_sjis(SV* sv_str)
{
  if( sv_str==&PL_sv_undef )
  {
    return newSVsv(&PL_sv_undef);
  }
  unsigned char* src = (unsigned char*)SvPV(sv_str,PL_na);
  int len = sv_len(sv_str);

  ECHO_U2S((stderr,"Unicode::Japanese::(xs)utf8_sjis\n"));
  ON_U2S( bin_dump("in ",src,len) );

  SV_Buf result(len+4);
  const unsigned char* src_end = src+len;

  while( src<src_end )
  {
    if( *src<=0x7f )
    {
      int len = 1;
      while( src+len<src_end && src[len]<=0x7f )
      {
	++len;
      }
      result.append(src,len);
      src+=len;
      continue;
    }
    int utf8_len;
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
      result.append(*src++);
      continue;
    }
    if( src+utf8_len-1>=src_end )
    {
      ECHO_U2S((stderr,"  no enough buffer, here is %d, need %d\n",src_end-src,utf8_len));
      result.append(*src++);
      continue;
    }
    bool succ = true;
    for( int i=1; i<utf8_len; ++i )
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
      result.append(*src++);
      continue;
    }
    ECHO_U2S((stderr,"utf8-charlen: [%d]\n",utf8_len));
    unsigned int ucs2;
    switch(utf8_len)
    {
    case 2:
      {
	ucs2 = ((src[0] & 0x1F)<<6)|(src[1] & 0x3F);
	break;
      }
    case 3:
      {
	ucs2 = ((src[0] & 0x0F)<<12)|((src[1] & 0x3F)<<6)|(src[2] & 0x3F);
	break;
      }
    case 4:
      {
	ucs2 = ((src[0] & 0x07)<<18)|((src[1] & 0x3F)<<12)|
	  ((src[2] & 0x3f) << 6)|(src[3] & 0x3F);
	break;
      }
    default:
      {
	ECHO_U2S((stderr,"utf8-charlen %d is not supported\n",utf8_len));
	result.append(*src++);
	continue;
      }
    }
    ECHO_U2S((stderr,"ucs2 [%04x]\n",ucs2));
    unsigned short sjis;
    if( ucs2<=0xFFFF )
    {
      sjis = g_u2s_table[ucs2];
    }else
    {
      sjis = '?';
    }
    ECHO_U2S((stderr,"sjis [%04x]\n",ntohs(sjis) ));
    if( sjis || !ucs2 )
    {
      if( sjis & 0xff00 )
      {
	result.append_ch2(sjis);
      }else
      {
	result.append((unsigned char)sjis);
      }
    }else
    {
      char buf[32];
      //fprintf(stderr,"outrange: [&#%d;]\n",ucs2);
      int write_len = snprintf(buf,32,"&#%d;",ucs2);
      if( write_len==-1 )
      {
	result.append(*src++);
	continue;
      }
      result.append((unsigned char*)buf,write_len);
    }
    src += utf8_len;
    //bin_dump("now",dst_begin,dst-dst_begin);
  } /* for */

  ON_U2S( bin_dump("out",result.getBegin(),result.getLength()) );
  result.setLength();

  return result.getSv();
}
