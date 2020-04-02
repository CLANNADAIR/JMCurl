//
//  NewFTPManager.m
//  libcurl
//
//  Created by Ans on 2018/1/3.
//  Copyright © 2018年 Mengxuan Chen. All rights reserved.
//

#import "FTPCurlDownloadManager.h"
#import "curl.h"
#include <sys/stat.h>

//#define kFMProcessInfoProgress @"progress" // 0.0 to 1.0
#define kFMProcessInfoFileSize @"fileSize"
//#define kFMProcessInfoBytesProcessed @"bytesProcessed"
#define kFMProcessInfoFileSizeProcessed @"fileSizeProcessed"


@implementation FTPCurlDownloadManager
{
    CURL *currentCurl;
}

//定义一个结构为了传递给my_fwrite函数.可用curl_easy_setopt的CURLOPT_WRITEDATA选项传递
struct FtpFile
{
    char *filename;
    FILE *stream;
};

- (instancetype)init
{
    self = [super init];
    if (self) {
        _sizeProgress = 0.0;
        currentCurl = curl_easy_init();
    }
    return self;
}

- (void)dealloc
{
//    curl_easy_cleanup(currentCurl);// 添加在appDelegate中
}

#pragma mark - 下载
int download(void *ocObj,CURL *curlhandle, const char * remotepath, const char * localpath, long timeout, long tries)
{
    
    FILE *f;
    curl_off_t local_file_len = -1 ;
    long filesize =0 ;
    CURLcode r = CURLE_GOT_NOTHING;
    struct stat file_info;
    int use_resume = 0;
    //获取本地文件大小信息
    if(stat(localpath, &file_info) == 0)
    {
        local_file_len = file_info.st_size;
        use_resume = 1;
    }
    //追加方式打开文件，实现断点续传
    f = fopen(localpath, "ab+");
    if (f == NULL) {
        perror(NULL);
        return 0;
    }
    //    curl_easy_setopt(curlhandle, CURLOPT_FTP_FILEMETHOD, CURLFTPMETHOD_NOCWD);
    curl_easy_setopt(curlhandle, CURLOPT_URL, remotepath);
    
    curl_easy_setopt(curlhandle, CURLOPT_USERPWD, "admin:admin");
    //连接超时设置
    curl_easy_setopt(curlhandle, CURLOPT_CONNECTTIMEOUT, timeout);
    //设置头处理函数
    curl_easy_setopt(curlhandle, CURLOPT_HEADERFUNCTION, getcontentlengthfunc);
    curl_easy_setopt(curlhandle, CURLOPT_HEADERDATA, &filesize);
    // 设置断点续传
    
    curl_easy_setopt(curlhandle, CURLOPT_RESUME_FROM_LARGE, use_resume?local_file_len:0);
    curl_easy_setopt(curlhandle, CURLOPT_WRITEFUNCTION, writefunc);
    curl_easy_setopt(curlhandle, CURLOPT_PROGRESSFUNCTION,my_progress_callback);
    curl_easy_setopt(curlhandle, CURLOPT_PROGRESSDATA, ocObj);
    curl_easy_setopt(curlhandle, CURLOPT_WRITEDATA, f);
    curl_easy_setopt (curlhandle, CURLOPT_NOPROGRESS, 0);
    curl_easy_setopt(curlhandle, CURLOPT_VERBOSE, 1L);
    curl_easy_setopt(curlhandle, CURLOPT_NOSIGNAL, 1);
    
    //    curl_easy_setopt(curlhandle, CURLOPT_DIRLISTONLY,fileListFunc);
    r = curl_easy_perform(curlhandle);
    fclose(f);
    if (r == CURLE_OK) {
        return 1;
    } else {
        fprintf(stderr, "%s\n", curl_easy_strerror(r));
        
        FTPCurlDownloadManager *ftpManager = (__bridge FTPCurlDownloadManager *)(ocObj);
        if (ftpManager.delegate && [ftpManager.delegate respondsToSelector:@selector(ftpManagerDownloadProgressDidChange:)]) {
            [ftpManager.delegate ftpManagerDownloadProgressDidChange:nil];
        }
        return 0;
    }
}

size_t getcontentlengthfunc(void *ptr, size_t size, size_t nmemb, void *stream)
{
    int r;
    long len = 0;
    /* _snscanf() is Win32 specific */
    //r = _snscanf(ptr, size * nmemb, "Content-Length: %ld\n", &len);
    r = sscanf((const char*)ptr, "Content-Length: %ld\n", &len);
    if (r) /* Microsoft: we don't read the specs */
        *((long *) stream) = len;
    return size * nmemb;
}

