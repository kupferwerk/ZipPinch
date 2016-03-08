//
//  ZPArchive.m
//  ZipPinch
//
//  Created by Alexey Bukhtin on 14.11.14.
//  Copyright (c) 2014 ZipPinch. All rights reserved.
//

#import "ZPArchive.h"

#include <zlib.h>
#include <ctype.h>
#include <stdio.h>

NSString *const ZPEntryErrorDomain = @"zp.entry.error";

typedef unsigned int uint32;
typedef unsigned short uint16;

typedef void(^ZPArchiveRequestCompletionBlock)(const char *cptr, NSUInteger len, NSError *error);

// The headers, see http://en.wikipedia.org/wiki/ZIP_(file_format)#File_headers
// Note that here they will not be as tightly packed as defined in the file format,
// so the extraction is done with a macro below.

struct zip_end_record {
    uint32 endOfCentralDirectorySignature;
    uint16 numberOfThisDisk;
    uint16 diskWhereCentralDirectoryStarts;
    uint16 numberOfCentralDirectoryRecordsOnThisDisk;
    uint16 totalNumberOfCentralDirectoryRecords;
    uint32 sizeOfCentralDirectory;
    uint32 offsetOfStartOfCentralDirectory;
    uint16 ZIPfileCommentLength;
};

struct zip_dir_record {
    uint32 centralDirectoryFileHeaderSignature;
    uint16 versionMadeBy;
    uint16 versionNeededToExtract;
    uint16 generalPurposeBitFlag;
    uint16 compressionMethod;
    uint16 fileLastModificationTime;
    uint16 fileLastModificationDate;
    uint32 CRC32;
    uint32 compressedSize;
    uint32 uncompressedSize;
    uint16 fileNameLength;
    uint16 extraFieldLength;
    uint16 fileCommentLength;
    uint16 diskNumberWhereFileStarts;
    uint16 internalFileAttributes;
    uint32 externalFileAttributes;
    uint32 relativeOffsetOfLocalFileHeader;
};

struct zip_file_header {
    uint32 localFileHeaderSignature;
    uint16 versionNeededToExtract;
    uint16 generalPurposeBitFlag;
    uint16 compressionMethod;
    uint16 fileLastModificationTime;
    uint16 fileLastModificationDate;
    uint32 CRC32;
    uint32 compressedSize;
    uint32 uncompressedSize;
    uint16 fileNameLength;
    uint16 extraFieldLength;
};

@interface ZPArchive () <NSURLSessionDelegate, NSURLSessionTaskDelegate>

/**
 *  The fileLength of the encrypted Archive
 */
@property (nonatomic) long long fileLength;

/**
 *  the data task to probe a zip file.
 */
@property (strong, nonatomic) NSURLSessionDataTask* dataTask;


@property (copy, nonatomic) ZPArchiveArchiveCompletionBlock archiveCompletionBlock;


@end

@implementation ZPArchive

#pragma mark - Fetch Archive

- (void)fetchArchiveWithURL:(NSURL *)URL completionBlock:(ZPArchiveArchiveCompletionBlock)completionBlock
{
    // Don't start without callback.
    if (!completionBlock) {
        return;
    }
    
    self.archiveCompletionBlock = completionBlock;
    
    _fileLength = 0;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;

    //if there is a data Task already running, cancel it
    //TODO: Doesn't look right, as soon as a second request is initiated, any previous one is canceled.
    if (self.dataTask)  {
        [self.dataTask cancel];
    }

    //Setup a new connection, set myself as response delegate
    //Note that this creates a STRONG reference to the delegate
    NSURLSessionConfiguration* configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:self
                                                     delegateQueue:nil];
    
    self.dataTask = [session dataTaskWithRequest:request];
    [self.dataTask resume];
    [session finishTasksAndInvalidate]; //This frees the delegate as soon as the dataTask is finished and all delegate calls were done
}

#pragma mark - Zip Content

/**
 *  Fetches (only) the Zip Directory from the URL
 *
 *  @param URL             the URL of the zip file
 *  @param length          the expected length of the zip file
 *  @param completionBlock the block to handle the result
 */
