//
//  MultipleImagePickerManager.h
//  RNMultipleImagePicker
//
//  Created by wangjianfei on 2016/11/4.
//  Copyright © 2016年 zheli.tech. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RCTBridgeModule.h"

typedef NS_ENUM(NSInteger, RNMultiImagePickerTarget) {
    RNMultiImagePickerTargetCamera = 1,
    RNMultiImagePickerTargetImages,
};

@interface MultipleImagePickerManager : NSObject <RCTBridgeModule, UINavigationControllerDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate>

@end
