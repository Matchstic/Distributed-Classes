//
//  SCCameraPreviewView.h
//  SecurityCam
//
//  Created by Matt Clarke on 13/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface SCCameraPreviewView : UIView

@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic) AVCaptureSession *session;

@end
