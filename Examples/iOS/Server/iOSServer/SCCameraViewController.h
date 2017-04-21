//
//  SCCameraViewController.h
//  SecurityCam
//
//  Created by Matt Clarke on 13/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "SCCameraPreviewView.h"

@interface SCCameraViewController : UIViewController

@property (nonatomic, strong) SCCameraPreviewView *cameraFeedView;

@property (nonatomic) int setupResult;
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic, getter=isSessionRunning) BOOL sessionRunning;

@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCapturePhotoOutput *photoOutput;

@property (nonatomic, strong) NSTimer *fadeTimer;
@property (nonatomic, strong) UIWindow *fadeWindow;
@property (nonatomic, readwrite) CGFloat preFadeBacklightLevel;

@end
