
/* $Id: jis.c,v 1.3 2002/10/31 11:08:50 hio Exp $ */

#include "Japanese.h"
#include "sjis.h"

#define S2J_DISP 0
#define J2S_DISP 0

#define JIS_0208 ((const unsigned char*)"\x1b$B")
#define JIS_0212 ((const unsigned char*)"\x1b$(D")
#define JIS_ASC  ((const unsigned char*)"\x1b(B")
#define JIS_KANA ((const unsigned char*)"\x1b(I")
#define JIS_0208_LEN 3
#define JIS_0212_LEN 4
#define JIS_ASC_LEN  3
#define JIS_KANA_LEN 3

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */
/* sjis=>jis変換 */
EXTERN_C
SV*
xs_sjis_jis(SV* sv_str)
{
  unsigned char* src;
  int len;
  SV_Buf result;
  int esc_asc;
  const unsigned char* src_end;

  if( sv_str==&PL_sv_undef )
  {
    return newSVsv(&PL_sv_undef);
  }
  
  src = (unsigned char*)SvPV(sv_str,PL_na);
  len = sv_len(sv_str);
  /*fprintf(stderr,"Unicode::Japanese::(xs)sjis_jis\n",len); */
  /*bin_dump("in ",src,len); */
  SV_Buf_init(&result,len+8);
  esc_asc = 1;
  src_end = src+len;

  while( src<src_end )
  {
    switch(chk_sjis[*src])
    {
    case CHK_SJIS_THROUGH:
      { /* SJIS:THROUGH => JIS:ASCII */
	const unsigned char* begin;
	if( !esc_asc )
	{
	  SV_Buf_append_str(&result,JIS_ASC,JIS_ASC_LEN);
	  esc_asc = 1;
	}
#if TEST && S2J_DISP
	fprintf(stderr,"  (throuh) %c[%02x]",*src,*src);
	fflush(stderr);
#endif
	begin = src;
	while( ++src<src_end && chk_sjis[*src]==CHK_SJIS_THROUGH )
	{
#if TEST && S2J_DISP
	  fprintf(stderr," %c[%02x]",*src,*src);
	  fflush(stderr);
#endif
	}
#if TEST && S2J_DISP
	fprintf(stderr,"\n");
	fflush(stderr);
#endif
	SV_Buf_append_str(&result,begin,src-begin);
	break;
      }
    case CHK_SJIS_C:
      {
	SV_Buf_append_str(&result,JIS_0208,JIS_0208_LEN);
	esc_asc = 0;
#if TEST && S2J_DISP
	fprintf(stderr,"  (sjis:c)");
	fflush(stderr);
#endif
	do
	{
	  unsigned char tmp[2];
#if TEST && S2J_DISP
	  fprintf(stderr, "%c%c[%02x.%02x]",src[0],src[1],src[0],src[1]);
	  fflush(stderr);
#endif
	  if( src[1]<0x40 || 0xfc<src[1] || src[1]==0x7f )
	  {
#if TEST && S2J_DISP
	    fprintf(stderr, "*");
	    fflush(stderr);
#endif
	    SV_Buf_append_str(&result,UNDEF_JIS,UNDEF_JIS_LEN);
	    ++src;
	    break;
	  }
	  if( 0x9f <= src[1] )
	  {
	    tmp[0] = src[0]*2 - (src[0]>=0xe0 ? 0xe0 : 0x60);
	    tmp[1] = src[1] + 2;
	  }else
	  {
	    tmp[0] = src[0]*2 - (src[0]>=0xe0 ? 0xe1 : 0x61);
	    tmp[1] = src[1] + 0x60 + (src[1] < 0x7f);
	  }
	  tmp[0] &= 0x7f;
	  tmp[1] &= 0x7f;
	  SV_Buf_append_ch2(&result,*(unsigned short*)tmp);
	  src += 2;
	}while( src<src_end && chk_sjis[*src]==CHK_SJIS_C );
#if TEST && S2J_DISP
	fprintf(stderr,"\n");
#endif
	break;
      }
    case CHK_SJIS_KANA:
      { /* SJIS:KANA => JIS:KANA */
	SV_Buf_append_str(&result,JIS_KANA,JIS_KANA_LEN);
	esc_asc = 0;
#if TEST && S2J_DISP
	fprintf(stderr,"  (sjis:kana)");
	fflush(stderr);
#endif
	esc_asc = 0;
        do
	{
#if TEST && S2J_DISP
	  fprintf(stderr," %02x",*src);
	  fflush(stderr);
#endif
	  SV_Buf_append_ch(&result,*src&0x7f);
	}while( ++src<src_end && chk_sjis[*src]==CHK_SJIS_KANA );
#if TEST && S2J_DISP
	fprintf(stderr,"\n");
#endif
	break;
      }
    default:
      {
#ifdef TEST
	fprintf(stderr,"xs_sjis_eucjp, unknown check-code[%02x] on char-code[%05x]\n",chk_sjis[*src],*src);
#endif
	SV_Buf_append_ch(&result,*src);
	++src;
      }
    } /*switch */
  } /*while */

  if( !esc_asc )
  {
    SV_Buf_append_str(&result,JIS_ASC,JIS_ASC_LEN);
  }
  /*bin_dump("out",result.getBegin(),result.getLength()); */
  SV_Buf_setLength(&result);

  return SV_Buf_getSv(&result);
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */
/* jis=>sjis変換 */
EXTERN_C
SV*
xs_jis_sjis(SV* sv_str)
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
  /*fprintf(stderr,"Unicode::Japanese::(xs)jis_sjis\n",len); */
  /*bin_dump("in ",src,len); */
  SV_Buf_init(&result,len);
  src_end = src+len;
  
  if( *src!='\x1b' )
  {
    const unsigned char* begin = src;
    while( ++src<src_end && *src!='\x1b')
    {
    }
    SV_Buf_append_str(&result,begin,src-begin);
  }
  while( src<src_end )
  {
#if TEST && J2S_DISP
    fprintf(stderr,"  len: %d\n",src_end-src);
#endif
    if( src_end-src>=JIS_ASC_LEN && memcmp(src,JIS_ASC,JIS_ASC_LEN)==0 )
    { /* <<jis.asc>> */
      const unsigned char* begin;
      /*fprintf(stderr,"  <jis.asc>\n"); */
      src += JIS_ASC_LEN;
      begin = src;
      while( src<src_end && *src!='\x1b')
      {
	++src;
      }
      if( src!=begin )
      {
	SV_Buf_append_str(&result,begin,src-begin);
      }
    }else if( src_end-src>=JIS_0212_LEN && memcmp(src,JIS_0212,JIS_0212_LEN)==0 )
    { /* <<jis.0212>> */
      const unsigned char* begin;
      int i;
      /*fprintf(stderr,"  <jis.0212>\n"); */
      src += JIS_0212_LEN;
      begin = src;
      while( src<src_end && *src!='\x1b')
      {
	++src;
      }
      for( i=0; i<(src-begin)/2; ++i )
      {
	SV_Buf_append_str(&result,UNDEF_SJIS,UNDEF_SJIS_LEN);
      }
    }else if( src_end-src>=JIS_KANA_LEN && memcmp(src,JIS_KANA,JIS_KANA_LEN)==0 )
    { /* <<jis.kana>> */
      /*fprintf(stderr,"  <jis.kana>\n"); */
      src += JIS_KANA_LEN;
      while( src<src_end && *src!='\x1b')
      {
	SV_Buf_append_ch(&result,*src|0x80);
	++src;
      }
    }else if( src_end-src>=JIS_0208_LEN && memcmp(src,JIS_0208,JIS_0208_LEN)==0 )
    { /* <<jis.0208>> */
#if TEST && J2S_DISP
      fprintf(stderr,"  <jis.c>"),fflush(stderr);
#endif
      src += JIS_0208_LEN;
      while( src<src_end )
      {
	unsigned char tmp[2];
	if( *src=='\x1b' ) break;
#if TEST && J2S_DISP
	fprintf(stderr," %02x",src[0]),fflush(stderr);
#endif
        if( src+1==src_end || src[1]=='\x1b' )
	{
#if TEST && J2S_DISP
	  fprintf(stderr,"*"),fflush(stderr);
#endif
	  ++src;
	  SV_Buf_append_str(&result,UNDEF_SJIS,UNDEF_SJIS_LEN);
	  break;
	}
#if TEST && J2S_DISP
	fprintf(stderr," %02x",src[0]),fflush(stderr);
#endif
	tmp[0] = src[0] | 0x80;
	tmp[1] = src[1] | 0x80;
	if( src[0]%2 )
	{
	  tmp[0] = (tmp[0]>>1) + (tmp[0] < 0xdf ? 0x31 : 0x71);
	  tmp[1] = tmp[1] - ( 0x60 + (tmp[1] < 0xe0) );
	}else
	{
	  tmp[0] = (tmp[0]>>1) + (tmp[0] < 0xdf ? 0x30 : 0x70);
	  tmp[1] = tmp[1] - 2;
	}
	SV_Buf_append_ch2(&result,*(unsigned short*)tmp);
	src += 2;
      }
#if TEST && J2S_DISP
      fprintf(stderr,"\n");
#endif
    }else
    { /* <<jis.???>> */
#ifdef TEST
      fprintf(stderr,"xs_jis_sjis, unknown escape found\n");
#if J2S_DISP
      fprintf(stderr,"  len: %d\n  src: %02x %02x %02x\n",src_end-src,src[0],src[1],src[2]);
#endif
#endif
      SV_Buf_append_ch(&result,*src);
      ++src;
    }
  } /*while */

  /*bin_dump("out",result.getBegin(),result.getLength()); */
  SV_Buf_setLength(&result);

  return SV_Buf_getSv(&result);
}