#pragma mark - write data to local 有数据写入本地时调用
size_t writefunc(void *ptr, size_t size, size_t nmemb, void *stream)
{
    return fwrite(ptr, size, nmemb, (FILE*)stream);
}

#pragma mark - "下载进度回调"
int my_progress_callback(void* ocPtr,
                         double TotalToDownload,
                         double NowDownloaded,
                         double TotalToUpload,
                         double NowUpload)
{
    if (ocPtr) {
//        id oc = (__bridge id)ocPtr;
        
        //how wide you want the progress bar to be ?
        int totalDot = 80;
        
        double fractionDownloaded = 0.0;
        if(TotalToDownload != 0)
            fractionDownloaded = NowDownloaded / TotalToDownload;//注意0不能为分母
        else
            fractionDownloaded = 0;
        if (fractionDownloaded == 0) return 0;

        //the full part of progress bar
        int dot = round(fractionDownloaded * totalDot);
        
        //create the progress bar, but control to print
        //    if(dot % 10 == 0){
//        printf("total: %0.0f, now: %0.0f\n", TotalToDownload, NowDownloaded);
        int i = 0;
//        printf("%3.0f%% [", fractionDownloaded * 100);
        for(; i < dot; i++)
//            printf("="); // full part
        for(; i < totalDot; i++)
//            printf(" "); // remainder part
//        printf("]\n");
        fflush(stdout); //avoid output buffering problems
        //    }
        
        // 回调 下载进度
        FTPCurlDownloadManager *ftpManager = (__bridge FTPCurlDownloadManager *)(ocPtr);
        if (fractionDownloaded >= ftpManager.sizeProgress || fractionDownloaded >= 0.9999) {
            if (fractionDownloaded == 1.0 || ftpManager.sizeProgress >= 1.0) {
                ftpManager.sizeProgress = 0.0;
            }
            ftpManager.sizeProgress += 0.01;

            if (ftpManager.delegate && [ftpManager.delegate respondsToSelector:@selector(ftpManagerDownloadProgressDidChange:)]) {
                [ftpManager.delegate ftpManagerDownloadProgressDidChange:
                 @{kFMProcessInfoFileSizeProcessed:@(NowDownloaded),
                   kFMProcessInfoFileSize:@(TotalToDownload)}];
            }
        }
        return 0;
    }else {
        // 回调 失败
        printf("下载进度回调错误 \n");
        FTPCurlDownloadManager *ftpManager = (__bridge FTPCurlDownloadManager *)(ocPtr);
        if (ftpManager.delegate && [ftpManager.delegate respondsToSelector:@selector(ftpManagerDownloadProgressDidChange:)]) {
            [ftpManager.delegate ftpManagerDownloadProgressDidChange:nil];
        }
        return -1;
    }
    
}



#pragma mark - 开始下载
/*
 urlStr: "ftp://169.254.176.247//Users/mengxuanchen/Desktop/2017_01_01_08_04_05.3gp"
 locaPath:
 NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
 NSString *path2 = [path stringByAppendingString:@"/777.3gp"];
 */
- (void)startDownload:(NSString *)urlStr locaPath:(NSString *)locaPath {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        void *p = (__bridge void *)self;
        download(p,
                 currentCurl,
                 [urlStr cStringUsingEncoding:NSUTF8StringEncoding],
                 [locaPath cStringUsingEncoding:NSUTF8StringEncoding],
                 5,
                 3);
        curl_easy_cleanup(currentCurl);
    });
}

#pragma mark - 暂停下载
- (void)pauseDownload {
    printf("NewFTPManager暂停下载 \n");
    curl_easy_pause(currentCurl, CURLPAUSE_ALL);
}

#pragma mark - 恢复下载
- (void)resumeDownload {
    curl_easy_pause(currentCurl, CURLPAUSE_CONT);
}

- (void)cancelDownload {
    _delegate = nil;
    if (currentCurl != nil) {
        curl_easy_setopt(currentCurl, CURLOPT_CONNECTTIMEOUT_MS, 1);
        curl_easy_setopt(currentCurl, CURLOPT_TIMEOUT_MS, 1);
    }
}

#pragma mark - 获取列表
- (void)getListFileName
{
    curl_easy_setopt(currentCurl, CURLOPT_URL, "ftp://169.254.176.247//Users/mengxuanchen/Desktop");
    curl_easy_setopt(currentCurl, CURLOPT_USERPWD, "mengxuanchen:123456");
    CURLcode ret = curl_easy_perform(currentCurl);
    if (CURLE_OK != ret) {
        fprintf(stderr, "ERROR: %u", ret);
    }
}



@end
