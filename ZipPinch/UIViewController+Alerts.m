//
//  UIViewController+Alerts.m
//  ZipPinch
//
//  Created by Kupferwerk on 07.03.16.
//  Copyright © 2016 NARR8. All rights reserved.
//

#import "UIViewController+Alerts.h"

@implementation UIViewController (Alerts)

#pragma mark - Alert

- (void)alertError:(NSError *)error
{
    [self alertWithErrorMessage:[error localizedDescription]];
}

- (void)alertWithErrorMessage:(NSString *)message
{
    [[[UIAlertView alloc] initWithTitle:@"Error"
                                message:message
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}

@end
