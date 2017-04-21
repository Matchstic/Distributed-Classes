//
//  SCCameraViewController.m
//  SecurityCam
//
//  Created by Matt Clarke on 13/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//
//  Code has been used from: https://developer.apple.com/library/content/samplecode/AVCam/Introduction/Intro.htm
//  This is since I have not had much experience working with the camera on iOS.


#import "SCCameraViewController.h"
#import "SCRemoteImageCapture.h"

@interface SCCameraViewController ()

@end

@interface UIApplication (Private)
-(void)setBacklightLevel:(CGFloat)level;
- (CGFloat)backlightLevel;
@end

@implementation SCCameraViewController

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [super viewWillAppear:animated];
    
    self.fadeTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(fadeTimerDidFire:) userInfo:nil repeats:NO];
    
    dispatch_async( self.sessionQueue, ^{
        switch ( self.setupResult ) {
            case 1: {
                // Only setup observers and start the session running if setup succeeded.
                [self.session startRunning];
                self.sessionRunning = self.session.isRunning;
                break;
            }
            case -1: {
                dispatch_async( dispatch_get_main_queue(), ^{
                    NSString *message = NSLocalizedString( @"Permission isn't granted for camera access; please change privacy settings", @"Alert message when the user has denied access to the camera" );
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                    [alertController addAction:cancelAction];
                    
                    // Provide quick access to Settings.
                    UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Settings", @"Alert button to open Settings" ) style:UIAlertActionStyleDefault handler:^( UIAlertAction *action ) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
                    }];
                    [alertController addAction:settingsAction];
                    [self presentViewController:alertController animated:YES completion:nil];
                } );
                break;
            }
            case -2: {
                dispatch_async( dispatch_get_main_queue(), ^{
                    NSString *message = NSLocalizedString( @"Unable to capture media", @"Alert message when something goes wrong during capture session configuration" );
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                    [alertController addAction:cancelAction];
                    [self presentViewController:alertController animated:YES completion:nil];
                } );
                break;
            }
        }
    } );
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [super viewWillDisappear:animated];
    
    [self.fadeTimer invalidate];
}

- (void)viewDidDisappear:(BOOL)animated {
    dispatch_async( self.sessionQueue, ^{
        if ( self.setupResult == 1) {
            [self.session stopRunning];
        }
    });
    
    [super viewDidDisappear:animated];
}

