
// $Id: sjis_jsky.cpp,v 1.6 2002/02/27 11:59:53 hio Exp $

#include <stdio.h>
#include "Japanese.h"

#define ECHO_EJ2U(arg) //fprintf arg
#define ON_EJ2U(cmd) //cmd
#define ECHO_U2EJ(arg) //fprintf arg
#define ON_U2EJ(cmd) //cmd

EXTERN_C
SV*
xs_sjis_jsky_utf8(SV* sv_str)
{
  if( sv_str==&PL_sv_undef )
  {
    return newSVsv(&PL_sv_undef);
  }
  const unsigned char* src = (unsigned char*)SvPV(sv_str,PL_na);
  int len = sv_len(sv_str);

  ECHO_EJ2U((stderr,"Unicode::Japanese::(xs)sjis_jsky_utf8\n",len));
  ON_EJ2U( bin_dump("in ",src,len) );

  SV_Buf result(len*3/2+4);
  const unsigned char* src_end = src+len;

  while( src<src_end )
  {
    const unsigned char* ptr;
    if( src[0]<0x80 )
    { // ASCII
      //fprintf(stderr,"ascii: %02x\n",src[0]);
      if( src[0]!='\e' || src+2>=src_end || src[1]!='$' )
      { // 絵文字じゃない
	result.append(*src++);
	continue;
      }
      //fprint(stderr,"detect j-sky emoji-start escape\n");
      // E_JSKY_1
      if( src[2]!='E' && src[2]!='F' && src[2]!='G' )
      {
	//fprintf(stderr,"first char is invalid");
	result.append(*src++);
	continue;
      }

      const unsigned char* begin = src;
      src += 3;
      // E_JSKY_2
      while( src+1<src_end )
      {
	if( '!'<=src[0] && src[0]<='z' )
	{
	  ++src;
	  continue;
	}
	break;
      }
      if( src[0]!=0x0f )
      {
	//fprintf(stderr,"invalid\n");
	src = begin;
	result.append(*src++);
	continue;
      }
      ++src;
      const int j1 = (begin[2]-'E')<<8;
      for( const unsigned char* ptr = begin+3; ptr<src-1; ++ptr )
      {
	//fprintf(stderr," <%c%c:%04x>\n",begin[2],*ptr,j1+*ptr);
	//fprintf(stderr,"   => %04x\n",g_ej2u_table[j1+*ptr]);
	const unsigned char* str = (unsigned char*)&g_ej2u_table[j1+*ptr];
	//fprintf(stderr,"   len: %d\n",str[3]?4:strlen((char*)str));
	result.append(str,str[3]?4:strlen((char*)str));
      }
      //fprintf(stderr,"j-sky string done.\n");
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
  ON_EJ2U( bin_dump("out",result.getBegin(),result.getLength()) );
  result.setLength();

  return result.getSv();
}


EXTERN_C
SV*
xs_utf8_sjis_jsky(SV* sv_str)
{
  if( sv_str==&PL_sv_undef )
  {
    return newSVsv(&PL_sv_undef);
  }
  unsigned char* src = (unsigned char*)SvPV(sv_str,PL_na);
  int len = sv_len(sv_str);

  ECHO_U2EJ((stderr,"Unicode::Japanese::(xs)utf8_sjis_jsky\n"));
  ON_U2EJ( bin_dump("in ",src,len) );
  
  SV_Buf result(len+4);
  const unsigned char* src_end = src+len;
  const unsigned char* src_begin = src;

  while( src<src_end )
  {
    //fprintf(stderr,"(try) %02x\n",*src);
    if( *src<=0x7f )
    {
      int utf8_len = 1;
      while( src+utf8_len<src_end && src[utf8_len]<=0x7f )
      {
	++utf8_len;
      }
      result.append(src,utf8_len);
      src+=utf8_len;
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
      //fprintf(stderr," [len:4] ucs4: %06x\n",ucs2);
      if( 0x0ff000<=ucs2 && ucs2<=0x0fffff )
      { // 先に絵文字判定
	const unsigned char* sjis = &g_eu2j_table[(ucs2 - 0x0ff000)*5];
	//fprintf(stderr,"  emoji: %02x %02x %02x %02x %02x\n",
	//	  sjis[0],sjis[1],sjis[2],sjis[3],sjis[4]);
	if( sjis[0]!=0 )
	{
	  result.append(sjis,sjis[4]?5:strlen((const char*)sjis));
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
    //fprintf(stderr,"sjis [%04x=>%04x]\n",htons(ucs2),ntohs(g_u2s_table[htons(ucs2)]));
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
  //fprintf(stderr,"  utf8 => sjis(j-sky) completed\n");
  //bin_dump("tmp",result.getBegin(),result.getLength());

  // packing J-SKY emoji escapes
  SV_Buf pack(result.getLength());
  src = result.getBegin();
  src_end = src + result.getLength();
  unsigned char* ptr = src;
  for( ; src+5*2-1<src_end; ++src )
  {
    // E_JSKY_START  "\e\$",
    if( src[0]!='\x1b' ) continue;
    if( src[1]!='$' ) continue;
    // E_JSKY1   '[EFG]',
    //fprintf(stderr,"  found emoji-start\n");
    if( src[2]!='E' && src[2]!='F' && src[2]!='G' )
    {
      //fprintf(stderr,"  invalid ch1 [%x:%02x]\n",src[2],src[2]);
      continue;
    }
    unsigned char ch1 = src[2];
    // E_JSKY2    '[\!-\;\=-z\xbc]',
    if( src[3]<'!' || 'z'<src[3] )
    {
      //fprintf(stderr,"  invalid ch2 [%02x]\n",src[3]);
      continue;
    }
    // E_JSKY_END    "\x0f",
    if( src[4]!='\x0f' ) continue;

    //fprintf(stderr,"  found first emoji [%02x:%c]\n",ch1,ch1);
    src += 5;
    pack.append(ptr,(src-1)-ptr);
    unsigned char tmpl[5] = { '\x1b','$',0,0,'\x0f',};
    tmpl[2] = ch1;
    for( ; src_end-src>=5; src+= 5 )
    {
      tmpl[3] = src[3];
      if( memcmp(src,tmpl,5)!=0 ) break;
      //fprintf(stderr,"  packing...[%02x]\n",src[3]);
      pack.append(src[3]);
    }
    //fprintf(stderr,"  pack done.\n");
    pack.append('\x0f');
    ptr = src;
  }
  //fprintf(stderr,"  pack complete.\n");
  //fprintf(stderr,"  append len %0d\n",src_end-ptr);
  if( ptr!=src_end )
  {
    pack.append(ptr,src_end-ptr);
  }

  ON_U2EJ( bin_dump("out",pack.getBegin(),pack.getLength()) );
  pack.setLength();

  return pack.getSv();
}
