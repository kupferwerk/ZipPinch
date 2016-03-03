//
//  ZPArchive.h
//  ZipPinch
//
//  Created by Alexey Bukhtin on 14.11.14.
//  Copyright (c) 2014 ZipPinch. All rights reserved.
//

#import "ZPEntry.h"

extern NSString *const ZPEntryErrorDomain;

typedef NS_ENUM(NSUInteger, ZPEntryErrorCode) {
    ZPEntryErrorCodeUnknown,
    ZPEntryErrorCodeResponseEmpty = 100,
    ZPEntryErrorCodeContentsEmpty = 101,
};

/**
 *  The block to handle fetching the archive's directory
 *
 *  @param fileLength the file length of the archive
 *  @param entries    the array of ZPEntry, describing the entris of the archive
 *  @param error      if failed, an error, otherwise nil
 */
typedef void(^ZPArchiveArchiveCompletionBlock)(long long fileLength, NSArray *entries, NSError *error);

/**
 *  The block to handle fetching a single entry
 *
 *  @param entry the ZP Entry to fetch
 *  @param error if failed, an error, otherwise nil
 */
typedef void(^ZPArchiveFileCompletionBlock)(ZPEntry *entry, NSError *error);


@interface ZPArchive : NSObject

/**
 *  Fetch the archive's directory
 *
 *  @param URL             the URL to fetch the Archive from
 *  @param completionBlock the block to handle fetching the archive's directory
 */
- (void)fetchArchiveWithURL:(NSURL *)URL completionBlock:(ZPArchiveArchiveCompletionBlock)completionBlock;

/**
 *  Fetch a file from the Archive
 *
 *  @param entry           a single zip archive entry
 *  @param completionBlock the block to handle the download of a single ZPEntry. The downloaded data are stored in entry.data
 */
- (void)fetchFile:(ZPEntry *)entry completionBlock:(ZPArchiveFileCompletionBlock)completionBlock;

@end