- (void)findCentralDirectoryWithURL:(NSURL *)URL
                     withFileLength:(NSUInteger)length
                    completionBlock:(ZPArchiveArchiveCompletionBlock)completionBlock
{
    [self startRequestWithURL:URL
                    rangeFrom:(length - 4096)
                  rangeLength:(length - 1)
              completionBlock:^(const char *cptr, NSUInteger len, NSError *error) {
                  if (error) {
                      completionBlock(0, nil, error);
                      
                      return;
                  }
                  
                  char *found = NULL;
                  
                  char endOfCentralDirectorySignature[4] = {
                      0x50, 0x4b, 0x05, 0x06
                  };
                  
                  NSLog(@"[ZipPinch] Find Central Directory: ended. Received: %lu", (unsigned long)len);
                  
                  do {
                      char *fptr = memchr(cptr, 0x50, len);
                      
                      // Done searching.
                      if (!fptr) {
                          break;
                      }
                      
                      // Use the last found directory.
                      if (!memcmp(endOfCentralDirectorySignature, fptr, 4)) {
                          found = fptr;
                      }
                      
                      len = len - (fptr - cptr) - 1;
                      cptr = fptr + 1;
                  } while (1);
                  
                  if (!found) {
                      NSLog(@"[ZipPinch] No end-header found!");
                  } else {
                      NSLog(@"[ZipPinch] Found end-header!");
                      
                      struct zip_end_record end_record;
                      int idx = 0;
                      
                      // Extract fields with a macro, if we would need to swap byteorder this would be the place
#define GETFIELD( _field ) \
memcpy(&end_record._field, &found[idx], sizeof(end_record._field)); \
idx += sizeof(end_record._field)
                      GETFIELD( endOfCentralDirectorySignature );
                      GETFIELD( numberOfThisDisk );
                      GETFIELD( diskWhereCentralDirectoryStarts );
                      GETFIELD( numberOfCentralDirectoryRecordsOnThisDisk );
                      GETFIELD( totalNumberOfCentralDirectoryRecords );
                      GETFIELD( sizeOfCentralDirectory );
                      GETFIELD( offsetOfStartOfCentralDirectory );
                      GETFIELD( ZIPfileCommentLength );
#undef GETFIELD
                      
                      [self parseCentralDirectoryWithURL:URL
                                              withOffset:end_record.offsetOfStartOfCentralDirectory
                                              withLength:end_record.sizeOfCentralDirectory
                                         completionBlock:completionBlock];
                  }
              }];
}


/**
 *  Parses the central directory of the URL and builds the array of entries in the zip
 *
 *  @param URL             the URL to fetch the directory from
 *  @param offset          the offset to the zip directory
 *  @param length          the length of the zip directory block
 *  @param completionBlock the block to handle the result
 */
