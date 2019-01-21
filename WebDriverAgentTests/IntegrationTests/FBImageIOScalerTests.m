/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>
#import "FBImageIOScaler.h"

@interface FBImageIOScalerTests : XCTestCase

@property (nonatomic) NSData *originalImage;
@property (nonatomic) CGSize originalSize;

@end

@implementation FBImageIOScalerTests

- (void)setUp {
  XCUIApplication *app = [[XCUIApplication alloc] init];
  [app launch];
  XCUIScreenshot *screenshot = app.screenshot;
  self.originalImage = UIImageJPEGRepresentation(screenshot.image, 1.0);
  self.originalSize = [FBImageIOScalerTests scaledSizeFromImage:screenshot.image];
}

- (void)testExample {
  NSUInteger halfScale = 50;
  CGSize expectedHalfScaleSize = [FBImageIOScalerTests sizeFromSize:self.originalSize withScalingFactor:50];
  [self scaleImageWithFactor:halfScale
                expectedSize:expectedHalfScaleSize];

  // 1 is the smalles scaling factor we accept
  NSUInteger minScale = 0;
  CGSize expectedMinScaleSize = [FBImageIOScalerTests sizeFromSize:self.originalSize withScalingFactor:1];
  [self scaleImageWithFactor:minScale
                expectedSize:expectedMinScaleSize];

  // For scaling factors above 100 we don't perform any scaling and just return the unmodified image
  NSUInteger unscaled = 200;
  [self scaleImageWithFactor:unscaled
                expectedSize:self.originalSize];
}

- (void)scaleImageWithFactor:(NSUInteger)scalingFactor expectedSize:(CGSize)excpectedSize {
  FBImageIOScaler *scaler = [[FBImageIOScaler alloc] initWithScalingFactor:scalingFactor
                                                        compressionQuality:100];

  id expScaled = [self expectationWithDescription:@"Receive scaled image"];

  [scaler submitImage:self.originalImage
    completionHandler:^(NSData *scaled) {
      UIImage *scaledImage = [UIImage imageWithData:scaled];
      CGSize scaledSize = [FBImageIOScalerTests scaledSizeFromImage:scaledImage];

      XCTAssertEqualWithAccuracy(scaledSize.width, excpectedSize.width, DBL_EPSILON);
      XCTAssertEqualWithAccuracy(scaledSize.height, excpectedSize.height, DBL_EPSILON);

      [expScaled fulfill];
    }];

  [self waitForExpectations:@[expScaled]
                    timeout:0.5];

}

+ (CGSize)scaledSizeFromImage:(UIImage *)image {
  return CGSizeMake(image.size.width * image.scale, image.size.height * image.scale);
}

+ (CGSize)sizeFromSize:(CGSize)size withScalingFactor:(NSUInteger)scalingFactor {
  return CGSizeMake(round(size.width * (scalingFactor / 100.0)), round(size.height * (scalingFactor / 100.0)));
}

@end

