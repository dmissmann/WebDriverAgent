//
//  FBCIImageScaler.h
//  WebDriverAgentLib
//
//  Created by David on 05.01.19.
//  Copyright © 2019 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Scales images and compresses it to JPEG using CoreImage
 It allows to enqueue only a single screenshot. If a new one arrives before the currently queued gets discared
 */
@interface FBCIImageScaler : NSObject

- (id)initWithScalingFactor:(NSUInteger)scalingFactor compressionQuality:(NSUInteger)compressionQuality;
- (void)submitImage:(NSData *)image completionHandler:(void(^)(NSData *scaled))completionHandler;

@end

NS_ASSUME_NONNULL_END
