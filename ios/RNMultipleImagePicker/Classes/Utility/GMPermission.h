//
//  GMPermission.h
//  Pods
//
//  Created by wangjianfei on 2016/11/8.
//
//

#import <Foundation/Foundation.h>

@interface GMPermission : NSObject

+ (void)checkCameraPermissions:(void(^)(BOOL granted))callback;
+ (void)checkPhotosPermissions:(void(^)(BOOL granted))callback;

@end
