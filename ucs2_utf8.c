
// $Id: ucs2_utf8.c,v 1.2 2002/10/30 01:12:21 hio Exp $

#include "Japanese.h"

/*
 * ucs2=>utf8Ê¸»úÎóÊÑ´¹
 */
EXTERN_C
SV*
xs_ucs2_utf8(SV* sv_str)
{
  unsigned char* src;
  int len;
  SV_Buf result;
  const unsigned char* src_end;
  unsigned char buf[4];

  if( sv_str==&PL_sv_undef )
  {
    return newSVpvn("",0);
  }
  
  src = (unsigned char*)SvPV(sv_str,PL_na);
  len = sv_len(sv_str);
  src_end = src+(len&~1);
  /*fprintf(stderr,"Unicode::Japanese::(xs)ucs2_utf8\n",len);*/
  /*bin_dump("in ",src,len);*/
  SV_Buf_init(&result,len*3/2+4);

  if( len&1 )
  {
    Perl_croak(aTHX_ "Unicode::Japanese::ucs2_utf8, invalid length (not 2*n)");
  }

  for(; src<src_end; src+=2 )
  {
    const unsigned short ucs2 = ntohs(*(unsigned short*)src);
    if( ucs2<0x80 )
    {
      SV_Buf_append_ch(&result,(unsigned char)ucs2);
    }else if( ucs2<0x800 )
    {
      buf[0] = 0xC0 | (ucs2 >> 6);
      buf[1] = 0x80 | (ucs2 & 0x3F);
      SV_Buf_append_ch2(&result,*(unsigned short*)buf);
    }else
    {
      buf[0] = 0xE0 | (ucs2 >> 12);
      buf[1] = 0x80 | ((ucs2 >> 6) & 0x3F);
      buf[2] = 0x80 | (ucs2 & 0x3F);
      SV_Buf_append_ch3(&result,*(unsigned int*)buf);
    }
  }

  //bin_dump("out",result.getBegin(),result.getLength());
  SV_Buf_setLength(&result);

  return SV_Buf_getSv(&result);
}

/*
 * utf8=>ucs2Ê¸»úÎóÊÑ´¹
 */
EXTERN_C
SV*
xs_utf8_ucs2(SV* sv_str)
{
  unsigned char* src;
  int len;
  SV_Buf result;
  const unsigned char* src_end;

  if( sv_str==&PL_sv_undef )
  {
    return newSVpvn("",0);
  }
  
  src = (unsigned char*)SvPV(sv_str,PL_na);
  len = sv_len(sv_str);
  src_end = src+len;
  //fprintf(stderr,"Unicode::Japanese::(xs)utf8_ucs2\n",len);
  //bin_dump("in ",src,len);
  SV_Buf_init(&result,len);

  while( src<src_end )
  {
    int utf8_len,ucs;
    if( *src<=0x7f )
    {
      SV_Buf_append_ch2(&result,htons(*src));
      ++src;
      continue;
    }
    if( 0xc0<=*src && *src<=0xdf )
    { // length [2]
      utf8_len = 2;
      if( src+1>=src_end ||
	  src[1]<0x80 || 0xbf<src[1] )
      {
	SV_Buf_append_ch2(&result,htons(*src));
	++src;
	continue;
      }
      ucs = ((src[0] & 0x1F)<<6)|(src[1] & 0x3F);
    }else if( 0xe0<=*src && *src<=0xef )
    { // length [3]
      utf8_len = 3;
      if( src+2>=src_end ||
	  src[1]<0x80 || 0xbf<src[1] ||
	  src[2]<0x80 || 0xbf<src[2] )
      {
	SV_Buf_append_ch2(&result,htons(*src));
	++src;
	continue;
      }
      ucs = ((src[0] & 0x0F)<<12)|((src[1] & 0x3F)<<6)|(src[2] & 0x3F);
    }else if( 0xf0<=*src && *src<=0xf7 )
    { // length [4]
      utf8_len = 4;
      if( src+3>=src_end ||
	  src[1]<0x80 || 0xbf<src[1] ||
	  src[2]<0x80 || 0xbf<src[2] ||
	  src[3]<0x80 || 0xbf<src[3] )
      {
	SV_Buf_append_ch2(&result,htons(*src));
	++src;
	continue;
      }
      ucs = ((src[0] & 0x07)<<18)|((src[1] & 0x3F)<<12)|
 	    ((src[2] & 0x3f) << 6)|(src[3] & 0x3F);
    }else if( 0xf8<=*src && *src<=0xfb )
    { // length [5]
      utf8_len = 5;
      if( src+4>=src_end ||
	  src[1]<0x80 || 0xbf<src[1] ||
	  src[2]<0x80 || 0xbf<src[2] ||
	  src[3]<0x80 || 0xbf<src[3] ||
	  src[4]<0x80 || 0xbf<src[4] )
      {
	SV_Buf_append_ch2(&result,htons(*src));
	++src;
	continue;
      }
      ucs = ((src[0] & 0x03) << 24)|((src[1] & 0x3F) << 18)|
	    ((src[2] & 0x3f) << 12)|((src[3] & 0x3f) << 6)|
             (src[4] & 0x3F);
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
	SV_Buf_append_ch2(&result,htons(*src));
	++src;
	continue;
      }
      ucs = ((src[0] & 0x03) << 30)|((src[1] & 0x3F) << 24)|
	    ((src[2] & 0x3f) << 18)|((src[3] & 0x3f) << 12)|
	    ((src[4] & 0x3f) <<  6)| (src[5] & 0x3F);
    }else
    { // invalid
      SV_Buf_append_ch2(&result,htons(*src));
      ++src;
      continue;
    }

    if( ucs & ~0xFFFF )
    { // ucs2¤ÎÈÏ°Ï³° (ucs4¤ÎÈÏ°Ï)
      SV_Buf_append_ch2(&result,htons('?'));
      src += utf8_len;
      continue;
    }
    SV_Buf_append_ch2(&result,htons(ucs));
    src += utf8_len;
    //bin_dump("now",dst_begin,dst-dst_begin);
  }

  //bin_dump("out",result.getBegin(),result.getLength());
  SV_Buf_setLength(&result);

  return SV_Buf_getSv(&result);
}
