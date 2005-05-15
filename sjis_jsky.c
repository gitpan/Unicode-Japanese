
/* $Id: sjis_jsky.c,v 1.6 2005/05/15 08:34:42 hio Exp $ */

#include "Japanese.h"
#include <stdio.h>

#define ECHO_EJ2U(arg) /*fprintf arg */
#define ON_EJ2U(cmd) /*cmd */
#define ECHO_U2EJ(arg) /* fprintf arg */
#define ON_U2EJ(cmd) /* cmd */

#ifndef __cplusplus
#undef bool
#undef true
#undef false
typedef enum bool { false, true, } bool;
#endif

/* ---------------------------------------------------------------------------
 * jsky 1 ==> utf8
 * ------------------------------------------------------------------------- */
EXTERN_C
SV*
xs_sjis_jsky1_utf8(SV* sv_str)
{
  const unsigned char* src;
  int len;
  SV_Buf result;
  const unsigned char* src_end;
  
  if( sv_str==&PL_sv_undef )
  {
    return newSVsv(&PL_sv_undef);
  }
  src = (unsigned char*)SvPV(sv_str,PL_na);
  len = sv_len(sv_str);

  ECHO_EJ2U((stderr,"Unicode::Japanese::(xs)sjis_jsky_utf8\n",len));
  ON_EJ2U( bin_dump("in ",src,len) );

  SV_Buf_init(&result,len*3/2+4);
  src_end = src+len;

  while( src<src_end )
  {
    const unsigned char* ptr;
    if( src[0]<0x80 )
    { /* ASCII */
      const unsigned char* begin;
      int j1;
      
      /*fprintf(stderr,"ascii: %02x\n",src[0]); */
      if( src[0]!='\x1b' || src+2>=src_end || src[1]!='$' )
      { /* 絵文字じゃない */
	SV_Buf_append_ch(&result,*src);
	++src;
	continue;
      }
      /*fprint(stderr,"detect j-sky emoji-start escape\n"); */
      /* E_JSKY_1 */
      if( src[2]!='E' && src[2]!='F' && src[2]!='G' )
      {
	/*fprintf(stderr,"first char is invalid"); */
	SV_Buf_append_ch(&result,*src);
	++src;
	continue;
      }

      begin = src;
      src += 3;
      /* E_JSKY_2 */
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
	/*fprintf(stderr,"invalid\n"); */
	src = begin;
	SV_Buf_append_ch(&result,*src);
	++src;
	continue;
      }
      ++src;
      j1 = (begin[2]-'E')<<8;
      for( ptr = begin+3; ptr<src-1; ++ptr )
      {
	/*fprintf(stderr," <%c%c:%04x>\n",begin[2],*ptr,j1+*ptr); */
	/*fprintf(stderr,"   => %04x\n",g_ej2u1_table[j1+*ptr]); */
	const unsigned char* str = (unsigned char*)&g_ej2u1_table[j1+*ptr];
	/*fprintf(stderr,"   len: %d\n",str[3]?4:strlen((char*)str)); */
	SV_Buf_append_str(&result,str,str[3]?4:strlen((char*)str));
      }
      /*fprintf(stderr,"j-sky string done.\n"); */
      continue;
    }else if( 0xa1<=src[0] && src[0]<=0xdf )
    { /* 半角カナ */
      /*fprintf(stderr,"kana": %02x\n",src[0]); */
      ptr = (unsigned char*)&g_s2u_table[src[0]];
      ++src;
    }else if( ((0x81<=src[0] && src[0]<=0x9f) || (0xe0<=src[0] && src[0]<=0xfc) )
	      && (0x40<=src[1] && src[1]<=0xfc && src[1]!=0x7f) )
    { /* 2バイト文字 */
      register const unsigned short sjis = ntohs(*(unsigned short*)src);
      /*fprintf(stderr,"sjis: %04x\n",sjis); */
      ptr = (unsigned char*)&g_s2u_table[sjis];
      src += 2;
    }else
    { /* 不明 */
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
    }else
    {
      /*fprintf(stderr,"utf8-len: [%d]\n",1); */
      SV_Buf_append_ch(&result,*ptr);
    }
  }
  ON_EJ2U( bin_dump("out",result.getBegin(),result.getLength()) );
  SV_Buf_setLength(&result);

  return SV_Buf_getSv(&result);
}

