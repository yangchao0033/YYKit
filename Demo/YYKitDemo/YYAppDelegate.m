//
//  AppDelegate.m
//  YYKitExample
//
//  Created by ibireme on 14-9-18.
//  Copyright (c) 2014 ibireme. All rights reserved.
//

#import "YYAppDelegate.h"
#import "YYRootViewController.h"

/// Fix the navigation bar height when hide status bar.
@interface YYExampleNavBar : UINavigationBar
@end

@implementation YYExampleNavBar {
    CGSize _previousSize;
}

- (CGSize)sizeThatFits:(CGSize)size {
    size = [super sizeThatFits:size];
    if ([UIApplication sharedApplication].statusBarHidden) {
        size.height = 64;
    }
    return size;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!CGSizeEqualToSize(self.bounds.size, _previousSize)) {
        _previousSize = self.bounds.size;
        [self.layer removeAllAnimations];
        [self.layer.sublayers enumerateObjectsUsingBlock:^(CALayer *layer, NSUInteger idx, BOOL *stop) {
            [layer removeAllAnimations];
        }];
    }
}

@end

@interface YYExampleNavController : UINavigationController
@end
@implementation YYExampleNavController
/** 设置当前控制器的view在屏幕旋转时是否自动旋转，默认为YES */
- (BOOL)shouldAutorotate {
    return YES;
}

/** 用二进制枚举标志指定可以旋转地方向，且返回值不可为0
 当用户改变设备方向时，系统调用该方法在根控制器或者最顶层的存在的并且填充在window上得控制器上。如果视图控制器支持新的旋转方向，window和视图控制器会被旋转为新的方向，该方法仅当shouldAutorotate返回为YES时被调用。
 Override this method to report all of the orientations that the view controller supports. The default values for a view controller's supported interface orientations is set to UIInterfaceOrientationMaskAll for the iPad idiom and UIInterfaceOrientationMaskAllButUpsideDown for the iPhone idiom.
 
 The system intersects the view controller's supported orientations with the app's supported orientations (as determined by the Info.plist file or the app delegate's application:supportedInterfaceOrientationsForWindow: method) to determine whether to rotate.
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

@end



@implementation YYAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
//    YYRootViewController *root = [YYRootViewController new];
//    YYExampleNavController *nav = [[YYExampleNavController alloc] initWithNavigationBarClass:[YYExampleNavBar class] toolbarClass:[UIToolbar class]];
//    if ([nav respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)]) {
//        nav.automaticallyAdjustsScrollViewInsets = NO;
//    }
//    [nav pushViewController:root animated:NO];
//    
//    self.rootViewController = nav;
//    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
//    self.window.rootViewController = self.rootViewController;
//    self.window.backgroundColor = [UIColor grayColor];
//    [self.window makeKeyAndVisible];
    YYRootViewController *root1 = [YYRootViewController new];
    YYExampleNavController *nav1 = [[YYExampleNavController alloc] initWithNavigationBarClass:[YYExampleNavBar class] toolbarClass:[UIToolbar class]];
    if ([nav1 respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)]) {
        nav1.automaticallyAdjustsScrollViewInsets = NO;
    }
    [nav1 pushViewController:root1 animated:YES];
    
    self.rootViewController = nav1;
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = self.rootViewController;
    self.window.backgroundColor = [UIColor grayColor];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
