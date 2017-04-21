//
//  SCRemoteImageCapture.h
//  SecurityCam
//
//  Created by Matt Clarke on 13/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol SCRemoteImageCaptureDelegate <NSObject>
@required
-(void)dataIsReady:(NSData*)data;
@end

@interface SCRemoteImageCapture : NSObject <AVCapturePhotoCaptureDelegate>

@property (nonatomic, weak) AVCaptureSession *currentSession;
@property (nonatomic, weak) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, weak) dispatch_queue_t sessionQueue;
@property (nonatomic) dispatch_semaphore_t sem;
@property (nonatomic, readwrite) AVCaptureVideoOrientation videoPreviewLayerVideoOrientation;
@property (nonatomic, strong) NSData *cachedPhoto;

// Client only need to know about the following two methods...
+(instancetype)sharedInstance;

@end