/* ---------------------------------------------------------------------------
 * jsky 2 ==> utf8
 * ------------------------------------------------------------------------- */
EXTERN_C
SV*
xs_sjis_jsky2_utf8(SV* sv_str)
{
  const unsigned char* src;
  int len;
  SV_Buf result;
  const unsigned char* src_end;
  
  if( sv_str==&PL_sv_undef )
  {
    return newSVsv(&PL_sv_undef);
  }
  
  src = (unsigned char*)SvPV(sv_str,PL_na);
  len = sv_len(sv_str);

  ECHO_EJ2U((stderr,"Unicode::Japanese::(xs)sjis_jsky_utf8\n",len));
  ON_EJ2U( bin_dump("in ",src,len) );

  SV_Buf_init(&result,len*3/2+4);
  src_end = src+len;

  while( src<src_end )
  {
    const unsigned char* ptr;
    if( src[0]<0x80 )
    { /* ASCII */
      int j1;
      UJ_UINT32 const* table;
      const unsigned char* begin;
      const unsigned char* ptr;
      
      /*fprintf(stderr,"ascii: %02x\n",src[0]); */
      if( src[0]!='\x1b' || src+2>=src_end || src[1]!='$' )
      { /* 絵文字じゃない */
	SV_Buf_append_ch(&result,*src);
	++src;
	continue;
      }
      /* warn("detect j-sky emoji-start escape\n"); */
      /* E_JSKY_1 */
      if( src[2]=='E' || src[2]=='F' || src[2]=='G' )
      {
	j1 = (src[2]-'E')<<8;
	table = g_ej2u1_table;
      }else if( src[2]=='O' || src[2]=='P' || src[2]=='Q' )
      {
	j1 = (src[2]-'O')<<8;
	table = g_ej2u2_table;
      }else
      {
	j1 = 0;
	table = NULL;
	/* warn("first char is invalid"); */
	SV_Buf_append_ch(&result,*src);
	++src;
	continue;
      }

      begin = src;
      src += 3;
      /* E_JSKY_2 */
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
	/* warn("invalid\n"); */
	src = begin;
	SV_Buf_append_ch(&result,*src);
	++src;
	continue;
      }
      ++src;
      for( ptr = begin+3; ptr<src-1; ++ptr )
      {
	/*fprintf(stderr," <%c%c:%04x>\n",begin[2],*ptr,j1+*ptr); */
	/*fprintf(stderr,"   => %04x\n",g_ej2u2_table[j1+*ptr]); */
	const unsigned char* str = (unsigned char*)&table[j1+*ptr];
	/*fprintf(stderr,"   len: %d\n",str[3]?4:strlen((char*)str)); */
	SV_Buf_append_str(&result,str,str[3]?4:strlen((char*)str));
      }
      /*fprintf(stderr,"j-sky string done.\n"); */
      continue;
    }else if( 0xa1<=src[0] && src[0]<=0xdf )
    { /* 半角カナ */
      /*fprintf(stderr,"kana": %02x\n",src[0]); */
      ptr = (unsigned char*)&g_s2u_table[src[0]];
      ++src;
    }else if( ((0x81<=src[0] && src[0]<=0x9f) || (0xe0<=src[0] && src[0]<=0xfc) )
	      && (0x40<=src[1] && src[1]<=0xfc && src[1]!=0x7f) )
    { /* 2バイト文字 */
      register const unsigned short sjis = ntohs(*(unsigned short*)src);
      /*fprintf(stderr,"sjis: %04x\n",sjis); */
      ptr = (unsigned char*)&g_s2u_table[sjis];
      src += 2;
    }else
    { /* 不明 */
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
    }else
    {
      /*fprintf(stderr,"utf8-len: [%d]\n",1); */
      SV_Buf_append_ch(&result,*ptr);
    }
  }
  ON_EJ2U( bin_dump("out",result.getBegin(),result.getLength()) );
  SV_Buf_setLength(&result);

  return SV_Buf_getSv(&result);
}

