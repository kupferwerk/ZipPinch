//
//  ZipTableViewController.m
//  ZipPinch
//
//  Created by Kupferwerk on 07.03.16.
//  Copyright © 2016 NARR8. All rights reserved.
//

#import "ZipTableViewController.h"
#import "ZPManager.h"

#import "ZipEntryViewController.h"

static NSString *const ViewControllerImageSegue = @"imageSegue";

@interface ZipTableViewController ()

@property (strong, nonatomic) ZPEntry* selectedZipEntry;

@end

@implementation ZipTableViewController

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:ViewControllerImageSegue]) {
        ZipEntryViewController* target = segue.destinationViewController;
        target.zipManager = _zipManager;
        target.selectedZipEntry = self.selectedZipEntry;
        target.title =_zipManager.URL.host;
    }
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _zipManager.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *const cellId = @"cellId";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
    }
    
    ZPEntry *entry = _zipManager.entries[indexPath.row];
    
    cell.textLabel.text = entry.filePath;
    cell.detailTextLabel.text = [NSByteCountFormatter stringFromByteCount:entry.sizeCompressed countStyle: NSByteCountFormatterCountStyleFile];
    cell.accessoryType = ([self isImageWithFileName:entry.filePath]
                          ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone);
    
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ZPEntry *entry = _zipManager.entries[indexPath.row];
    
    return [self isImageWithFileName:entry.filePath] ? indexPath : nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.selectedZipEntry = _zipManager.entries[indexPath.row];
    [self performSegueWithIdentifier:ViewControllerImageSegue sender:nil];
}

#pragma mark - Helper method

- (BOOL)isImageWithFileName:(NSString *)fileName
{
    NSString *extension = [[fileName pathExtension] lowercaseString];
    return [extension isEqual:@"jpg"] || [extension isEqual:@"png"] || [extension isEqual:@"gif"] || [extension isEqual:@"jpeg"];
}

@end