- (void)parseCentralDirectoryWithURL:(NSURL *)URL
                          withOffset:(NSInteger)offset
                          withLength:(NSUInteger)length
                     completionBlock:(ZPArchiveArchiveCompletionBlock)completionBlock
{
    static int const zipPrefixLength = 46;
    
    [self startRequestWithURL:URL
                    rangeFrom:offset
                  rangeLength:(offset + length - 1)
              completionBlock:^(const char *cptr, NSUInteger len, NSError *error) {
                  // Check response error.
                  if (error) {
                      completionBlock(0, nil, error);
                      
                      return;
                  }
                  
                  NSMutableArray *entries = [NSMutableArray array];
                  
                  NSLog(@"[ZipPinch] Parse Central Directory: ended. Received: %lu", (unsigned long)len);
                  
                  // 46 ?!? That's the record length up to the filename see
                  // http://en.wikipedia.org/wiki/ZIP_(file_format)#File_headers
                  
                  while (len > zipPrefixLength) {
                      struct zip_dir_record dir_record;
                      int idx = 0;
                      
                      // Extract fields with a macro, if we would need to swap byteorder this would be the place
#define GETFIELD( _field ) \
memcpy(&dir_record._field, &cptr[idx], sizeof(dir_record._field)); \
idx += sizeof(dir_record._field)
                      GETFIELD( centralDirectoryFileHeaderSignature );
                      GETFIELD( versionMadeBy );
                      GETFIELD( versionNeededToExtract );
                      GETFIELD( generalPurposeBitFlag );
                      GETFIELD( compressionMethod );
                      GETFIELD( fileLastModificationTime );
                      GETFIELD( fileLastModificationDate );
                      GETFIELD( CRC32 );
                      GETFIELD( compressedSize );
                      GETFIELD( uncompressedSize );
                      GETFIELD( fileNameLength );
                      GETFIELD( extraFieldLength );
                      GETFIELD( fileCommentLength );
                      GETFIELD( diskNumberWhereFileStarts );
                      GETFIELD( internalFileAttributes );
                      GETFIELD( externalFileAttributes );
                      GETFIELD( relativeOffsetOfLocalFileHeader );
#undef GETFIELD
                      
                      NSString *filename = [[NSString alloc] initWithBytes:(cptr + zipPrefixLength)
                                                                    length:dir_record.fileNameLength
                                                                  encoding:NSUTF8StringEncoding];
                      ZPEntry *entry = [ZPEntry new];
                      entry.URL = URL;
                      entry.filePath = filename;
                      entry.method = dir_record.compressionMethod;
                      entry.sizeCompressed = dir_record.compressedSize;
                      entry.sizeUncompressed = dir_record.uncompressedSize;
                      entry.offset = dir_record.relativeOffsetOfLocalFileHeader;
                      entry.filenameLength = dir_record.fileNameLength;
                      entry.extraFieldLength = dir_record.extraFieldLength;
                      [entries addObject:entry];
                      
                      len -= zipPrefixLength + dir_record.fileNameLength + dir_record.extraFieldLength + dir_record.fileCommentLength;
                      cptr += zipPrefixLength + dir_record.fileNameLength + dir_record.extraFieldLength + dir_record.fileCommentLength;
                  }
                  
                  completionBlock(_fileLength, [entries copy], nil);
              }];
}

#pragma mark - Fetch File

- (void)fetchFile:(ZPEntry *)entry completionBlock:(ZPArchiveFileCompletionBlock)completionBlock
{
    if (!completionBlock) {
        return;
    }
    
    entry.data = nil;
    
    // Download '16' extra bytes as I've seen that extraFieldLength sometimes differs
    // from the centralDirectory and the fileEntry header...
    NSInteger length = sizeof(struct zip_file_header) + entry.sizeCompressed + entry.filenameLength + entry.extraFieldLength;
    
    [self startRequestWithURL:entry.URL
                    rangeFrom:entry.offset
                  rangeLength:(entry.offset + length + 16)
              completionBlock:^(const char *cptr, NSUInteger len, NSError *error) {
                  
                  NSLog(@"[ZipPinch] Fetch File: ended. Received: %lu", (unsigned long)len);
                  
                  if (!cptr || len == 0 || error) {
                      completionBlock(entry, error);
                      
                      return;
                  }
                  
                  struct zip_file_header file_record;
                  int idx = 0;
                  
                  // Extract fields with a macro, if we would need to swap byteorder this would be the place
#define GETFIELD( _field ) \
memcpy(&file_record._field, &cptr[idx], sizeof(file_record._field)); \
idx += sizeof(file_record._field)
                  GETFIELD( localFileHeaderSignature );
                  GETFIELD( versionNeededToExtract );
                  GETFIELD( generalPurposeBitFlag );
                  GETFIELD( compressionMethod );
                  GETFIELD( fileLastModificationTime );
                  GETFIELD( fileLastModificationDate );
                  GETFIELD( CRC32 );
                  GETFIELD( compressedSize );
                  GETFIELD( uncompressedSize );
                  GETFIELD( fileNameLength );
                  GETFIELD( extraFieldLength );
#undef GETFIELD
                  
                  if (entry.method == Z_DEFLATED) {
                      z_stream zstream;
                      int ret;
                      
                      zstream.zalloc = Z_NULL;
                      zstream.zfree = Z_NULL;
                      zstream.opaque = Z_NULL;
                      zstream.avail_in = 0;
                      zstream.next_in = Z_NULL;
                      
                      ret = inflateInit2(&zstream, -MAX_WBITS);
                      
                      if (ret != Z_OK) {
                          return;
                      }
                      
                      zstream.avail_in = (uInt)entry.sizeCompressed;
                      zstream.next_in = (unsigned char *)&cptr[idx + file_record.fileNameLength + file_record.extraFieldLength];
                      
                      unsigned char *ptr = malloc(entry.sizeUncompressed);
                      
                      zstream.avail_out = (unsigned int)entry.sizeUncompressed;
                      zstream.next_out = ptr;
                      
                      ret = inflate(&zstream, Z_SYNC_FLUSH);
                      
                      entry.data = [NSData dataWithBytes:ptr length:entry.sizeUncompressed];
                      
                      NSLog(@"[ZipPinch] Uncompressed bytes: %li", (long)zstream.avail_in);
                      
                      free(ptr);
                      
                      switch (ret) {
                          case Z_NEED_DICT: {
                              NSLog(@"[ZipPinch] Uncompressed Data Error");
                              break;
                          }
                              
                          case Z_DATA_ERROR: {
                              NSLog(@"[ZipPinch] Uncompressed Error");
                              break;
                          }
                              
                          case Z_MEM_ERROR: {
                              NSLog(@"[ZipPinch] Uncompressed Memory Error");
                              break;
                          }
                      }
                      
                      inflateEnd(&zstream);
                      
                  } else if (entry.method == 0) {
                      unsigned char *ptr = (unsigned char *)&cptr[idx + file_record.fileNameLength + file_record.extraFieldLength];
                      entry.data = [NSData dataWithBytes:ptr length:entry.sizeUncompressed];
                      
                  } else {
                      NSLog(@"[ZipPinch] Unimplemented uncompress method: %li", (long)entry.method);
                  }
                  
                  completionBlock(entry, nil);
              }];
}

