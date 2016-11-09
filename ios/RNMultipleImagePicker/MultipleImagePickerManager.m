//
//  MultipleImagePickerManager.m
//  RNMultipleImagePicker
//
//  Created by wangjianfei on 2016/11/4.
//  Copyright © 2016年 zheli.tech. All rights reserved.
//

#import "MultipleImagePickerManager.h"
#import "RCTConvert.h"
#import "RCTUtils.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <BLPhotoAssetPickerController/BLPhotoAssetViewController.h>
#import <BLPhotoAssetPickerController/BLPhotoAssetPickerController.h>
#import <BLPhotoAssetPickerController/BLPhotoUtils.h>
#import <BLPhotoAssetPickerController/MBProgressHUD+Add.h>
#import <BLPhotoAssetPickerController/BLPhotoDataCenter.h>
#import <RMUniversalAlert/RMUniversalAlert.h>
#import "UIImage+GMAdditions.h"
#import "GMPermission.h"
#import "NSFileManager+GMAdditions.h"
#import "UIViewController+GMAdditions.h"

@interface MultipleImagePickerManager () <BLPhotoAssetPickerControllerDelegate>

@property (nonatomic, strong) UIAlertController *alertController;
@property (nonatomic, strong) UIImagePickerController *picker;
@property (nonatomic, strong) RCTResponseSenderBlock callback;
@property (nonatomic, strong) NSDictionary *defaultOptions;
@property (nonatomic, retain) NSMutableDictionary *options;
@property (nonatomic, strong) NSArray *customButtons;

@end

@implementation MultipleImagePickerManager {
    MBProgressHUD *_uploadHud;
    NSArray *_requestImageIdArray;
}

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(launchCamera:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback)
{
    self.options = [options mutableCopy];
    self.callback = callback;
    
#if TARGET_IPHONE_SIMULATOR
    self.callback(@[RCTMakeError(@"CAMERA_NOT_SUPPORT", nil, nil)]);
    return;
#else
    // Check permissions
    [GMPermission checkCameraPermissions:^(BOOL granted) {
        if (!granted) {
            self.callback(@[RCTMakeError(@"NO_CAMERA_PERMISSION", nil, nil)]);
            return;
        }
        
        self.picker = [[UIImagePickerController alloc] init];
        self.picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        if ([[self.options objectForKey:@"cameraType"] isEqualToString:@"front"]) {
            self.picker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
        }
        else { // "back"
            self.picker.cameraDevice = UIImagePickerControllerCameraDeviceRear;
        }
        self.picker.mediaTypes = @[(NSString *)kUTTypeImage];
        
        if ([[self.options objectForKey:@"allowsEditing"] boolValue]) {
            self.picker.allowsEditing = true;
        }
        self.picker.modalPresentationStyle = UIModalPresentationCurrentContext;
        self.picker.delegate = self;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *root = [UIViewController gm_toppestPresentedViewController];
            [root presentViewController:self.picker animated:YES completion:nil];
        });
    }];
#endif
}

RCT_EXPORT_METHOD(launchMultipleImagePicker:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback)
{
    self.options = [options mutableCopy];
    self.callback = callback;
    
    [GMPermission checkPhotosPermissions:^(BOOL granted) {
        if (!granted) {
            self.callback(@[RCTMakeError(@"NO_PHOTO_ALBUM_PERMISSION", nil, nil)]);
            return;
        }
        
        BLPhotoAssetViewController *assetViewController = [[BLPhotoAssetViewController alloc] init];
        assetViewController.maxSelectionNum = (self.options[@"maxSelectionNum"] ? [self.options[@"maxSelectionNum"] integerValue] : 9);
        assetViewController.cameraEnable = NO;
        BLPhotoAssetPickerController *pickerController = [[BLPhotoAssetPickerController alloc] initWithRootViewController:assetViewController];
        pickerController.assetDelegate = self;
        [BLPhotoUtils setUseCount:0];
        [BLPhotoUtils setWillUseCount:0];

        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *root = [UIViewController gm_toppestPresentedViewController];
            [root presentViewController:pickerController animated:YES completion:nil];
        });
    }];
}

