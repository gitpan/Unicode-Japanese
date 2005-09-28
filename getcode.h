
#ifndef GETCODE_H
#define GETCODE_H

/* $Id: getcode.h,v 1.5 2005/09/28 13:17:06 hio Exp $ */

#ifdef TEST
#define DECL_MAP_MODE(name,num) const char* mode_##name[num]
#define EXTERN_DECL_MAP_MODE(name,num) extern DECL_MAP_MODE(name,num)
#else
#define DECL_MAP_MODE(name,num)
#define EXTERN_DECL_MAP_MODE(name,num)
#endif

#define DECL_MAP_TABLE(name,num) \
  extern const unsigned char map_##name[num][256]

#define DECL_MAP(name,num) DECL_MAP_MODE(name,num); DECL_MAP_TABLE(name,num)
#define EXTERN_DECL_MAP(name,num) EXTERN_DECL_MAP_MODE(name,num); DECL_MAP_TABLE(name,num)

EXTERN_DECL_MAP(ascii,1);
EXTERN_DECL_MAP(eucjp,5);
EXTERN_DECL_MAP(sjis,2);
EXTERN_DECL_MAP(utf8,6);
EXTERN_DECL_MAP(jis,11);
EXTERN_DECL_MAP(jis_au,12);
EXTERN_DECL_MAP(jis_jsky,13);
EXTERN_DECL_MAP(utf32_be,4);
EXTERN_DECL_MAP(utf32_le,4);
EXTERN_DECL_MAP(sjis_jsky,5);
EXTERN_DECL_MAP(sjis_imode,4);
EXTERN_DECL_MAP(sjis_doti,7);

#define map_invalid 0x7f

#endif
