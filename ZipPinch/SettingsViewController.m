//
//  ViewController.m
//  ZipPinch
//
//  Created by Alexey Bukhtin on 14.11.14.
//  Copyright (c) 2014 NARR8. All rights reserved.
//

#import "SettingsViewController.h"
#import "ZPManager.h"

#import "ZipTableViewController.h"
#import "UIViewController+Alerts.h"


static NSString *const ViewControllerEntriesSegue = @"entriesSegue";

@interface SettingsViewController () <UITextFieldDelegate>

@property (strong, nonatomic) ZPManager *zipManager;

@property (weak, nonatomic) IBOutlet UISwitch *cacheEnabledSwitch;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

- (IBAction)finishEditingTextField:(UITextField *)sender;
- (IBAction)showHubblePhotos:(UIButton *)sender;
- (IBAction)updateCacheEnabled:(UISwitch *)sender;

@end


@implementation SettingsViewController

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:ViewControllerEntriesSegue]) {
        ZipTableViewController* target = segue.destinationViewController;
        target.zipManager = _zipManager;
        target.title =_zipManager.URL.host;
    }
}

#pragma mark - Actions

- (IBAction)finishEditingTextField:(UITextField *)sender
{
    if (sender.text.length) {
        if (![sender.text hasPrefix:@"http"]) {
            sender.text = [@"http://" stringByAppendingString:sender.text];
        }
        
        NSURL *URL = [NSURL URLWithString:sender.text];
        
        if (URL && URL.host && [URL.host rangeOfString:@"."].location != NSNotFound) {
            [_activityIndicator startAnimating];
            [self loadZipWithURL:URL useCache: self.cacheEnabledSwitch.on];
            return;
        }
    }
    [self alertWithErrorMessage:@"URL not valid"];
}

- (IBAction)showHubblePhotos:(UIButton *)sender
{
    _textField.text = @"http://www.spacetelescope.org/static/images/zip/top100/top100-large.zip";
    [self finishEditingTextField:_textField];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self cancelZipLoading];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return NO;
}

- (void)cancelZipLoading
{
    [_activityIndicator stopAnimating];
    //TODO: refactor! The download task should be properly canceled!
    _zipManager = nil;
}


#pragma mark - ZipPinch

- (void)loadZipWithURL:(NSURL *)URL useCache:(BOOL)useCache
{
    self.zipManager = [[ZPManager alloc] initWithURL:URL];
    
    if (useCache) {
        [_zipManager enableCacheAtPath:nil];
    }
    
    __weak ZPManager *zipManager = _zipManager;
    __weak SettingsViewController *weakSelf = self;
    
    [_zipManager loadContentWithCompletionBlock:^(long long fileLength, NSArray *entries, NSError *error) {
            if (error) {
                [weakSelf.activityIndicator stopAnimating];
                [weakSelf alertError:error];
                return;
            }
            
            if (weakSelf.zipManager && zipManager == weakSelf.zipManager) {
                if (entries.count) {
                    [weakSelf.activityIndicator stopAnimating];
                    [weakSelf performSegueWithIdentifier:ViewControllerEntriesSegue sender:nil];
                    
                } else {
                    [weakSelf cancelZipLoading];
                    [weakSelf alertWithErrorMessage:@"Zip empty or not found"];
                }
            }
    }];
}


@end
