//
//  MultipleImagePickerManager.m
//  RNMultipleImagePicker
//
//  Created by wangjianfei on 2016/11/4.
//  Copyright © 2016年 zheli.tech. All rights reserved.
//

#import "MultipleImagePickerManager.h"
#import "RCTConvert.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface MultipleImagePickerManager ()

@property (nonatomic, strong) UIAlertController *alertController;
@property (nonatomic, strong) UIImagePickerController *picker;
@property (nonatomic, strong) RCTResponseSenderBlock callback;
@property (nonatomic, strong) NSDictionary *defaultOptions;
@property (nonatomic, retain) NSMutableDictionary *options, *response;

@end

@implementation MultipleImagePickerManager

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(launchCamera:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback)
{
    self.callback = callback;
    [self launchImagePicker:RNMultiImagePickerTargetCamera options:options];
}

- (void)launchImagePicker:(RNMultiImagePickerTarget)target options:(NSDictionary *)options
{
    self.options = [options mutableCopy];
    [self launchImagePicker:target];
}

- (void)launchImagePicker:(RNMultiImagePickerTarget)target
{
    self.picker = [[UIImagePickerController alloc] init];
    
#if TARGET_IPHONE_SIMULATOR
    self.callback(@[@{@"error": @"Camera not available on simulator"}]);
    return;
#else
    self.picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    if ([[self.options objectForKey:@"cameraType"] isEqualToString:@"front"]) {
        self.picker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    }
    else { // "back"
        self.picker.cameraDevice = UIImagePickerControllerCameraDeviceRear;
    }
#endif
    
    self.picker.mediaTypes = @[(NSString *)kUTTypeImage];
    
    if ([[self.options objectForKey:@"allowsEditing"] boolValue]) {
        self.picker.allowsEditing = true;
    }
    self.picker.modalPresentationStyle = UIModalPresentationCurrentContext;
    self.picker.delegate = self;
    
    // Check permissions
    void (^showPickerViewController)() = ^void() {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *root = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
            while (root.presentedViewController != nil) {
                root = root.presentedViewController;
            }
            [root presentViewController:self.picker animated:YES completion:nil];
        });
    };
    
    [self checkCameraPermissions:^(BOOL granted) {
        if (!granted) {
            self.callback(@[@{@"error": @"Camera permissions not granted"}]);
            return;
        }
        
        showPickerViewController();
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    dispatch_block_t dismissCompletionBlock = ^{
        
        NSURL *imageURL = [info valueForKey:UIImagePickerControllerReferenceURL];
        NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
        
        
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
        else {
            NSURL *videoURL = info[UIImagePickerControllerMediaURL];
            fileName = videoURL.lastPathComponent;
        }
        
        // We default to path to the temporary directory
        NSString *path = [[NSTemporaryDirectory()stringByStandardizingPath] stringByAppendingPathComponent:fileName];
        
        // If storage options are provided, we use the documents directory which is persisted
        if ([self.options objectForKey:@"storageOptions"] && [[self.options objectForKey:@"storageOptions"] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *storageOptions = [self.options objectForKey:@"storageOptions"];
            
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths objectAtIndex:0];
            path = [documentsDirectory stringByAppendingPathComponent:fileName];
            
            // Creates documents subdirectory, if provided
            if ([storageOptions objectForKey:@"path"]) {
                NSString *newPath = [documentsDirectory stringByAppendingPathComponent:[storageOptions objectForKey:@"path"]];
                NSError *error;
                [[NSFileManager defaultManager] createDirectoryAtPath:newPath withIntermediateDirectories:YES attributes:nil error:&error];
                if (error) {
                    NSLog(@"Error creating documents subdirectory: %@", error);
                    self.callback(@[@{@"error": error.localizedFailureReason}]);
                    return;
                }
                else {
                    path = [newPath stringByAppendingPathComponent:fileName];
                }
            }
        }
        
        // Create the response object
        self.response = [[NSMutableDictionary alloc] init];
        
        if ([mediaType isEqualToString:(NSString *)kUTTypeImage]) { // PHOTOS
            UIImage *image;
            if ([[self.options objectForKey:@"allowsEditing"] boolValue]) {
                image = [info objectForKey:UIImagePickerControllerEditedImage];
            }
            else {
                image = [info objectForKey:UIImagePickerControllerOriginalImage];
            }
            
            // GIFs break when resized, so we handle them differently
            if (imageURL && [[imageURL absoluteString] rangeOfString:@"ext=GIF"].location != NSNotFound) {
                ALAssetsLibrary* assetsLibrary = [[ALAssetsLibrary alloc] init];
                [assetsLibrary assetForURL:imageURL resultBlock:^(ALAsset *asset) {
                    ALAssetRepresentation *rep = [asset defaultRepresentation];
                    Byte *buffer = (Byte*)malloc(rep.size);
                    NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
                    NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
                    [data writeToFile:path atomically:YES];
                    
                    NSMutableDictionary *gifResponse = [[NSMutableDictionary alloc] init];
                    [gifResponse setObject:@(image.size.width) forKey:@"width"];
                    [gifResponse setObject:@(image.size.height) forKey:@"height"];
                    
                    BOOL vertical = (image.size.width < image.size.height) ? YES : NO;
                    [gifResponse setObject:@(vertical) forKey:@"isVertical"];
                    
                    if (![[self.options objectForKey:@"noData"] boolValue]) {
                        NSString *dataString = [data base64EncodedStringWithOptions:0];
                        [gifResponse setObject:dataString forKey:@"data"];
                    }
                    
                    NSURL *fileURL = [NSURL fileURLWithPath:path];
                    [gifResponse setObject:[fileURL absoluteString] forKey:@"uri"];
                    
                    NSNumber *fileSizeValue = nil;
                    NSError *fileSizeError = nil;
                    [fileURL getResourceValue:&fileSizeValue forKey:NSURLFileSizeKey error:&fileSizeError];
                    if (fileSizeValue){
                        [gifResponse setObject:fileSizeValue forKey:@"fileSize"];
                    }
                    
                    self.callback(@[gifResponse]);
                } failureBlock:^(NSError *error) {
                    self.callback(@[@{@"error": error.localizedFailureReason}]);
                }];
                return;
            }
            
            image = [self fixOrientation:image];  // Rotate the image for upload to web
            
            // If needed, downscale image
            float maxWidth = image.size.width;
            float maxHeight = image.size.height;
            if ([self.options valueForKey:@"maxWidth"]) {
                maxWidth = [[self.options valueForKey:@"maxWidth"] floatValue];
            }
            if ([self.options valueForKey:@"maxHeight"]) {
                maxHeight = [[self.options valueForKey:@"maxHeight"] floatValue];
            }
            image = [self downscaleImageIfNecessary:image maxWidth:maxWidth maxHeight:maxHeight];
            
            NSData *data;
            if ([[[self.options objectForKey:@"imageFileType"] stringValue] isEqualToString:@"png"]) {
                data = UIImagePNGRepresentation(image);
            }
            else {
                data = UIImageJPEGRepresentation(image, [[self.options valueForKey:@"quality"] floatValue]);
            }
            [data writeToFile:path atomically:YES];
            
            if (![[self.options objectForKey:@"noData"] boolValue]) {
                NSString *dataString = [data base64EncodedStringWithOptions:0]; // base64 encoded image string
                [self.response setObject:dataString forKey:@"data"];
            }
            
            BOOL vertical = (image.size.width < image.size.height) ? YES : NO;
            [self.response setObject:@(vertical) forKey:@"isVertical"];
            NSURL *fileURL = [NSURL fileURLWithPath:path];
            NSString *filePath = [fileURL absoluteString];
            [self.response setObject:filePath forKey:@"uri"];
            
            // add ref to the original image
            NSString *origURL = [imageURL absoluteString];
            if (origURL) {
                [self.response setObject:origURL forKey:@"origURL"];
            }
            
            NSNumber *fileSizeValue = nil;
            NSError *fileSizeError = nil;
            [fileURL getResourceValue:&fileSizeValue forKey:NSURLFileSizeKey error:&fileSizeError];
            if (fileSizeValue){
                [self.response setObject:fileSizeValue forKey:@"fileSize"];
            }
            
            [self.response setObject:@(image.size.width) forKey:@"width"];
            [self.response setObject:@(image.size.height) forKey:@"height"];
            
            NSDictionary *storageOptions = [self.options objectForKey:@"storageOptions"];
            if (storageOptions && [[storageOptions objectForKey:@"cameraRoll"] boolValue] == YES && self.picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
                if ([[storageOptions objectForKey:@"waitUntilSaved"] boolValue]) {
                    UIImageWriteToSavedPhotosAlbum(image, self, @selector(savedImage : hasBeenSavedInPhotoAlbumWithError : usingContextInfo :), nil);
                } else {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
                }
            }
        }
        else { // VIDEO
            NSURL *videoRefURL = info[UIImagePickerControllerReferenceURL];
            NSURL *videoURL = info[UIImagePickerControllerMediaURL];
            NSURL *videoDestinationURL = [NSURL fileURLWithPath:path];
            
            if ([videoURL.URLByResolvingSymlinksInPath.path isEqualToString:videoDestinationURL.URLByResolvingSymlinksInPath.path] == NO) {
                NSFileManager *fileManager = [NSFileManager defaultManager];
                
                // Delete file if it already exists
                if ([fileManager fileExistsAtPath:videoDestinationURL.path]) {
                    [fileManager removeItemAtURL:videoDestinationURL error:nil];
                }
                
                NSError *error = nil;
                [fileManager moveItemAtURL:videoURL toURL:videoDestinationURL error:&error];
                if (error) {
                    self.callback(@[@{@"error": error.localizedFailureReason}]);
                    return;
                }
            }
            
            [self.response setObject:videoDestinationURL.absoluteString forKey:@"uri"];
            if (videoRefURL.absoluteString) {
                [self.response setObject:videoRefURL.absoluteString forKey:@"origURL"];
            }
            
            NSDictionary *storageOptions = [self.options objectForKey:@"storageOptions"];
            if (storageOptions && [[storageOptions objectForKey:@"cameraRoll"] boolValue] == YES && self.picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
                ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                [library writeVideoAtPathToSavedPhotosAlbum:videoDestinationURL completionBlock:^(NSURL *assetURL, NSError *error) {
                    if (error) {
                        self.callback(@[@{@"error": error.localizedFailureReason}]);
                        return;
                    } else {
                        NSLog(@"Save video succeed.");
                        if ([[storageOptions objectForKey:@"waitUntilSaved"] boolValue]) {
                            self.callback(@[self.response]);
                        }
                    }
                }];
            }
        }
        
        // If storage options are provided, check the skipBackup flag
        if ([self.options objectForKey:@"storageOptions"] && [[self.options objectForKey:@"storageOptions"] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *storageOptions = [self.options objectForKey:@"storageOptions"];
            
            if ([[storageOptions objectForKey:@"skipBackup"] boolValue]) {
                [self addSkipBackupAttributeToItemAtPath:path]; // Don't back up the file to iCloud
            }
            
            if (![[storageOptions objectForKey:@"waitUntilSaved"] boolValue]) {
                self.callback(@[self.response]);
            }
        }
        else {
            self.callback(@[self.response]);
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
            self.callback(@[@{@"didCancel": @YES}]);
        }];
    });
}

