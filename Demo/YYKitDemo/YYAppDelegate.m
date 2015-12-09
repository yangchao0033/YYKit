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
/** 设置当前控制器的view在屏幕旋转时是否自动旋转，默认为YES
     当为根控制器或model显示的控制器
 */
- (BOOL)shouldAutorotate {
    return YES;
}

/** 
 用二进制枚举标志指定可以旋转地方向，且返回值不可为0当用户改变设备方向时，系统调用该方法在根控制器或者最顶层的并且为模态（modal）展示的的并且填充在window上得控制器上。如果视图控制器支持新的旋转方向，window和视图控制器会被旋转为新的方向，该方法仅当shouldAutorotate返回为YES时被调用。
 重写这个方法来告诉系统当前视图控制器所支持的所有旋转方向，iPad默认返回值为UIInterfaceOrientationMaskAll（支持所有方向）
 iPhone默认为UIInterfaceOrientationMaskAllButUpsideDown（非向倒置的所有方向）
 与系统相交的控制器支持的旋转方向与app支持的旋转方向一致（比如info.plist文件或者代理application:supportedInterfaceOrientationsForWindow:指定的方向）
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

/*!
 *  @author 杨超, 15-12-07 11:12:19
 *
 *  @brief 配合supportedInterfaceOrientations方法实现非root视图控制器或modal出得控制器的屏幕旋转控制
 *
 *  @return 指定屏幕旋转方向
 */
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
        /** 
         The default value of this property is YES, which allows the view controller to adjust its scroll view insets in response to the screen areas consumed by the status bar, navigation bar, and toolbar or tab bar. Set to NO if you want to manage scroll view inset adjustments yourself, such as when there is more than one scroll view in the view hierarchy.
         默认值为YES，该属性允许系统通过导航栏或者toolbar或者tab bar去调整视图控制器中的scrollView的内边距，如果想自己手动管理内边距则设置为NO，比如在垂直方向有一个或多个scrollview
         */
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
