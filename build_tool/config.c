#ifndef JX9_AMALGAMATION
#include "jx9Int.h"
#endif

#if !defined(JX9_DISABLE_BUILTIN_FUNC) || defined(__APPLE__)
JX9_PRIVATE sxi32 SyStrncmp(const char *zLeft, const char *zRight, sxu32 nLen)
{
	const unsigned char *zP = (const unsigned char *)zLeft;
	const unsigned char *zQ = (const unsigned char *)zRight;

	if( SX_EMPTY_STR(zP) || SX_EMPTY_STR(zQ)  ){
			return SX_EMPTY_STR(zP) ? (SX_EMPTY_STR(zQ) ? 0 : -1) :1;
	}
	if( nLen <= 0 ){
		return 0;
	}
	for(;;){
		if( nLen <= 0 ){ return 0; } if( zP[0] == 0 || zQ[0] == 0 || zP[0] != zQ[0] ){ break; } zP++; zQ++; nLen--;
		if( nLen <= 0 ){ return 0; } if( zP[0] == 0 || zQ[0] == 0 || zP[0] != zQ[0] ){ break; } zP++; zQ++; nLen--;
		if( nLen <= 0 ){ return 0; } if( zP[0] == 0 || zQ[0] == 0 || zP[0] != zQ[0] ){ break; } zP++; zQ++; nLen--;
		if( nLen <= 0 ){ return 0; } if( zP[0] == 0 || zQ[0] == 0 || zP[0] != zQ[0] ){ break; } zP++; zQ++; nLen--;
	}
	return (sxi32)(zP[0] - zQ[0]);
}	
#endif