RCT_EXPORT_METHOD(showImagePicker:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback)
{
    NSString *title = [options valueForKey:@"title"];
    if ([title isEqual:[NSNull null]] || title.length == 0) {
        title = nil; // A more visually appealing UIAlertControl is displayed with a nil title rather than title = @""
    }
    NSString *cancelTitle = [options valueForKey:@"cancelButtonTitle"];
    NSString *takePhotoButtonTitle = [options valueForKey:@"takePhotoButtonTitle"];
    NSString *chooseFromLibraryButtonTitle = [options valueForKey:@"chooseFromLibraryButtonTitle"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = [UIViewController gm_toppestPresentedViewController];
        [RMUniversalAlert showActionSheetInViewController:root
                                                withTitle:title
                                                  message:nil
                                        cancelButtonTitle:cancelTitle
                                   destructiveButtonTitle:nil
                                        otherButtonTitles:@[takePhotoButtonTitle, chooseFromLibraryButtonTitle]
                       popoverPresentationControllerBlock:nil
                                                 tapBlock:^(RMUniversalAlert * _Nonnull alert, NSInteger buttonIndex) {
                                                     if (buttonIndex == alert.cancelButtonIndex) {
                                                         // do nothing
                                                         callback(@[RCTMakeError(@"CANCELLED", nil, nil)]);
                                                     } else if (buttonIndex >= alert.firstOtherButtonIndex) {
                                                         if (buttonIndex == alert.firstOtherButtonIndex) {
                                                             [self launchCamera:options callback:callback];
                                                         } else {
                                                             [self launchMultipleImagePicker:options callback:callback];
                                                         }
                                                     }
                                                 }];
    });
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    dispatch_block_t dismissCompletionBlock = ^{
        NSURL *imageURL = [info valueForKey:UIImagePickerControllerReferenceURL];
        NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
        
        // We default to path to the temporary directory
        NSString *path = [self _defaultCachePathForImageURL:imageURL mediaType:mediaType];
        
        // If storage options are provided, we use the documents directory which is persisted
        NSError *error = nil;
        path = [self _resetCachePathIfNeeded:path error:&error];
        if (error) {
            self.callback(@[RCTMakeError(@"CREATE_CACHE_DIR_FAILED", nil, nil)]);
            return;
        }
        
        UIImage *image;
        if ([[self.options objectForKey:@"allowsEditing"] boolValue]) {
            image = [info objectForKey:UIImagePickerControllerEditedImage];
        }
        else {
            image = [info objectForKey:UIImagePickerControllerOriginalImage];
        }
        
        // GIFs break when resized, so we handle them differently
        if (imageURL && [[imageURL absoluteString] rangeOfString:@"ext=GIF"].location != NSNotFound) {
            [self _gitResponseForImage:image imageURL:imageURL cachePath:path completionBlock:^(NSError *error, NSDictionary *response) {
                if (error) {
                    self.callback(@[RCTMakeError(@"ACCESS_IMAGE_FAILED", nil, nil)]);
                } else {
                    self.callback(@[[NSNull null], @[response]]);
                }
            }];
        } else {
            [self _responseForImage:image imageURL:imageURL cachePath:path completionBlock:^(NSError *error, NSDictionary *response) {
                if (error) {
                    self.callback(@[RCTMakeError(@"ACCESS_IMAGE_FAILED", nil, nil)]);
                } else {
                    self.callback(@[[NSNull null], @[response]]);
                }
            }];
        }
    };
    dispatch_async(dispatch_get_main_queue(), ^{
        [picker dismissViewControllerAnimated:YES completion:dismissCompletionBlock];
    });
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [picker dismissViewControllerAnimated:YES completion:^{
            self.callback(@[RCTMakeError(@"CANCELLED", nil, nil)]);
        }];
    });
}

- (void)savedImage:(UIImage *)image hasBeenSavedInPhotoAlbumWithError:(NSError *)error usingContextInfo:(void*)ctxInfo {
    if (error) {
        NSLog(@"Error while saving picture into photo album");
    } else {
        // when the image has been saved in the photo album
        self.callback(@[[NSNull null], @[(__bridge NSDictionary *)ctxInfo]]);
    }
}

- (NSString *)_defaultCachePathForImageURL:(NSURL *)imageURL mediaType:(NSString *)mediaType {
    NSString *fileName;
    if ([mediaType isEqualToString:(NSString *)kUTTypeImage]) {
        NSString *tempFileName = [[NSUUID UUID] UUIDString];
        if (imageURL && [[imageURL absoluteString] rangeOfString:@"ext=GIF"].location != NSNotFound) {
            fileName = [tempFileName stringByAppendingString:@".gif"];
        }
        else if ([[[self.options objectForKey:@"imageFileType"] stringValue] isEqualToString:@"png"]) {
            fileName = [tempFileName stringByAppendingString:@".png"];
        }
        else {
            fileName = [tempFileName stringByAppendingString:@".jpg"];
        }
    }
    return [[NSTemporaryDirectory() stringByStandardizingPath] stringByAppendingPathComponent:fileName];
}

