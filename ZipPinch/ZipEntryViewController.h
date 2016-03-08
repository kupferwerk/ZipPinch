//
//  ZipEntryViewController.h
//  ZipPinch
//
//  Created by Kupferwerk on 07.03.16.
//  Copyright © 2016 NARR8. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ZPManager;
@class ZPEntry;

@interface ZipEntryViewController : UIViewController

@property (strong, nonatomic) ZPManager *zipManager;
@property (nonatomic) ZPEntry *selectedZipEntry;

@end