/* ---------------------------------------------------------------------------
 * utf8 ==> jsky 1
 * ------------------------------------------------------------------------- */

EXTERN_C
SV*
xs_utf8_sjis_jsky1(SV* sv_str)
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

  ECHO_U2EJ((stderr,"Unicode::Japanese::(xs)utf8_sjis jsky(1)\n"));
  ON_U2EJ( bin_dump("in ",src,len) );

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
      ECHO_U2EJ((stderr,"  no enough buffer, here is %d, need %d\n",src_end-src,utf8_len));
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
	ECHO_U2EJ((stderr,"  at %d, char out of range\n",i));
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
    ECHO_U2EJ((stderr,"utf8-charlen: [%d]\n",utf8_len));
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
	ECHO_U2EJ((stderr,"invalid utf8-length: %d\n",utf8_len));
	ucs = '?';
      }
    }

    if( 0x0f0000<=ucs && ucs<=0x0fffff )
    { /* 私用領域 */
      const unsigned char* sjis;
      assert(utf8_len>=4);
      if( ucs<0x0ff000 )
      { /* 知らない使用領域 */
        SV_Buf_append_ch(&result,'?');
	src += utf8_len;
	continue;
      }
      /* 絵文字判定(j-sky) */
      sjis = &g_eu2j1_table[(ucs - 0x0ff000)*5];
      /*fprintf(stderr,"  emoji: %02x %02x %02x %02x %02x\n", */
      /*	  sjis[0],sjis[1],sjis[2],sjis[3],sjis[4]); */
      if( sjis[4]!=0 )
      { /* ５バイト文字に. */
	SV_Buf_append_ch5(&result,sjis);
      }else if( sjis[3]!=0 )
      { /* ４バイト文字に. */
	assert("not reach here" && 0);
	SV_Buf_append_ch4(&result,*(const int*)(sjis));
      }else if( sjis[2]!=0 )
      { /* ３バイト文字に. */
	assert("not reach here" && 0);
	SV_Buf_append_ch3(&result,*(const int*)(sjis));
      }else if( sjis[1]!=0 )
      { /* ２バイト文字に. */
	SV_Buf_append_ch2(&result,*(const unsigned short*)(sjis));
      }else if( sjis[0]!=0 )
      { /* １バイト文字に. */
	SV_Buf_append_ch(&result,*sjis);
      }else
      { /* マッピングなし */
        SV_Buf_append_ch(&result,'?');
      }
      src += utf8_len;
      continue;
    }

    if( ucs & ~0xFFFF )
    { /* ucs2の範囲外 (ucs4の範囲) */
      SV_Buf_append_ch(&result,'?');
      src += utf8_len;
      continue;
    }
    
    /* ucs => sjis */
    ECHO_U2EJ((stderr,"ucs2 [%04x]\n",ucs));
    /*const unsigned short sjis = g_u2s_table[ucs]; */
    /*ECHO_U2EJ((stderr,"sjis [%04x]\n",ntohs(sjis) ));*/
    
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
      SV_Buf_append_ch(&result,'?');
    }
    src += utf8_len;
    /*bin_dump("now",dst_begin,dst-dst_begin); */
  } /* for */

  ON_U2EJ( bin_dump("out",SV_Buf_getBegin(&result),SV_Buf_getLength(&result)) );
  SV_Buf_setLength(&result);
  sv_2mortal(SV_Buf_getSv(&result));

  {
  /* packing J-SKY emoji escapes */
  SV_Buf pack;
  unsigned char* ptr;
  unsigned char tmpl[5] = { '\x1b','$',0,0,'\x0f',};
  
  SV_Buf_init(&pack,SV_Buf_getLength(&result));
  src = SV_Buf_getBegin(&result);
  src_end = src + SV_Buf_getLength(&result);
  ptr = src;
  for( ; src+5*2-1<src_end; ++src )
  {
    unsigned char ch1;
    /* E_JSKY_START  "\x1b\$", */
    if( src[0]!='\x1b' ) continue;
    if( src[1]!='$' ) continue;
    /* E_JSKY1   '[EFG]', */
    /*fprintf(stderr,"  found emoji-start\n"); */
    if( src[2]!='E' && src[2]!='F' && src[2]!='G' )
    {
      /*fprintf(stderr,"  invalid ch1 [%x:%02x]\n",src[2],src[2]); */
      continue;
    }
    ch1 = src[2];
    /* E_JSKY2    '[\!-\;\=-z\xbc]', */
    if( src[3]<'!' || 'z'<src[3] )
    {
      /*fprintf(stderr,"  invalid ch2 [%02x]\n",src[3]); */
      continue;
    }
    /* E_JSKY_END    "\x0f", */
    if( src[4]!='\x0f' ) continue;

    /*fprintf(stderr,"  found first emoji [%02x:%c]\n",ch1,ch1); */
    src += 5;
    SV_Buf_append_str(&pack,ptr,(src-1)-ptr);
    tmpl[2] = ch1;
    for( ; src_end-src>=5; src+= 5 )
    {
      tmpl[3] = src[3];
      if( memcmp(src,tmpl,5)!=0 ) break;
      /*fprintf(stderr,"  packing...[%02x]\n",src[3]); */
      SV_Buf_append_ch(&pack,src[3]);
    }
    /*fprintf(stderr,"  pack done.\n"); */
    SV_Buf_append_ch(&pack,'\x0f');
    ptr = src;
  }
  /*fprintf(stderr,"  pack complete.\n"); */
  /*fprintf(stderr,"  append len %0d\n",src_end-ptr); */
  if( ptr!=src_end )
  {
    SV_Buf_append_str(&pack,ptr,src_end-ptr);
  }

  ON_U2EJ( bin_dump("out",SV_Buf_getBegin(&pack),SV_Buf_getLength(&pack)) );
  SV_Buf_setLength(&pack);
  
  return SV_Buf_getSv(&pack);
  }
}

