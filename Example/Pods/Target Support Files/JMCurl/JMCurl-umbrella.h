#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "curl.h"
#import "curlver.h"
#import "easy.h"
#import "FTPCurlDownloadManager.h"
#import "mprintf.h"
#import "multi.h"
#import "stdcheaders.h"
#import "system.h"
#import "typecheck-gcc.h"

FOUNDATION_EXPORT double JMCurlVersionNumber;
FOUNDATION_EXPORT const unsigned char JMCurlVersionString[];

