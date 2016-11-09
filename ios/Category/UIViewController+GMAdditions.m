//
//  UIViewController+GMAdditions.m
//  Pods
//
//  Created by wangjianfei on 2016/11/8.
//
//

#import "UIViewController+GMAdditions.h"

@implementation UIViewController (GMAdditions)

+ (UIViewController *)gm_toppestPresentedViewController {
    UIViewController *root = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    while (root.presentedViewController != nil) {
        root = root.presentedViewController;
    }
    return root;
}

@end
