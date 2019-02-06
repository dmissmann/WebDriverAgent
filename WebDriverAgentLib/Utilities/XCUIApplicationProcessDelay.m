/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <objc/runtime.h>
#import "XCUIApplicationProcess.h"
#import "FBLogger.h"

static void (*orig_set_event_loop_has_idled)(id, SEL, BOOL);
static unsigned int delay = 0;

@interface XCUIApplicationProcessDelay : NSObject

@end

@implementation XCUIApplicationProcessDelay

+ (void)load {
  NSDictionary *env = [[NSProcessInfo processInfo] environment];
  NSString *setEventLoopIdleDelay = [env objectForKey:@"DELAY_SET_EVENTLOOP_IDLE"];
  if (!setEventLoopIdleDelay || [setEventLoopIdleDelay length] == 0) {
    [FBLogger verboseLog:@"don't delay -[XCUIApplicationProcess setEventLoopHasIdled:]"];
    return;
  }
  delay = [setEventLoopIdleDelay intValue];
  Method original = class_getInstanceMethod([XCUIApplicationProcess class], @selector(setEventLoopHasIdled:));
  if (original == nil) {
    [FBLogger log:@"Could not find method -[XCUIApplicationProcess setEventLoopHasIdled:]"];
    return;
  }
  [FBLogger verboseLog:[NSString stringWithFormat:@"Delay -[XCUIApplicationProcess setEventLoopHasIdled:] by %u seconds", delay]];
  orig_set_event_loop_has_idled = (void(*)(id, SEL, BOOL)) method_getImplementation(original);
  Method replace = class_getClassMethod([XCUIApplicationProcessDelay class], @selector(setEventLoopHasIdled:));
  method_setImplementation(original, method_getImplementation(replace));
}

+ (void)setEventLoopHasIdled:(BOOL)idled {
  sleep(delay);
  orig_set_event_loop_has_idled(self, _cmd, idled);
}

@end
