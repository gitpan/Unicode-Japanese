
/* $Id: sjis_imode.c,v 1.4 2002/10/31 11:08:50 hio Exp $ */

#include "Japanese.h"
#include <stdio.h>

#ifndef __cplusplus
#undef bool
#undef true
#undef false
typedef enum bool { false, true, } bool;
#endif

/* ---------------------------------------------------------------------------
 * imode1 ==> utf8
 * ------------------------------------------------------------------------- */
EXTERN_C
SV*
xs_sjis_imode1_utf8(SV* sv_str)
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
  /*fprintf(stderr,"Unicode::Japanese::(xs)sjis_imode_utf8[len:%d]\n",len); */
  /*bin_dump("in ",src,len); */
  SV_Buf_init(&result,len*3/2+4);
  src_end = src+len;

  while( src<src_end )
  {
    const unsigned char* ptr;
    if( src[0]<0x80 )
    { /* ASCII */
      /*fprintf(stderr,"ascii: %02x\n",src[0]); */
      if( src[0]=='&' && src+3<src_end && src[1]=='#' )
      { /* "&#ooooo;"�Υ����å� */
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
	{ /* &#oooo;ɽ����i-mode��ʸ�� */
	  const unsigned char* emoji = (unsigned char*)&g_ei2u1_table[num&0x1ff];
	  if( emoji[3] )
	  {
	    /*fprintf(stderr,"utf8-len: [%d]\n",4); */
	    SV_Buf_append_ch4(&result,*(unsigned int*)emoji);
	    src = ptr+1;
	    continue;
	  }
	}
      }
	
      SV_Buf_append_ch(&result,*src);
      ++src;
      continue;
    }else if( 0xa1<=src[0] && src[0]<=0xdf )
    { /* Ⱦ�ѥ��� */
      /*fprintf(stderr,"kana": %02x\n",src[0]); */
      ptr = (unsigned char*)&g_s2u_table[src[0]];
      ++src;
    }else if( src+1<src_end && ( src[0]==0xf8 || src[0]==0xf9 ) )
    { /* i-mode��ʸ�� */
      /*fprintf(stderr,"code: %02x %02x\n", src[0],src[1]); */
      ptr = (unsigned char*)&g_ei2u1_table[((src[0]&1)<<8)|src[1]];
      if( *(unsigned long*)ptr==0 )
      {
	register const unsigned short sjis = ntohs(*(unsigned short*)src);
	/*fprintf(stderr,"sjis: %04x\n",sjis); */
	ptr = (unsigned char*)&g_s2u_table[sjis];
      }
      /*fprintf(stderr,"out : %02x %02x %02x %02x\n",ptr[0],ptr[1],ptr[2],ptr[3]); */
      src += 2;
    }else if( ((0x81<=src[0] && src[0]<=0x9f) || (0xe0<=src[0] && src[0]<=0xfc) )
	      && src+1<src_end
	      && (0x40<=src[1] && src[1]<=0xfc && src[1]!=0x7f) )
    { /* 2�Х���ʸ�� */
      unsigned short sjis = ntohs(*(unsigned short*)src);
      /*fprintf(stderr,"sjis: %04x\n",sjis); */
      ptr = (unsigned char*)&g_s2u_table[sjis];
      src += 2;
    }else
    { /* ���� */
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
  /*bin_dump("out",result.getBegin(),result.getLength()); */
  SV_Buf_setLength(&result);

  return SV_Buf_getSv(&result);
}

/* ---------------------------------------------------------------------------
 * imode2 ==> utf8
 * ------------------------------------------------------------------------- */

EXTERN_C
SV*
xs_sjis_imode2_utf8(SV* sv_str)
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
  /*fprintf(stderr,"Unicode::Japanese::(xs)sjis_imode_utf8[len:%d]\n",len); */
  /*bin_dump("in ",src,len); */
  SV_Buf_init(&result,len*3/2+4);
  src_end = src+len;

  while( src<src_end )
  {
    const unsigned char* ptr;
    if( src[0]<0x80 )
    { /* ASCII */
      /*fprintf(stderr,"ascii: %02x\n",src[0]); */
      if( src[0]=='&' && src+3<src_end && src[1]=='#' )
      { /* "&#ooooo;"�Υ����å� */
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
	{ /* &#oooo;ɽ����i-mode��ʸ�� */
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
    { /* Ⱦ�ѥ��� */
      /*fprintf(stderr,"kana": %02x\n",src[0]); */
      ptr = (unsigned char*)&g_s2u_table[src[0]];
      ++src;
    }else if( src+1<src_end && ( src[0]==0xf8 || src[0]==0xf9 ) )
    { /* i-mode��ʸ�� */
      /*fprintf(stderr,"code: %02x %02x\n", src[0],src[1]); */
      ptr = (unsigned char*)&g_ei2u2_table[((src[0]&1)<<8)|src[1]];
      if( *(unsigned long*)ptr==0 )
      {
	register const unsigned short sjis = ntohs(*(unsigned short*)src);
	/*fprintf(stderr,"sjis: %04x\n",sjis); */
	ptr = (unsigned char*)&g_s2u_table[sjis];
      }
      /*fprintf(stderr,"out : %02x %02x %02x %02x\n",ptr[0],ptr[1],ptr[2],ptr[3]); */
      src += 2;
    }else if( ((0x81<=src[0] && src[0]<=0x9f) || (0xe0<=src[0] && src[0]<=0xfc) )
	      && src+1<src_end
	      && (0x40<=src[1] && src[1]<=0xfc && src[1]!=0x7f) )
    { /* 2�Х���ʸ�� */
      unsigned short sjis = ntohs(*(unsigned short*)src);
      /*fprintf(stderr,"sjis: %04x\n",sjis); */
      ptr = (unsigned char*)&g_s2u_table[sjis];
      src += 2;
    }else
    { /* ���� */
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
  /*bin_dump("out",result.getBegin(),result.getLength()); */
  SV_Buf_setLength(&result);

  return SV_Buf_getSv(&result);
}

/* ---------------------------------------------------------------------------
 * utf8 ==> imode1
 * ------------------------------------------------------------------------- */

EXTERN_C
SV*
xs_utf8_sjis_imode1(SV* sv_str)
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

  /*fprintf(stderr,"Unicode::Japanese::(xs)utf8_sjis_imode\n"); */
  /*ON_U2S( bin_dump("in ",src,len) ); */

  SV_Buf_init(&result,len+4);
  src_end = src+len;

  while( src<src_end )
  {
    int utf8_len;
    bool succ;
    int i;
    unsigned int ucs;
    if( *src<=0x7f )
    {
      /* ASCII�ϤޤȤ���ɲá� */
      int len = 1;
      while( src+len<src_end && src[len]<=0x7f )
      {
	++len;
      }
      SV_Buf_append_str(&result,src,len);
      src+=len;
      continue;
    }
    /* utf8��ucs���Ѵ� */
    /* utf8�Σ�ʸ����Ĺ�������å� */
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
    /* Ĺ��­��Ƥ뤫�����å� */
    if( src+utf8_len-1>=src_end )
    {
      /*ECHO_U2S((stderr,"  no enough buffer, here is %d, need %d\n",src_end-src,utf8_len)); */
      SV_Buf_append_ch(&result,'?');
      ++src;
      continue;
    }
    /* ���Х����ܰʹߤ�������ʸ���ϰϤ���ǧ */
    succ = true;
    for( i=1; i<utf8_len; ++i )
    {
      if( src[i]<0x80 || 0xbf<src[i] )
      {
	/*ECHO_U2S((stderr,"  at %d, char out of range\n",i)); */
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
    /* utf8����ucs�Υ����ɤ򻻽� */
    /*ECHO_U2S((stderr,"utf8-charlen: [%d]\n",utf8_len)); */
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
	/*ECHO_U2S((stderr,"invalid utf8-length: %d\n",utf8_len)); */
	ucs = '?';
      }
    }

    if( 0x0f0000<=ucs && ucs<=0x0fffff )
    { /* �����ΰ� */
      const unsigned char* sjis;
      assert(utf8_len>=4);
      if( ucs<0x0ff000 )
      { /* �Τ�ʤ������ΰ� */
	SV_Buf_append_ch(&result,'?');
	src += utf8_len;
	continue;
      }
      /* ��ʸ��Ƚ��(imode) */
      sjis = (unsigned char*)&g_eu2i1_table[ucs - 0x0ff000];
      if( sjis[1]!=0 )
      { /* ���Х���ʸ����. */
	SV_Buf_append_ch2(&result,*(const unsigned short*)(sjis));
      }else if( sjis[0]!=0 )
      { /* ���Х���ʸ����. */
	SV_Buf_append_ch(&result,*sjis);
      }else
      { /* �ޥåԥ󥰤ʤ� */
	SV_Buf_append_ch(&result,'?');
      }
      src += utf8_len;
      continue;
    }

    if( ucs & ~0xFFFF )
    { /* ucs2���ϰϳ� (ucs4���ϰ�) */
      SV_Buf_append_ch(&result,'?');
      src += utf8_len;
      continue;
    }
    
    /* ucs => sjis */
    /*ECHO_U2S((stderr,"ucs2 [%04x]\n",ucs)); */
    /*const unsigned short sjis = g_u2s_table[ucs]; */
    /*ECHO_U2S((stderr,"sjis [%04x]\n",ntohs(sjis) )); */
    
    if( g_u2s_table[ucs] || !ucs )
    { /* �б�ʸ�����������ucs=='\0'�λ� */
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
      SV_Buf_append_ch(&result,'?');
    }
    src += utf8_len;
    /*bin_dump("now",dst_begin,dst-dst_begin); */
  } /* for */

  /*ON_U2S( bin_dump("out",result.getBegin(),result.getLength()) ); */
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
  /*fprintf(stderr,"Unicode::Japanese::(xs)utf8_sjis_imode\n"); */
  /*ON_U2S( bin_dump("in ",src,len) ); */
  SV_Buf_init(&result,len+4);
  src_end = src+len;

  while( src<src_end )
  {
    int utf8_len;
    bool succ;
    int i;
    int ucs;
    if( *src<=0x7f )
    {
      /* ASCII�ϤޤȤ���ɲá� */
      int len = 1;
      while( src+len<src_end && src[len]<=0x7f )
      {
	++len;
      }
      SV_Buf_append_str(&result,src,len);
      src+=len;
      continue;
    }
    /* utf8��ucs���Ѵ� */
    /* utf8�Σ�ʸ����Ĺ�������å� */
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
    /* Ĺ��­��Ƥ뤫�����å� */
    if( src+utf8_len-1>=src_end )
    {
      /*ECHO_U2S((stderr,"  no enough buffer, here is %d, need %d\n",src_end-src,utf8_len)); */
      SV_Buf_append_ch(&result,'?');
      ++src;
      continue;
    }
    /* ���Х����ܰʹߤ�������ʸ���ϰϤ���ǧ */
    succ = true;
    for( i=1; i<utf8_len; ++i )
    {
      if( src[i]<0x80 || 0xbf<src[i] )
      {
	/*ECHO_U2S((stderr,"  at %d, char out of range\n",i)); */
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
    /* utf8����ucs�Υ����ɤ򻻽� */
    /*ECHO_U2S((stderr,"utf8-charlen: [%d]\n",utf8_len)); */
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
	/*ECHO_U2S((stderr,"invalid utf8-length: %d\n",utf8_len)); */
	ucs = '?';
      }
    }

    if( 0x0f0000<=ucs && ucs<=0x0fffff )
    { /* �����ΰ� */
      const unsigned char* sjis;
      assert(utf8_len>=4);
      if( ucs<0x0ff000 )
      { /* �Τ�ʤ������ΰ� */
	SV_Buf_append_ch(&result,'?');
	src += utf8_len;
	continue;
      }
      /* ��ʸ��Ƚ��(imode) */
      sjis = (unsigned char*)&g_eu2i2_table[ucs - 0x0ff000];
      if( sjis[1]!=0 )
      { /* ���Х���ʸ����. */
	SV_Buf_append_ch2(&result,*(const unsigned short*)(sjis));
      }else if( sjis[0]!=0 )
      { /* ���Х���ʸ����. */
	SV_Buf_append_ch(&result,*sjis);
      }else
      { /* �ޥåԥ󥰤ʤ� */
	SV_Buf_append_ch(&result,'?');
      }
      src += utf8_len;
      continue;
    }

    if( ucs & ~0xFFFF )
    { /* ucs2���ϰϳ� (ucs4���ϰ�) */
      SV_Buf_append_ch(&result,'?');
      src += utf8_len;
      continue;
    }
    
    /* ucs => sjis */
    /*ECHO_U2S((stderr,"ucs2 [%04x]\n",ucs)); */
    /*const unsigned short sjis = g_u2s_table[ucs]; */
    /*ECHO_U2S((stderr,"sjis [%04x]\n",ntohs(sjis) )); */
    
    if( g_u2s_table[ucs] || !ucs )
    { /* �б�ʸ�����������ucs=='\0'�λ� */
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
      SV_Buf_append_ch(&result,'?');
    }
    src += utf8_len;
    /*bin_dump("now",dst_begin,dst-dst_begin); */
  } /* for */

  /*ON_U2S( bin_dump("out",result.getBegin(),result.getLength()) ); */
  SV_Buf_setLength(&result);

  return SV_Buf_getSv(&result);
}

