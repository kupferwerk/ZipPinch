//
//  ZPManager.m
//  ZipPinch
//
//  Created by Alexey Bukhtin on 17.11.14.
//  Copyright (c) 2014 ZipPinch. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZPManager.h"

static NSString *const ZPManagerFileCachePath = @"ZipPinch";
static NSString *const ZPManagerEntriesFileName = @"zipPinchEntries.plist";
static NSString *const ZPManagerCacheFileLengthKey = @"length";
static NSString *const ZPManagerCacheEntriesKey = @"entries";

@interface ZPManager ()
@property (nonatomic) ZPArchive *archive;
@property (nonatomic) NSArray *entries;
@property (nonatomic) long long fileLength;
@property (nonatomic) BOOL cacheEnabled;
@property (nonatomic) NSString *baseCachePath;
@end

@implementation ZPManager

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithURL:(NSURL *)URL
{
    self = [super init];
    
    if (self) {
        _URL = URL;
        _archive = [ZPArchive new];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemoryCache)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)enableCacheAtPath:(NSString *)path
{
    if (!path) {
        path = [[self class] libraryCachesPath];
    }
    
    _baseCachePath = [path stringByAppendingPathComponent:[_URL lastPathComponent]];
    _cacheEnabled = YES;
}

+ (NSString *)libraryCachesPath
{
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:ZPManagerFileCachePath];
    
    return path;
}


- (void)loadContentWithCompletionBlock:(ZPArchiveArchiveCompletionBlock)completionBlock
{
    // Load entries from cache.
    NSString *cachePath = nil;
    
    if (_cacheEnabled) {
        cachePath = [self.baseCachePath stringByAppendingPathComponent:ZPManagerEntriesFileName];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
            NSDictionary *cache = [NSKeyedUnarchiver unarchiveObjectWithFile:cachePath];
            _fileLength = [cache[ZPManagerCacheFileLengthKey] longLongValue];
            _entries = [cache[ZPManagerCacheEntriesKey] copy];
            
            if (_entries) {
                if (completionBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^(void){
                        completionBlock(_fileLength, _entries, nil);
                        
                    });
                }
                return;
            }
        }
    }
    
    // Load zip content by URL.
    __weak ZPManager *weakSelf = self;
    _fileLength = 0;
    _entries = nil;
    
    [_archive fetchArchiveWithURL:_URL completionBlock:^(long long fileLength, NSArray *entries, NSError *error) {
        if (error) {
            if (completionBlock) {
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    completionBlock(0, nil, error);
                });
            }
            
            return;
        }
        
        weakSelf.fileLength = fileLength;
        weakSelf.entries = [entries copy];
        
        // Cache entries.
        if (weakSelf.cacheEnabled && entries.count) {
            NSString *baseCachePath = [cachePath stringByDeletingLastPathComponent];
            
            if (![[NSFileManager defaultManager] fileExistsAtPath:baseCachePath]) {
                [[NSFileManager defaultManager] createDirectoryAtPath:baseCachePath
                                          withIntermediateDirectories:YES
                                                           attributes:@{ NSFilePosixPermissions:@0755 }
                                                                error:nil];
            }
            
            NSDictionary *cache = @{ ZPManagerCacheFileLengthKey:@(fileLength),
                                     ZPManagerCacheEntriesKey:weakSelf.entries };
            
            if (![NSKeyedArchiver archiveRootObject:cache toFile:cachePath]) {
                NSLog(@"[ZipPinch] Error write to file cache at path: %@", cachePath);
            }
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                completionBlock(fileLength, weakSelf.entries, nil);
            });
        }
    }];
}


- (NSURLSessionDownloadTask*)loadDataWithFilePath:(NSString *)filePath completionBlock:(ZPManagerDataCompletionBlock)completionBlock
{
    return [self loadDataWithEntry:[self entryWithFilePath:filePath] completionBlock:completionBlock];
}


- (NSURLSessionDownloadTask*)loadDataWithURL:(NSURL *)URL completionBlock:(ZPManagerDataCompletionBlock)completionBlock
{
    return [self loadDataWithEntry:[self entryWithURL:URL] completionBlock:completionBlock];
}


- (NSURLSessionDownloadTask*)loadDataWithEntry:(ZPEntry *)entry completionBlock:(ZPManagerDataCompletionBlock)completionBlock
{
    if (entry.data) {
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                completionBlock(entry.data, nil);
            });
        }
        return nil;
    }
    
    // Check cache.
    NSString *path = nil;
    
    if (_cacheEnabled) {
        path = [self.baseCachePath stringByAppendingPathComponent:entry.filePath];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            NSData *data = [NSData dataWithContentsOfFile:path];
            
            if (completionBlock) {
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    completionBlock(data, nil);
                });
            }
            return nil;
        }
    }
    
    return [_archive fetchFile:entry completionBlock:^(ZPEntry *entry, NSError *error) {
        // Cache data.
        if (!error && _cacheEnabled) {
            NSString *basePath = [path stringByDeletingLastPathComponent];
            
            if (![[NSFileManager defaultManager] fileExistsAtPath:basePath]) {
                [[NSFileManager defaultManager] createDirectoryAtPath:basePath
                                          withIntermediateDirectories:YES
                                                           attributes:@{ NSFilePosixPermissions:@0755 }
                                                                error:nil];
            }
            
            [entry.data writeToFile:path atomically:YES];
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                completionBlock(error ? nil : entry.data, error);
            });
        }
    }];
}

- (ZPEntry *)entryWithFilePath:(NSString *)filePath
{
    __block ZPEntry *entryOne = nil;
    
    [_entries enumerateObjectsUsingBlock:^(ZPEntry *entry, NSUInteger idx, BOOL *stop) {
        if ([entry.filePath isEqual:filePath]) {
            entryOne = entry;
            *stop = YES;
        }
    }];
    
    return entryOne;
}

- (ZPEntry *)entryWithURL:(NSURL *)URL
{
    NSString *path = [URL path];
    __block ZPEntry *entryOne = nil;
    
    [_entries enumerateObjectsUsingBlock:^(ZPEntry *entry, NSUInteger idx, BOOL *stop) {
        if ([path hasSuffix:entry.filePath]) {
            entryOne = entry;
            *stop = YES;
        }
    }];
    
    return entryOne;
}

- (void)clearMemoryCache
{
    [_entries enumerateObjectsUsingBlock:^(ZPEntry *entry, NSUInteger idx, BOOL *stop) {
        entry.data = nil;
    }];
}

- (void)clearCache
{
    [self clearMemoryCache];
    
    if (_cacheEnabled && [[NSFileManager defaultManager] fileExistsAtPath:_baseCachePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:_baseCachePath error:nil];
    }
}

+ (void)clearCacheAtDefaultPath
{
    NSString *defaultCachePath = [self libraryCachesPath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:defaultCachePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:defaultCachePath error:nil];
    }
}

@end