/* ---------------------------------------------------------------------------
 * utf8 ==> jsky 2
 * ------------------------------------------------------------------------- */

EXTERN_C
SV*
xs_utf8_sjis_jsky2(SV* sv_str)
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

  ECHO_U2EJ((stderr,"Unicode::Japanese::(xs)utf8_sjis jsky(2)\n"));
  ON_U2EJ( bin_dump("in ",src,len) );

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
      ECHO_U2EJ((stderr,"  no enough input, here is %d, need %d\n",src_end-src,utf8_len));
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
	ECHO_U2EJ((stderr,"  at %d, char out of range\n",i));
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
    ECHO_U2EJ((stderr,"utf8-charlen: [%d]\n",utf8_len));
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
	ECHO_U2EJ((stderr,"invalid utf8-length: %d\n",utf8_len));
	ucs = '?';
      }
    }
    ECHO_U2EJ((stderr,"  ucs:%06x\n",ucs));

    if( 0x0f0000<=ucs && ucs<=0x0fffff )
    { /* 私用領域 */
      const unsigned char* sjis;
      assert(utf8_len>=4);
      if( ucs<0x0ff000 )
      { /* 知らない使用領域 */
        SV_Buf_append_ch(&result,'?');
	src += utf8_len;
	continue;
      }
      /* 絵文字判定(j-sky) */
      sjis = &g_eu2j2_table[(ucs - 0x0ff000)*5];
      ECHO_U2EJ((stderr,"  emoji: %02x %02x %02x %02x %02x\n",
        	  sjis[0],sjis[1],sjis[2],sjis[3],sjis[4]));
      if( sjis[4]!=0 )
      { /* ５バイト文字に. */
	SV_Buf_append_ch5(&result,sjis);
      }else if( sjis[3]!=0 )
      { /* ４バイト文字に. */
	assert("not reach here" && 0);
	SV_Buf_append_ch4(&result,*(const int*)(sjis));
      }else if( sjis[2]!=0 )
      { /* ３バイト文字に. */
	assert("not reach here" && 0);
	SV_Buf_append_ch3(&result,*(const int*)(sjis));
      }else if( sjis[1]!=0 )
      { /* ２バイト文字に. */
	SV_Buf_append_ch2(&result,*(const unsigned short*)(sjis));
      }else if( sjis[0]!=0 )
      { /* １バイト文字に. */
	SV_Buf_append_ch(&result,*sjis);
      }else
      { /* マッピングなし */
        SV_Buf_append_ch(&result,'?');
      }
      src += utf8_len;
      continue;
    }

    if( ucs & ~0xFFFF )
    { /* ucs2の範囲外 (ucs4の範囲) */
      SV_Buf_append_ch(&result,'?');
      src += utf8_len;
      continue;
    }
    
    /* ucs => sjis */
    ECHO_U2EJ((stderr,"ucs2 [%04x]\n",ucs));
    /*const unsigned short sjis = g_u2s_table[ucs]; */
    /*ECHO_U2EJ((stderr,"sjis [%04x]\n",ntohs(sjis) ));*/
    
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
      SV_Buf_append_ch(&result,'?');
    }
    src += utf8_len;
    /*bin_dump("now",dst_begin,dst-dst_begin); */
  } /* for */

  ON_U2EJ( bin_dump("out",SV_Buf_getBegin(&result),SV_Buf_getLength(&result)) );
  SV_Buf_setLength(&result);
  sv_2mortal(SV_Buf_getSv(&result));

  {
  /* packing J-SKY emoji escapes */
  SV_Buf pack;
  unsigned char* ptr;
  
  SV_Buf_init(&pack,SV_Buf_getLength(&result));
  src = SV_Buf_getBegin(&result);
  src_end = src + SV_Buf_getLength(&result);
  ptr = src;
  for( ; src+5*2-1<src_end; ++src )
  {
    unsigned char ch1;
    unsigned char tmpl[5] = { '\x1b','$',0,0,'\x0f',};
    /* E_JSKY_START  "\x1b\$", */
    if( src[0]!='\x1b' ) continue;
    if( src[1]!='$' ) continue;
    /* E_JSKY1   '[EFG]', */
    /*fprintf(stderr,"  found emoji-start\n"); */
    if( src[2]!='E' && src[2]!='F' && src[2]!='G' 
	&& src[2]!='O' && src[2]!='P' && src[2]!='Q' )
    {
      /*fprintf(stderr,"  invalid ch1 [%x:%02x]\n",src[2],src[2]); */
      continue;
    }
    ch1 = src[2];
    /* E_JSKY2    '[\!-\;\=-z\xbc]', */
    if( src[3]<'!' || 'z'<src[3] )
    {
      /*fprintf(stderr,"  invalid ch2 [%02x]\n",src[3]); */
      continue;
    }
    /* E_JSKY_END    "\x0f", */
    if( src[4]!='\x0f' ) continue;

    /*fprintf(stderr,"  found first emoji [%02x:%c]\n",ch1,ch1); */
    src += 5;
    SV_Buf_append_str(&pack,ptr,(src-1)-ptr);
    tmpl[2] = ch1;
    for( ; src_end-src>=5; src+= 5 )
    {
      tmpl[3] = src[3];
      if( memcmp(src,tmpl,5)!=0 ) break;
      /*fprintf(stderr,"  packing...[%02x]\n",src[3]); */
      SV_Buf_append_ch(&pack,src[3]);
    }
    /*fprintf(stderr,"  pack done.\n"); */
    SV_Buf_append_ch(&pack,'\x0f');
    ptr = src;
  }
  /*fprintf(stderr,"  pack complete.\n"); */
  /*fprintf(stderr,"  append len %0d\n",src_end-ptr); */
  if( ptr!=src_end )
  {
    SV_Buf_append_str(&pack,ptr,src_end-ptr);
  }

  ON_U2EJ( bin_dump("out",SV_Buf_getBegin(&pack),SV_Buf_getLength(&pack)) );
  SV_Buf_setLength(&pack);

  return SV_Buf_getSv(&pack);
  }
}
