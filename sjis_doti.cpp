
/* $Id: sjis_doti.cpp,v 1.2 2001/12/28 02:19:38 hio Exp $ */

#include <stdio.h>
#include "Japanese.h"

EXTERN_C
SV*
xs_sjis_doti_utf8(SV* sv_str)
{
  if( sv_str==&PL_sv_undef )
  {
    return newSVsv(&PL_sv_undef);
  }
  unsigned char* src = (unsigned char*)SvPV(sv_str,PL_na);
  int len = sv_len(sv_str);

  //fprintf(stderr,"Unicode::Japanese::(xs)sjis_doti_utf8\n",len);
  //bin_dump("in ",src,len);

  SV_Buf result(len*3/2+4);
  const unsigned char* src_end = src+len;

  while( src<src_end )
  {
    const unsigned char* ptr;
    if( src[0]<0x80 )
    { // ASCII
      //fprintf(stderr,"ascii: %02x\n",src[0]);
      if( src[0]=='&' && src+3<src_end && src[1]=='#' )
      { // "&#ooooo;"のチェック
	int num = 0;
	unsigned char* ptr = src+2;
	const unsigned char* ptr_end = ptr+8<src_end ? ptr+8 : src_end;
	for( ; ptr<ptr_end; ++ptr )
	{
	  if( *ptr==';' ) break;
	  if( *ptr<'0' || '9'<*ptr ) break;
	  num = num*10 + *ptr-'0';
	}
	if( ptr<ptr_end && *ptr==';' && 0xf000<=num && num<=0xf4ff )
	{ // &#oooo;表記のdot-i絵文字
	  const unsigned char* emoji = (unsigned char*)&g_ed2u_table[num-0xf000];
	  if( emoji[3] )
	  {
	    //fprintf(stderr,"utf8-len: [%d]\n",4);
	    result.append(emoji,4);
	    src = ptr;
	    continue;
	  }
	}
      }
	
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
    }else if( src+1<src_end && ( 0xf0<=src[0] && src[0]<=0xf4 ) )
    { // dot-i絵文字
      ptr = (unsigned char*)&g_ed2u_table[((src[0]&0x07)<<8)|src[1]];
      if( ptr[3] )
      {
	//fprintf(stderr,"utf8-len: [%d]\n",4);
	result.append(ptr,4);
	src += 2;
	continue;
      }
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
  //bin_dump("out",result.getBegin(),result.getLength());
  result.setLength();

  return result.getSv();
}

EXTERN_C
SV*
xs_utf8_sjis_doti(SV* sv_str)
{
  if( sv_str==&PL_sv_undef )
  {
    return newSVsv(&PL_sv_undef);
  }
  unsigned char* src = (unsigned char*)SvPV(sv_str,PL_na);
  int len = sv_len(sv_str);

  //fprintf(stderr,"Unicode::Japanese::(xs)utf8_sjis_doti\n");
  //bin_dump("in ",src,len);
  
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
    int utf8_len,ucs2;
    if( 0xc0<=*src && *src<=0xdf )
    { // length [2]
      utf8_len = 2;
      if( src+1>=src_end ||
	  src[1]<0x80 || 0xbf<src[1] )
      {
	result.append(*src++);
	continue;
      }
      ucs2 = ((src[0] & 0x1F)<<6)|(src[1] & 0x3F);
    }else if( 0xe0<=*src && *src<=0xef )
    { // length [3]
      utf8_len = 3;
      if( src+2>=src_end ||
	  src[1]<0x80 || 0xbf<src[1] ||
	  src[2]<0x80 || 0xbf<src[2] )
      {
	result.append(*src++);
	continue;
      }
      ucs2 = ((src[0] & 0x0F)<<12)|((src[1] & 0x3F)<<6)|(src[2] & 0x3F);
    }else if( 0xf0<=*src && *src<=0xf7 )
    { // length [4]
      utf8_len = 4;
      if( src+3>=src_end ||
	  src[1]<0x80 || 0xbf<src[1] ||
	  src[2]<0x80 || 0xbf<src[2] ||
	  src[3]<0x80 || 0xbf<src[3] )
      {
	result.append(*src++);
	continue;
      }
      ucs2 = ((src[0] & 0x07)<<18)|((src[1] & 0x3F)<<12)|
	((src[2] & 0x3f) << 6)|(src[3] & 0x3F);
      if( 0x0ff000<=ucs2 && ucs2<=0x0fffff )
      { // 先に絵文字判定
	unsigned short sjis = g_eu2d_table[ucs2 - 0x0ff000];
	if( sjis!=0 )
        {
	  //fprintf(stderr,"  ucs2 [%04x]\n",ucs2);
	  //fprintf(stderr,"  code: [%04x]\n",ucs2 - 0x0ff000);
	  //fprintf(stderr,"  emoji:%02x%02x\n",sjis&0xff,(sjis>>8)&0xff);
	  result.append_ch2(sjis);
	  src += 4;
	  continue;
	}
      }
    }else if( 0xf8<=*src && *src<=0xfb )
    { // length [5]
      utf8_len = 5;
      if( src+4>=src_end ||
	  src[1]<0x80 || 0xbf<src[1] ||
	  src[2]<0x80 || 0xbf<src[2] ||
	  src[3]<0x80 || 0xbf<src[3] ||
	  src[4]<0x80 || 0xbf<src[4] )
      {
	result.append(*src++);
	continue;
      }
      // not supported.
      result.append(*src++);
      continue;
    }else if( 0xfc<=*src && *src<=0xfd )
    { // length [6]
      utf8_len = 6;
      if( src+5>=src_end ||
	  src[1]<0x80 || 0xbf<src[1] ||
	  src[2]<0x80 || 0xbf<src[2] ||
	  src[3]<0x80 || 0xbf<src[3] ||
	  src[4]<0x80 || 0xbf<src[4] ||
	  src[5]<0x80 || 0xbf<src[5] )
      {
	result.append(*src++);
	continue;
      }
      // not supported.
      result.append(*src++);
      continue;
    }else
    { // invalid
      result.append(*src++);
      continue;
    }

    //fprintf(stderr,"utf8-charlen: [%d]\n",utf8_len);
    //fprintf(stderr,"ucs2 [%04x]\n",ucs2);
    unsigned short sjis = g_u2s_table[ucs2];
    //fprintf(stderr,"sjis [%04x]\n",sjis);
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
      result.append((unsigned char)'?');
    }
    src += utf8_len;
    //bin_dump("now",dst_begin,dst-dst_begin);
  } /* for */

  //bin_dump("out",result.getBegin(),result.getLength());
  result.setLength();

  return result.getSv();
}