- (NSString *)_resetCachePathIfNeeded:(NSString *)path error:(NSError **)error {
    if ([self.options objectForKey:@"storageOptions"] && [[self.options objectForKey:@"storageOptions"] isKindOfClass:[NSDictionary class]]) {
        NSString *fileName = [path lastPathComponent];
        NSDictionary *storageOptions = [self.options objectForKey:@"storageOptions"];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        
        // Creates documents subdirectory, if provided
        if ([storageOptions objectForKey:@"path"]) {
            NSString *newPath = [documentsDirectory stringByAppendingPathComponent:[storageOptions objectForKey:@"path"]];
            [[NSFileManager defaultManager] createDirectoryAtPath:newPath withIntermediateDirectories:YES attributes:nil error:error];
            if (*error == nil) {
                path = [newPath stringByAppendingPathComponent:fileName];
            }
        } else {
            path = [documentsDirectory stringByAppendingPathComponent:fileName];
        }
    }
    return path;
}

- (void)_gitResponseForImage:(UIImage *)image imageURL:(NSURL *)imageURL cachePath:(NSString *)cachePath completionBlock:(void (^)(NSError *error, NSDictionary *response))completionBlock {
    ALAssetsLibrary* assetsLibrary = [[ALAssetsLibrary alloc] init];
    [assetsLibrary assetForURL:imageURL resultBlock:^(ALAsset *asset) {
        ALAssetRepresentation *rep = [asset defaultRepresentation];
        Byte *buffer = (Byte*)malloc(rep.size);
        NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
        NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
        [data writeToFile:cachePath atomically:YES];
        
        NSMutableDictionary *gifResponse = [[NSMutableDictionary alloc] init];
        [gifResponse setObject:@(image.size.width) forKey:@"width"];
        [gifResponse setObject:@(image.size.height) forKey:@"height"];
        
        BOOL vertical = (image.size.width < image.size.height) ? YES : NO;
        [gifResponse setObject:@(vertical) forKey:@"isVertical"];
        
        if (![[self.options objectForKey:@"noData"] boolValue]) {
            NSString *dataString = [data base64EncodedStringWithOptions:0];
            [gifResponse setObject:dataString forKey:@"data"];
        }
        
        NSURL *fileURL = [NSURL fileURLWithPath:cachePath];
        [gifResponse setObject:[fileURL absoluteString] forKey:@"uri"];
        
        NSNumber *fileSizeValue = nil;
        NSError *fileSizeError = nil;
        [fileURL getResourceValue:&fileSizeValue forKey:NSURLFileSizeKey error:&fileSizeError];
        if (fileSizeValue){
            [gifResponse setObject:fileSizeValue forKey:@"fileSize"];
        }
        completionBlock(nil, gifResponse);
    } failureBlock:^(NSError *error) {
        completionBlock(error, nil);
    }];
}

