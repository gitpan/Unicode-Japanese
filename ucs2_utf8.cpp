
// $Id: ucs2_utf8.cpp,v 1.2 2001/12/28 02:19:39 hio Exp $

#include "Japanese.h"

EXTERN_C
int
ucs2_utf8_ch(const unsigned char* src, unsigned char* buf)
{
  unsigned short ucs2 = ntohs(*(unsigned short*)src);
  if( ucs2<0x80 )
  {
    buf[0] = (unsigned char)ucs2;
    return 1;
  }else if( ucs2<0x800 )
  {
    buf[0] = 0xC0 | (ucs2 >> 6);
    buf[1] = 0x80 | (ucs2 & 0x3F);
    return 2;
  }else
  {
    buf[0] = 0xE0 | (ucs2 >> 12);
    buf[1] = 0x80 | ((ucs2 >> 6) & 0x3F);
    buf[2] = 0x80 | (ucs2 & 0x3F);
    return 3;
  }
}

EXTERN_C
SV*
ucs2_utf8(SV* sv_str)
{
  if( sv_str==&PL_sv_undef )
  {
    return newSVsv(&PL_sv_undef);
  }
  unsigned char* src = (unsigned char*)SvPV(sv_str,PL_na);
  int len = sv_len(sv_str);

  //fprintf(stderr,"Unicode::Japanese::(xs)sjis_utf8\n",len);
  //bin_dump("in ",src,len);

  //asm volatile(".int 3");
  SV_Buf result(len*3/2+4);
  const unsigned char* src_end = src+len;

  while( src<src_end )
  {
    fputs("Unicode::Japanese::(xs)ucs2_utf8, not available yet.\n",stderr);
    break;
  }
  //bin_dump("out",result.getBegin(),result.getLength());
  result.setLength();

  return result.getSv();
}
