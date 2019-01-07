//
//  FBCIImageScaler.m
//  WebDriverAgentLib
//
//  Created by David on 05.01.19.
//  Copyright © 2019 Facebook. All rights reserved.
//

#import "FBCIImageScaler.h"
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>
#import "FBLogger.h"

@interface FBCIImageScaler ()

@property (nonatomic, readonly) CGFloat scalingFactor;
@property (nonatomic, readonly) CGFloat compressionQuality;

@property (nonatomic) NSData *nextImage;
@property (nonatomic, readonly) NSLock *nextImageLock;
@property (nonatomic, readonly) dispatch_queue_t scalingQueue;

@property (nonatomic, readonly) CIFilter *scalingFilter;
@property (nonatomic, readonly) CIContext *context;

@end

@implementation FBCIImageScaler

- (id)initWithScalingFactor:(NSUInteger)scalingFactor compressionQuality:(NSUInteger)compressionQuality {
  self = [super init];
  if (self) {
    _scalingFactor = scalingFactor / 100.0f;
    _compressionQuality = compressionQuality / 100.0f;

    _nextImageLock = [[NSLock alloc] init];
    _scalingQueue = dispatch_queue_create("image.scaling.queue", NULL);

    _scalingFilter = [self initializeScalingFilter];
    _context = [self initializeContext];  
  }
  return self;
}

-(CIFilter*) initializeScalingFilter {
  CIFilter *scalingFilter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
  [scalingFilter setValue:@(self.scalingFactor)
                   forKey:kCIInputScaleKey];
  [scalingFilter setValue:@(1.0)
                   forKey:kCIInputAspectRatioKey];
  return scalingFilter;
}

-(CIContext*)initializeContext {
  NSMutableDictionary *optionsDict = [[NSMutableDictionary alloc] init] ;
  [optionsDict setValue:@(NO)
                 forKey:kCIContextUseSoftwareRenderer];
  return [[CIContext alloc] initWithOptions:optionsDict];
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
    NSData *scaled = [self scaleDown:next];
    completionHandler(scaled);
  });
}

- (NSData *)scaleDown:(NSData *)rawScreenshotData {
  CIImage *image = [[CIImage alloc] initWithData:rawScreenshotData];
  [self.scalingFilter setValue:image forKey:kCIInputImageKey];
  CIImage *outputImage = [self.scalingFilter valueForKey:kCIOutputImageKey];
  return [self getJpegRepresentationFromImage:outputImage];
}

-(NSData*) getJpegRepresentationFromImage:(CIImage*) outputImage{
  CGRect rectangle = [outputImage extent];
  CGImageRef scaledImage = [self.context createCGImage:outputImage fromRect:rectangle];

  UIImage *uiImageRepresentation = [[UIImage alloc] initWithCGImage:scaledImage];
  NSData *jpegBytes = UIImageJPEGRepresentation(uiImageRepresentation, self.compressionQuality);
  if (scaledImage != nil){
    CFRelease(scaledImage);
  }
  return jpegBytes;
}

@end
