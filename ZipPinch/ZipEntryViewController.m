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

@end

@implementation ZipEntryViewController


- (void)viewWillAppear:(BOOL)animated   {
    
    [super viewWillAppear:animated];
    
    //TODO: Progress reporting
    
    [_zipManager loadDataWithFilePath:_selectedZipEntry.filePath completionBlock:^(NSData *data, NSError *error) {
        if (error) {
            [self alertError:error];
        } else {
            _imageView.image = [[UIImage alloc] initWithData:data];
        }
    }];
}

@end
