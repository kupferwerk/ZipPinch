//
//  UIViewController+Alerts.h
//  ZipPinch
//
//  Created by Kupferwerk on 07.03.16.
//  Copyright © 2016 NARR8. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (Alerts)

- (void)alertError:(NSError *)error;
- (void)alertWithErrorMessage:(NSString *)message;

@end
