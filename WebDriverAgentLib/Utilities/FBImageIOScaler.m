/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBImageIOScaler.h"
#import <ImageIO/ImageIO.h>
#import <CoreServices/CoreServices.h>
#import "FBLogger.h"

@interface FBImageIOScaler ()

@property (nonatomic, readonly) CGFloat scalingFactor;

@property (nonatomic) NSData *nextImage;
@property (nonatomic, readonly) NSLock *nextImageLock;
@property (nonatomic, readonly) dispatch_queue_t scalingQueue;

@property (nonatomic, readonly) CFDictionaryRef compressionOptions;

@end

@implementation FBImageIOScaler

- (id)initWithScalingFactor:(NSUInteger)scalingFactor compressionQuality:(NSUInteger)compressionQuality {
  self = [super init];
  if (self) {
    _scalingFactor = scalingFactor / 100.0f;

    _nextImageLock = [[NSLock alloc] init];
    _scalingQueue = dispatch_queue_create("image.scaling.queue", NULL);

    _compressionOptions = (__bridge CFDictionaryRef)@{
                                                      (id)kCGImageDestinationLossyCompressionQuality: @(compressionQuality / 100.f)
                                                      };
  }
  return self;
}
- (void)submitImage:(NSData *)image completionHandler:(void(^)(NSData *scaled))completionHandler {
  if (fabs(1.0 - self.scalingFactor) < DBL_EPSILON) {
    completionHandler(image);
    return;
  }
  [self.nextImageLock lock];
  if (self.nextImage != nil) {
    [FBLogger verboseLog:@"Discarding screenshot"];
  }
  self.nextImage = image;
  [self.nextImageLock unlock];

  dispatch_async(self.scalingQueue, ^{
    [self.nextImageLock lock];
    NSData *next = self.nextImage;
    self.nextImage = nil;
    [self.nextImageLock unlock];
    if (next == nil) {
      return;
    }
    NSData *scaled = [self scaleImage:next];
    if (scaled == nil) {
      [FBLogger log:@"Could not scale down image"];
      return;
    }
    completionHandler(scaled);
  });
}

- (NSData *)scaleImage:(NSData *)image {
  CGImageSourceRef imageData = CGImageSourceCreateWithData((CFDataRef)image, nil);

  CGSize size = [self getImageSize:imageData];
  CGFloat scaledMaxPixelSize = MAX(size.width, size.height) * self.scalingFactor;

  CFDictionaryRef params = (__bridge CFDictionaryRef)@{
                                                       (id)kCGImageSourceCreateThumbnailWithTransform: @(YES),
                                                       (id)kCGImageSourceCreateThumbnailFromImageIfAbsent: @(YES),
                                                       (id)kCGImageSourceThumbnailMaxPixelSize: @(scaledMaxPixelSize)
                                                       };

  CGImageRef scaled = CGImageSourceCreateThumbnailAtIndex(imageData, 0, params);
  if (scaled == nil) {
    [FBLogger log:@"Failed to scale image"];
    CFRelease(imageData);
    return nil;
  }
  NSData *jpegData = [self convertToJpeg:scaled];
  CFRelease(scaled);
  CFRelease(imageData);
  return jpegData;
}

- (NSData *)convertToJpeg:(CGImageRef)imageRef {
  NSMutableData *newImageData = [NSMutableData data];
  CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((CFMutableDataRef)newImageData, kUTTypeJPEG, 1, NULL);

  CGImageDestinationAddImage(imageDestination, imageRef, self.compressionOptions);
  if(!CGImageDestinationFinalize(imageDestination)) {
    [FBLogger log:@"Failed to write image"];
    newImageData = nil;
  }
  CFRelease(imageDestination);
  return newImageData;
}

- (CGSize)getImageSize:(CGImageSourceRef)imageSource {
  NSDictionary *options = @{
                            (NSString *)kCGImageSourceShouldCache: @(NO)
                            };
  CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (CFDictionaryRef)options);

  NSNumber *width = [(__bridge NSDictionary *)properties objectForKey:(id)kCGImagePropertyPixelWidth];
  NSNumber *height = [(__bridge NSDictionary *)properties objectForKey:(id)kCGImagePropertyPixelHeight];

  CGSize size = CGSizeMake([width floatValue], [height floatValue]);
  CFRelease(properties);
  return size;
}

@end