- (void)_responseForImage:(UIImage *)image imageURL:(NSURL *)imageURL cachePath:(NSString *)cachePath completionBlock:(void (^)(NSError *error, NSDictionary *response))completionBlock {
    NSMutableDictionary *response = [NSMutableDictionary dictionary];
    
    // GIFs break when resized, so we handle them differently
    image = [UIImage gm_fixOrientation:image];  // Rotate the image for upload to web
    
    // If needed, downscale image
    float maxWidth = image.size.width;
    float maxHeight = image.size.height;
    if ([self.options valueForKey:@"maxWidth"]) {
        maxWidth = [[self.options valueForKey:@"maxWidth"] floatValue];
    }
    if ([self.options valueForKey:@"maxHeight"]) {
        maxHeight = [[self.options valueForKey:@"maxHeight"] floatValue];
    }
    image = [UIImage gm_downscaleImageIfNecessary:image maxWidth:maxWidth maxHeight:maxHeight];
    
    NSData *data;
    if ([[[self.options objectForKey:@"imageFileType"] stringValue] isEqualToString:@"png"]) {
        data = UIImagePNGRepresentation(image);
    }
    else {
        data = UIImageJPEGRepresentation(image, [[self.options valueForKey:@"quality"] floatValue]);
    }
    [data writeToFile:cachePath atomically:YES];
    
    if (![[self.options objectForKey:@"noData"] boolValue]) {
        NSString *dataString = [data base64EncodedStringWithOptions:0]; // base64 encoded image string
        [response setObject:dataString forKey:@"data"];
    }
    
    BOOL vertical = (image.size.width < image.size.height) ? YES : NO;
    [response setObject:@(vertical) forKey:@"isVertical"];
    NSURL *fileURL = [NSURL fileURLWithPath:cachePath];
    NSString *filePath = [fileURL absoluteString];
    [response setObject:filePath forKey:@"uri"];
    
    // add ref to the original image
    NSString *origURL = [imageURL absoluteString];
    if (origURL) {
        [response setObject:origURL forKey:@"origURL"];
    }
    
    NSNumber *fileSizeValue = nil;
    NSError *fileSizeError = nil;
    [fileURL getResourceValue:&fileSizeValue forKey:NSURLFileSizeKey error:&fileSizeError];
    if (fileSizeValue){
        [response setObject:fileSizeValue forKey:@"fileSize"];
    }
    
    [response setObject:@(image.size.width) forKey:@"width"];
    [response setObject:@(image.size.height) forKey:@"height"];
    
    NSDictionary *storageOptions = [self.options objectForKey:@"storageOptions"];
    if (storageOptions && [[storageOptions objectForKey:@"cameraRoll"] boolValue] == YES && self.picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
        if ([[storageOptions objectForKey:@"waitUntilSaved"] boolValue]) {
            UIImageWriteToSavedPhotosAlbum(image, self, @selector(savedImage : hasBeenSavedInPhotoAlbumWithError : usingContextInfo :), (__bridge void * _Nullable)(response));
        } else {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
        }
    }
    
    // If storage options are provided, check the skipBackup flag
    if ([self.options objectForKey:@"storageOptions"] && [[self.options objectForKey:@"storageOptions"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *storageOptions = [self.options objectForKey:@"storageOptions"];
        
        if ([[storageOptions objectForKey:@"skipBackup"] boolValue]) {
            [NSFileManager gm_addSkipBackupAttributeToItemAtPath:cachePath]; // Don't back up the file to iCloud
        }
        
        if (![[storageOptions objectForKey:@"waitUntilSaved"] boolValue]) {
            completionBlock(nil, response);
        }
    }
    else {
        completionBlock(nil, response);
    }
}

#pragma mark - BLPhotoAssetPickerControllerDelegate

- (void)assetPickerController:(BLPhotoAssetPickerController *)picker didFinishPickingAssets:(NSArray *)assets {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    __block NSMutableArray *array = [NSMutableArray array];
    __block NSInteger fetchData = 0;
    [BLPhotoDataCenter getThumbnailDataFromAssets:assets WithBlock:^(NSArray *thumbarray) {
        fetchData = 1;
        
    } withRequestIDBlock:^(NSArray *requestArray) {
        _requestImageIdArray = requestArray;
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (fetchData == 0) {
            _uploadHud = [MBProgressHUD showProcessTip:@"正在加载..."];
            [_uploadHud addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cancelLoadThumbnailAlert)]];
        }
    });
}

- (void)assetPickerControllerDidCancel:(BLPhotoAssetPickerController *)picker {
    self.callback(@[RCTMakeError(@"CANCELLED", nil, nil)]);
}

- (void)cancelLoadThumbnailAlert {
    __weak typeof(self) weakSelf = self;
    [RMUniversalAlert showAlertInViewController:self
                                      withTitle:@"取消图片加载？"
                                        message:nil
                              cancelButtonTitle:@"否"
                         destructiveButtonTitle:@"是"
                              otherButtonTitles:nil
                                       tapBlock:^(RMUniversalAlert * _Nonnull alert, NSInteger buttonIndex) {
                                           __strong typeof(self) strongSelf = weakSelf;
                                           if (buttonIndex != alert.cancelButtonIndex) {
                                               [strongSelf cancelLoadThumbnail];
                                           }
                                       }];
}

- (void)cancelLoadThumbnail {
    [_uploadHud hide:YES];
    if (_requestImageIdArray && _requestImageIdArray.count >0) {
        for (int i = 0; i<_requestImageIdArray.count; i++) {
            [[PHImageManager defaultManager] cancelImageRequest:[[_requestImageIdArray objectAtIndex:i] intValue]];
        }
    }
    _requestImageIdArray = nil;
    [BLPhotoUtils setUseCount:0];
    [BLPhotoUtils setWillUseCount:0];
    
    self.callback(@[RCTMakeError(@"CANCELLED", nil, nil)]);
}

@end
