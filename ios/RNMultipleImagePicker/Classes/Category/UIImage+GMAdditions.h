//
//  UIImage+GMAdditions.h
//  Pods
//
//  Created by wangjianfei on 2016/11/8.
//
//

#import <UIKit/UIKit.h>

@interface UIImage (GMAdditions)

+ (UIImage *)gm_fixOrientation:(UIImage *)srcImg;
+ (UIImage*)gm_downscaleImageIfNecessary:(UIImage*)image maxWidth:(float)maxWidth maxHeight:(float)maxHeight;

@end