- (void)savedImage:(UIImage *)image hasBeenSavedInPhotoAlbumWithError:(NSError *)error usingContextInfo:(void*)ctxInfo {
    if (error) {
        NSLog(@"Error while saving picture into photo album");
    } else {
        // when the image has been saved in the photo album
        self.callback(@[self.response]);
    }
}

#pragma mark - Helpers

- (void)checkCameraPermissions:(void(^)(BOOL granted))callback
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusAuthorized) {
        callback(YES);
        return;
    } else if (status == AVAuthorizationStatusNotDetermined){
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            callback(granted);
            return;
        }];
    } else {
        callback(NO);
    }
}

- (void)checkPhotosPermissions:(void(^)(BOOL granted))callback
{
    if (![PHPhotoLibrary class]) { // iOS 7 support
        callback(YES);
        return;
    }
    
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusAuthorized) {
        callback(YES);
        return;
    } else if (status == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                callback(YES);
                return;
            }
            else {
                callback(NO);
                return;
            }
        }];
    }
    else {
        callback(NO);
    }
}

- (UIImage*)downscaleImageIfNecessary:(UIImage*)image maxWidth:(float)maxWidth maxHeight:(float)maxHeight
{
    UIImage* newImage = image;
    
    // Nothing to do here
    if (image.size.width <= maxWidth && image.size.height <= maxHeight) {
        return newImage;
    }
    
    CGSize scaledSize = CGSizeMake(image.size.width, image.size.height);
    if (maxWidth < scaledSize.width) {
        scaledSize = CGSizeMake(maxWidth, (maxWidth / scaledSize.width) * scaledSize.height);
    }
    if (maxHeight < scaledSize.height) {
        scaledSize = CGSizeMake((maxHeight / scaledSize.height) * scaledSize.width, maxHeight);
    }
    
    // If the pixels are floats, it causes a white line in iOS8 and probably other versions too
    scaledSize.width = (int)scaledSize.width;
    scaledSize.height = (int)scaledSize.height;
    
    UIGraphicsBeginImageContext(scaledSize); // this will resize
    [image drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    if (newImage == nil) {
        NSLog(@"could not scale image");
    }
    UIGraphicsEndImageContext();
    
    return newImage;
}

- (UIImage *)fixOrientation:(UIImage *)srcImg {
    if (srcImg.imageOrientation == UIImageOrientationUp) {
        return srcImg;
    }
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    switch (srcImg.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, srcImg.size.width, srcImg.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, srcImg.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, srcImg.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
    }
    
    switch (srcImg.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, srcImg.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, srcImg.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationDown:
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
            break;
    }
    
    CGContextRef ctx = CGBitmapContextCreate(NULL, srcImg.size.width, srcImg.size.height, CGImageGetBitsPerComponent(srcImg.CGImage), 0, CGImageGetColorSpace(srcImg.CGImage), CGImageGetBitmapInfo(srcImg.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (srcImg.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            CGContextDrawImage(ctx, CGRectMake(0,0,srcImg.size.height,srcImg.size.width), srcImg.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,srcImg.size.width,srcImg.size.height), srcImg.CGImage);
            break;
    }
    
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

- (BOOL)addSkipBackupAttributeToItemAtPath:(NSString *) filePathString
{
    NSURL* URL= [NSURL fileURLWithPath: filePathString];
    if ([[NSFileManager defaultManager] fileExistsAtPath: [URL path]]) {
        NSError *error = nil;
        BOOL success = [URL setResourceValue: [NSNumber numberWithBool: YES]
                                      forKey: NSURLIsExcludedFromBackupKey error: &error];
        
        if(!success){
            NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
        }
        return success;
    }
    else {
        NSLog(@"Error setting skip backup attribute: file not found");
        return @NO;
    }
}

@end