#pragma mark -

/**
 *  Start a download task for a range of bytes
 *
 *  @param URL             the target URL
 *  @param rangeFrom       the download starts here...
 *  @param rangeTo         ...and ends here
 *  @param completionBlock the block to handle the result
 */
- (void)startRequestWithURL:(NSURL *)URL
                  rangeFrom:(NSUInteger)rangeFrom
                rangeLength:(NSUInteger)rangeTo
            completionBlock:(ZPArchiveRequestCompletionBlock)completionBlock
{
    NSString *rangeValue = [NSString stringWithFormat:@"bytes=%lu-%lu", (unsigned long)rangeFrom, (unsigned long)rangeTo];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setValue:rangeValue forHTTPHeaderField:@"Range"];
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    
    NSURLSessionConfiguration* configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.HTTPMaximumConnectionsPerHost = 1;  //Serialize downloads to a single host
    configuration.timeoutIntervalForResource = 7200000; //
    
    NSURLSession* session = [NSURLSession sessionWithConfiguration:configuration];
    NSURLSessionDownloadTask* task = [session downloadTaskWithRequest:request
                                                completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                    if (!error)  {
                                                        //temporary adjustment to keep interface
                                                        NSData* data = [NSData dataWithContentsOfURL:location];
                                                        completionBlock((const char *)[data bytes], [data length], nil);
                                                    }
                                                    else {
                                                        completionBlock(nil, 0, error);
                                                    }
                                                }];
    [task resume];
}


#pragma mark - <NSURLSessionDataDelegate>

/**
 *  Handling the first response of a data task request. NOTE: This stops the request immediately! The method is used here to inspect the response for availability and the expected length, not to download data. Downloading data uses NSURLSessionDownloadTask tasks!
 *
 *  @param session           the session
 *  @param dataTask          the dataTask
 *  @param response          the server response
 *  @param completionHandler the block to handle the result
 */
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    
    
    //TODO: Check if dataTask is a prober task!
    [dataTask cancel];

    if ([(NSHTTPURLResponse*)response statusCode] == 200)  {
        self.fileLength = response.expectedContentLength;
        [self findCentralDirectoryWithURL:response.URL
                               withFileLength:(NSUInteger)response.expectedContentLength
                              completionBlock:self.archiveCompletionBlock];
    }
    else {
        NSLog(@"[ZipPinch] Fetch URL: failed. %@", response.URL);
        NSError* error = [NSError errorWithDomain:@"HTTP Error"
                                             code:[(NSHTTPURLResponse*)response statusCode]
                                         userInfo:nil];
        self.archiveCompletionBlock(0, nil, error);
    }
}





@end
