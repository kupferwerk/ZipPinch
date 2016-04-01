//
//  ZPManager.h
//  ZipPinch
//
//  Created by Alexey Bukhtin on 17.11.14.
//  Copyright (c) 2014 ZipPinch. All rights reserved.
//

#import "ZPArchive.h"

typedef void(^ZPManagerDataCompletionBlock)(NSData *data, NSError *error);

@interface ZPManager : NSObject

@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, readonly) NSArray *entries;
@property (nonatomic, readonly) NSString *baseCachePath;

/**
 *  Initializes the ZPManager with the given URL
 *
 *  @param URL the url to pick files from
 *
 *  @return the configured ZPManager
 */
- (instancetype)initWithURL:(NSURL *)URL;


/**
 *  Enable file cache at the given path. If path is nil, then path is /Library/Caches/ZipPinch/.
 *
 *  @param path the path to use for cache data.
 */
- (void)enableCacheAtPath:(NSString *)path;


/**
 *  Loads the content table from the zip file
 *
 *  @param completionBlock the block that processes the entry table
 */
- (void)loadContentWithCompletionBlock:(ZPArchiveArchiveCompletionBlock)completionBlock;


/**
 *  Starts or Resumes the download of the specified entry
 *
 *  @param entry      the entry, if the entry has resumeData, the download is started from them
 *  @param completionBlock the block to run after completion
 *
 *  @return the started downloadTask, which can be used to cancel the task
 */
- (NSURLSessionDownloadTask*)loadDataWithEntry:(ZPEntry *)entry completionBlock:(ZPManagerDataCompletionBlock)completionBlock;


- (NSURLSessionDownloadTask*)loadDataWithFilePath:(NSString *)filePath completionBlock:(ZPManagerDataCompletionBlock)completionBlock;

- (NSURLSessionDownloadTask*)loadDataWithURL:(NSURL *)URL completionBlock:(ZPManagerDataCompletionBlock)completionBlock;


- (void)clearCache;
- (void)clearMemoryCache;


/**
 *  clears the default cache at /Library/Caches/ZipPinch/.
 */
+ (void)clearCacheAtDefaultPath;

@end
