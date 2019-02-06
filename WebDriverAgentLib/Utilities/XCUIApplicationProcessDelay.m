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

/**
 In certain cases WebDriverAgent fails to create a session because it waits for an app to quiescence,
 but they don't always do.
 The reason for this seems to be that 'testmanagerd' doesn't send the events WebDriverAgent is waiting for.
 The expected events would trigger calls to '-[XCUIApplicationProcess setEventLoopHasIdled:]' and
 '-[XCUIApplicationProcess setAnimationsHaveFinished:]', which are the properties that are checked to
 determine whether an app has quiescenced or not.
 Delaying the call to on of the setters can fix this issue. Setting the environment variable
 'DELAY_SET_EVENTLOOP_IDLE' will swizzle the method '-[XCUIApplicationProcess setEventLoopHasIdled:]'
 and add a thread sleep of the value specified in the environment variable in seconds.
 */
@interface XCUIApplicationProcessDelay : NSObject

@end

static void (*orig_set_event_loop_has_idled)(id, SEL, BOOL);
static NSUInteger delay = 0;

@implementation XCUIApplicationProcessDelay

+ (void)load {
  NSDictionary *env = [[NSProcessInfo processInfo] environment];
  NSString *setEventLoopIdleDelay = [env objectForKey:@"DELAY_SET_EVENTLOOP_IDLE"];
  if (!setEventLoopIdleDelay || [setEventLoopIdleDelay length] == 0) {
    [FBLogger verboseLog:@"don't delay -[XCUIApplicationProcess setEventLoopHasIdled:]"];
    return;
  }
  delay = [setEventLoopIdleDelay integerValue];
  Method original = class_getInstanceMethod([XCUIApplicationProcess class], @selector(setEventLoopHasIdled:));
  if (original == nil) {
    [FBLogger log:@"Could not find method -[XCUIApplicationProcess setEventLoopHasIdled:]"];
    return;
  }
  orig_set_event_loop_has_idled = (void(*)(id, SEL, BOOL)) method_getImplementation(original);
  Method replace = class_getClassMethod([XCUIApplicationProcessDelay class], @selector(setEventLoopHasIdled:));
  method_setImplementation(original, method_getImplementation(replace));
}

+ (void)setEventLoopHasIdled:(BOOL)idled {
  [FBLogger verboseLog:[NSString stringWithFormat:@"Delay -[XCUIApplicationProcess setEventLoopHasIdled:] by %lu seconds", (unsigned long)delay]];
  [NSThread sleepForTimeInterval:delay];
  orig_set_event_loop_has_idled(self, _cmd, idled);
}

@end
