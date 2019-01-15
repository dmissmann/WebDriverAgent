//
//  FBImageIOScaler.h
//  WebDriverAgentLib
//
//  Created by David on 14.01.19.
//  Copyright © 2019 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FBImageIOScaler : NSObject

- (id)initWithScalingFactor:(NSUInteger)scalingFactor compressionQuality:(NSUInteger)compressionQuality;
- (void)submitImage:(NSData *)image completionHandler:(void(^)(NSData *scaled))completionHandler;

@end

NS_ASSUME_NONNULL_END