-(UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

-(void)loadView {
    self.view = [[UIView alloc] initWithFrame:CGRectZero];
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.cameraFeedView = [[SCCameraPreviewView alloc] initWithFrame:CGRectZero];
    self.cameraFeedView.opaque = YES;
    
    [self.view addSubview:self.cameraFeedView];
    
    // Add buttons etc on the top.
}

-(void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    
    if ( UIDeviceOrientationIsPortrait( deviceOrientation ) || UIDeviceOrientationIsLandscape( deviceOrientation ) ) {
        self.cameraFeedView.videoPreviewLayer.connection.videoOrientation = (AVCaptureVideoOrientation)deviceOrientation;
        [SCRemoteImageCapture sharedInstance].videoPreviewLayerVideoOrientation = (AVCaptureVideoOrientation)deviceOrientation;
    }
    
    self.cameraFeedView.frame = self.view.bounds;
    
    // Configure buttons etc.
    
}

-(void)viewDidLoad {
    [super viewDidLoad];
    
    [[self navigationItem] setTitle:@"Camera"];
    
    // Create the AVCaptureSession.
    self.session = [[AVCaptureSession alloc] init];
    
    // Set up the preview view.
    self.cameraFeedView.session = self.session;
    
    // Communicate with the session and other session objects on this queue.
    self.sessionQueue = dispatch_queue_create("sessionqueue", DISPATCH_QUEUE_SERIAL);
    
    self.setupResult = 1;
    
    switch ( [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusAuthorized: {
            // The user has previously granted access to the camera.
            break;
        }
        case AVAuthorizationStatusNotDetermined: {
            dispatch_suspend( self.sessionQueue );
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^( BOOL granted ) {
                if ( ! granted ) {
                    self.setupResult = -1;
                }
                dispatch_resume( self.sessionQueue );
            }];
            break;
        }
        default: {
            // The user has previously denied access.
            self.setupResult = -1;
            break;
        }
    }

    dispatch_async( self.sessionQueue, ^{
        [self configureSession];
    } );
}

-(void)configureSession {
    if (self.setupResult != 1) {
        return;
    }
    
    NSError *error = nil;
    
    [self.session beginConfiguration];
    
    /*
     We do not create an AVCaptureMovieFileOutput when setting up the session because the
     AVCaptureMovieFileOutput does not support movie recording with AVCaptureSessionPresetPhoto.
     */
    self.session.sessionPreset = AVCaptureSessionPresetPhoto;
    
    // Add video input.
    
    // Choose the back dual camera if available, otherwise default to a wide angle camera.
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDualCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    if (!videoDevice ) {
        // If the back dual camera is not available, default to the back wide angle camera.
        videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
        
        // In some cases where users break their phones, the back wide angle camera is not available. In this case, we should default to the front wide angle camera.
        if (!videoDevice ) {
            videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
        }
    }
    
    AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if (!videoDeviceInput ) {
        NSLog( @"Could not create video device input: %@", error );
        self.setupResult = -2;
        [self.session commitConfiguration];
        return;
    }
    
    if ( [self.session canAddInput:videoDeviceInput] ) {
        [self.session addInput:videoDeviceInput];
        self.videoDeviceInput = videoDeviceInput;
        
        dispatch_async( dispatch_get_main_queue(), ^{
            UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
            AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationPortrait;
            if ( statusBarOrientation != UIInterfaceOrientationUnknown ) {
                initialVideoOrientation = (AVCaptureVideoOrientation)statusBarOrientation;
            }
            
            self.cameraFeedView.videoPreviewLayer.connection.videoOrientation = initialVideoOrientation;
            [SCRemoteImageCapture sharedInstance].videoPreviewLayerVideoOrientation = initialVideoOrientation;
        } );
    }
    else {
        NSLog( @"Could not add video device input to the session" );
        self.setupResult = -2;
        [self.session commitConfiguration];
        return;
    }
    
    // Add photo output.
    AVCapturePhotoOutput *photoOutput = [[AVCapturePhotoOutput alloc] init];
    if ([self.session canAddOutput:photoOutput] ) {
        [self.session addOutput:photoOutput];
        self.photoOutput = photoOutput;
        
        self.photoOutput.highResolutionCaptureEnabled = YES;
        self.photoOutput.livePhotoCaptureEnabled = NO;
    }
    else {
        NSLog( @"Could not add photo output to the session" );
        self.setupResult = -2;
        [self.session commitConfiguration];
        return;
    }
    
    [self.session commitConfiguration];
    
    SCRemoteImageCapture *remote = [SCRemoteImageCapture sharedInstance];
    remote.sessionQueue = self.sessionQueue;
    remote.photoOutput = self.photoOutput;
    remote.currentSession = self.session;
}

-(void)fadeTimerDidFire:(id)sender {
    // We should pause video previewing (but keep it all running), drop brightness and overlay with black.
    [self.fadeTimer invalidate];
    
    CGRect rect = [UIScreen mainScreen].bounds;
    
    self.fadeWindow = [[UIWindow alloc] initWithFrame:rect];
    self.fadeWindow.backgroundColor = [UIColor blackColor];
    self.fadeWindow.alpha = 0.0;
    self.fadeWindow.windowLevel = 1080;
    self.fadeWindow.opaque = YES;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapFadeWindow:)];
    [self.fadeWindow addGestureRecognizer:tap];
    
    [self.fadeWindow makeKeyAndVisible];
    
    [UIView animateWithDuration:0.3 animations:^{
        self.fadeWindow.alpha = 1.0;
    } completion:^(BOOL finished) {
        if (finished) {
            self.preFadeBacklightLevel = [[UIApplication sharedApplication] backlightLevel];
            [[UIApplication sharedApplication] setBacklightLevel:0.0];
            
            self.cameraFeedView.hidden = YES;
        }
    }];
}

-(void)didTapFadeWindow:(id)sender {
    // Start live preview again.
    self.cameraFeedView.hidden = NO;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.fadeWindow.alpha = 0.0;
        [[UIApplication sharedApplication] setBacklightLevel:self.preFadeBacklightLevel];
    } completion:^(BOOL finished) {
        self.fadeWindow.hidden = YES;
        
        self.fadeWindow = nil;
    }];
    
    self.fadeTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(fadeTimerDidFire:) userInfo:nil repeats:NO];
}

@end
