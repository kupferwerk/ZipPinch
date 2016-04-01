//
//  ZipEntryViewController.m
//  ZipPinch
//
//  Created by Kupferwerk on 07.03.16.
//  Copyright © 2016 NARR8. All rights reserved.
//

#import "ZipEntryViewController.h"
#import "ZPManager.h"
#import "UIViewController+Alerts.h"

@interface ZipEntryViewController ()

@property (weak,nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) NSURLSessionDownloadTask* downloadTask;
@property (strong, nonatomic) NSData* resumeData;

@end

@implementation ZipEntryViewController


- (void)viewWillAppear:(BOOL)animated   {
    
    [super viewWillAppear:animated];
    [self startOrResumeDownload:nil];
}


- (IBAction)pauseDownload:(id)sender    {
    [self.downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
#warning resume does not work, because resume data are not set correctly for file chunks!
        //TODO: file a radar for this issue!
        _selectedZipEntry.resumeData = resumeData;
    }];
}

- (IBAction)startOrResumeDownload:(id)sender    {
    //TODO: Progress reporting
    //TODO: Resuming does not work, as it seems to set the startOffset, but not the end offset
    self.downloadTask = [_zipManager loadDataWithEntry:_selectedZipEntry completionBlock:^(NSData *data, NSError *error) {
        if (error) {
            [self alertError:error];
        } else {
            _imageView.image = [[UIImage alloc] initWithData:data];
        }
    }];
}

- (IBAction)cancelDownload:(id)sender    {
    [self.downloadTask cancel];
}

@end
