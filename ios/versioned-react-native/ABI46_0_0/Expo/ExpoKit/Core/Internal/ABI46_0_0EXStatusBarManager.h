
#import <UIKit/UIKit.h>

#import <ABI46_0_0React/ABI46_0_0RCTConvert.h>
#import <ABI46_0_0React/ABI46_0_0RCTEventEmitter.h>

@interface ABI46_0_0RCTConvert (ABI46_0_0EXStatusBar)

#if !TARGET_OS_TV
+ (UIStatusBarStyle)UIStatusBarStyle:(id)json;
+ (UIStatusBarAnimation)UIStatusBarAnimation:(id)json;
#endif

@end

@interface ABI46_0_0EXStatusBarManager : ABI46_0_0RCTEventEmitter

@end
