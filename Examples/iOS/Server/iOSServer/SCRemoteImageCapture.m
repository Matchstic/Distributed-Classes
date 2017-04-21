//
//  SCRemoteImageCapture.m
//  SecurityCam
//
//  Created by Matt Clarke on 13/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import "SCRemoteImageCapture.h"

static SCRemoteImageCapture *shared;
static NSTimer *fauxRealtimeTimer;

@implementation SCRemoteImageCapture

+(instancetype)sharedInstance {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

-(instancetype)init {
    self = [super init];
    
    if (self) {
        fauxRealtimeTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(setCurrentCapture:) userInfo:nil repeats:YES];
    }
    
    return self;
}

-(void)setCurrentCapture:(id)sender {
    if (!self.sessionQueue || !self.photoOutput) {
        return;
    }
    
    dispatch_async(self.sessionQueue, ^{
        // Update the photo output's connection to match the video orientation of the video preview layer.
        AVCaptureConnection *photoOutputConnection = [self.photoOutput connectionWithMediaType:AVMediaTypeVideo];
        photoOutputConnection.videoOrientation = self.videoPreviewLayerVideoOrientation;
        
        // Capture a JPEG photo with flash set to auto and high resolution photo enabled.
        AVCapturePhotoSettings *photoSettings = [AVCapturePhotoSettings photoSettings];
        //photoSettings.flashMode = AVCaptureFlashModeOff;
        photoSettings.highResolutionPhotoEnabled = YES;
        if ( photoSettings.availablePreviewPhotoPixelFormatTypes.count > 0 ) {
            photoSettings.previewPhotoFormat = @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : photoSettings.availablePreviewPhotoPixelFormatTypes.firstObject };
        }
        
        self.sem = dispatch_semaphore_create(0);
        
        [self.photoOutput capturePhotoWithSettings:photoSettings delegate:self];
    });
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput
didFinishProcessingPhotoSampleBuffer:(CMSampleBufferRef)photoSampleBuffer
previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer
     resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
      bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings
                error:(NSError *)error {
    // ^ now that is a long method name...
    
    if ( error != nil ) {
        NSLog( @"Error capturing photo: %@", error );
        dispatch_semaphore_signal(self.sem);
        return;
    }
    
    self.cachedPhoto = [AVCapturePhotoOutput JPEGPhotoDataRepresentationForJPEGSampleBuffer:photoSampleBuffer previewPhotoSampleBuffer:previewPhotoSampleBuffer];
}

@end
