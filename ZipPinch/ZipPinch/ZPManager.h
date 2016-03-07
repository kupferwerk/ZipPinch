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


- (void)loadContentWithCompletionBlock:(ZPArchiveArchiveCompletionBlock)completionBlock;

- (void)loadDataWithFilePath:(NSString *)filePath completionBlock:(ZPManagerDataCompletionBlock)completionBlock;

- (void)loadDataWithURL:(NSURL *)URL completionBlock:(ZPManagerDataCompletionBlock)completionBlock;


- (void)clearCache;
- (void)clearMemoryCache;

/**
 *  clears the default cache at /Library/Caches/ZipPinch/.
 */
+ (void)clearCacheAtDefaultPath;

@end
