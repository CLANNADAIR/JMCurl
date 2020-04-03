//
//  NewFTPManager.h
//  libcurl
//
//  Created by Ans on 2018/1/3.
//  Copyright © 2018年 Mengxuan Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FTPCurlDownloadManagerDelegate <NSObject>
@optional
- (void)ftpManagerDownloadProgressDidChange:(NSDictionary *)processInfo;
// Returns information about the current download.
// See "Process Info Dictionary Constants" below for detailed info.
//- (void)ftpManagerDownloadFailureReason:(FMStreamFailureReason)failureReason;
//error
@end


@interface FTPCurlDownloadManager : NSObject

@property (weak, nonatomic) id<FTPCurlDownloadManagerDelegate> delegate;
@property (assign, nonatomic) double sizeProgress;

- (void)startDownload:(NSString *)urlStr locaPath:(NSString *)locaPath;
- (void)pauseDownload;
- (void)resumeDownload;
- (void)cancelDownload;

@end
