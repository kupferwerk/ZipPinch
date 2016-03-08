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

/**
 *  Shows the error in a UIAlertView
 *
 *  @param error the error, which localized description is displayed
 */
- (void)alertError:(NSError *)error
{
    [self alertWithErrorMessage:[error localizedDescription]];
}

/**
 *  Shows the message in an UIAlertView with the title "Error" and an OK button to vlose the alert 
 *
 *  @param message the message to show
 */
- (void)alertWithErrorMessage:(NSString *)message
{
    [[[UIAlertView alloc] initWithTitle:@"Error"
                                message:message
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}

@end
