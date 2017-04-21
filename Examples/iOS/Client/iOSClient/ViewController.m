//
//  ViewController.m
//  DOClientTest
//
//  Created by Matt Clarke on 29/11/2016.
//  Copyright (c) 2016 Matt Clarke. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>
#include <sys/time.h>

#import <DistributedClasses.h>

@interface SomeOtherClass : NSObject

-(void)test;
-(NSString*)passByValue;
@property (nonatomic, readwrite) int testInt;
@property (nonatomic, strong) NSString *testString;
+(SomeOtherClass*)sharedInstance;

@end

#define SCREEN_MAX_LENGTH (MAX([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height))
#define SCREEN_MIN_LENGTH (MIN([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height))

@interface ViewController ()

@end

static ViewController *shared;
static SomeOtherClass *someOther;

@implementation ViewController

+(instancetype)sharedInstance {
    return shared;
}

-(instancetype)init {
    self = [super init];
    
    if (self) {
        shared = self;
    }
    
    return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        shared = self;
    }
    
    return self;
}

-(instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        shared = self;
    }
    
    return self;
}

-(void)loadView {
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_MIN_LENGTH, SCREEN_MAX_LENGTH)];
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.textView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.textView.textAlignment = NSTextAlignmentLeft;
    self.textView.textColor = [UIColor blackColor];
    self.textView.editable = NO;
    
    [self.view addSubview:self.textView];
    
    self.textLine = [[UIView alloc] initWithFrame:CGRectZero];
    self.textLine.backgroundColor = [UIColor grayColor];
    
    [self.view addSubview:self.textLine];
    
    self.button = [[UIButton alloc] initWithFrame:CGRectZero];
    [self.button setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.button setTitle:@"Connect" forState:UIControlStateNormal];
    [self.button addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.button sizeToFit];
    
    [self.view addSubview:self.button];
    
    self.setInt7 = [[UIButton alloc] initWithFrame:CGRectZero];
    [self.setInt7 setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.setInt7 setTitle:@"testInt to 7" forState:UIControlStateNormal];
    [self.setInt7 addTarget:self action:@selector(setInt7Clicked:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.setInt7 sizeToFit];
    
    [self.view addSubview:self.setInt7];
    
    self.setInt10 = [[UIButton alloc] initWithFrame:CGRectZero];
    [self.setInt10 setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.setInt10 setTitle:@"testInt to 10" forState:UIControlStateNormal];
    [self.setInt10 addTarget:self action:@selector(setInt10Clicked:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.setInt10 sizeToFit];
    
    [self.view addSubview:self.setInt10];
    
    self.setStringHello = [[UIButton alloc] initWithFrame:CGRectZero];
    [self.setStringHello setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.setStringHello setTitle:@"testString to 'Hello'" forState:UIControlStateNormal];
    [self.setStringHello addTarget:self action:@selector(setStringHelloClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.setStringHello sizeToFit];
    
    [self.view addSubview:self.setStringHello];
    
    self.setStringWorld = [[UIButton alloc] initWithFrame:CGRectZero];
    [self.setStringWorld setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.setStringWorld setTitle:@"testString to 'World'" forState:UIControlStateNormal];
    [self.setStringWorld addTarget:self action:@selector(setStringWorldClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.setStringWorld sizeToFit];
    
    [self.view addSubview:self.setStringWorld];
    
    self.refreshState = [[UIButton alloc] initWithFrame:CGRectZero];
    [self.refreshState setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.refreshState setTitle:@"Refresh State" forState:UIControlStateNormal];
    [self.refreshState addTarget:self action:@selector(refreshStateClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.refreshState sizeToFit];
    
    [self.view addSubview:self.refreshState];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

-(void)viewDidAppear:(BOOL)animated {
    [self updateTextViewWithString:@"Please tap Connect above.\n\n"];
}

-(void)viewDidLayoutSubviews {
    // Buttons.
    int y = 30;
    self.button.frame = CGRectMake(self.view.frame.size.width/4 - self.button.frame.size.width/2, y, self.button.frame.size.width, 25);
    self.refreshState.frame = CGRectMake((self.view.frame.size.width/4 * 3) - self.refreshState.frame.size.width/2, y, self.refreshState.frame.size.width, 25);
    
    y += 35;
    
    self.setInt7.frame = CGRectMake(self.view.frame.size.width/4 - self.setInt7.frame.size.width/2, y, self.setInt7.frame.size.width, 25);
    self.setInt10.frame = CGRectMake((self.view.frame.size.width/4 * 3) - self.setInt10.frame.size.width/2, y, self.setInt10.frame.size.width, 25);
    
    y += 35;
    
    self.setStringHello.frame = CGRectMake(self.view.frame.size.width/4 - self.setStringHello.frame.size.width/2, y, self.setStringHello.frame.size.width, 25);
    self.setStringWorld.frame = CGRectMake((self.view.frame.size.width/4 * 3) - self.setStringWorld.frame.size.width/2, y, self.setStringWorld.frame.size.width, 25);
    
    y += 60;
    
    self.textView.frame = CGRectMake(0, y, self.view.frame.size.width, self.view.frame.size.height - y);
    
    self.textLine.frame = CGRectMake(0, y-1, self.view.frame.size.width, 1);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)buttonClicked:(UIButton*)sender {
    // Fire off distributed classes.
    [self updateTextViewWithString:@"Attempting to connect to server 'com.matchstic.testserver' (timeout 10 seconds)...\n"];
    
    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            
            DCNSBasicAuthentication *auth = [DCNSBasicAuthentication
                                             createAuthenticationModuleWithTransportEncryptionOnly:kDCNSBasicEncryptionChaCha];
            
            NSError *error;
            [DCNSClient initialiseToRemoteWithService:@"com.matchstic.testserver" authenticationDelegate:auth andError:&error];
            
            if (!error) {
                // We have success!
                struct timeval t0, t1;
                
                gettimeofday(&t0, NULL);
                SomeOtherClass *someOther2 = [[$c(SomeOtherClass) alloc] init];
                gettimeofday(&t1, NULL);
                
                NSLog(@"******** In %.10g seconds for proxy\n", t1.tv_sec - t0.tv_sec + 1E-6 * (t1.tv_usec - t0.tv_usec));
                
                gettimeofday(&t0, NULL);
                NSObject *newObj = [[NSObject alloc] init];
                gettimeofday(&t1, NULL);
                
                NSLog(@"******** In %.10g seconds for real\n", t1.tv_sec - t0.tv_sec + 1E-6 * (t1.tv_usec - t0.tv_usec));
                
                someOther = [$c(SomeOtherClass) sharedInstance];
                
                NSString *str = [NSString stringWithFormat:@"Have SomeOtherClass shared instance:\n%@\n\n", someOther];
                
                [self updateTextViewWithString:str];
                
                [self _refresh];
            } else {
                [self updateTextViewWithString:[NSString stringWithFormat:@"ERROR: %@\n", error]];
            }
        } @catch (NSException *e) {
            [self updateTextViewWithString:[NSString stringWithFormat:@"Communications error: %@, %@", e.name, e.reason]];
        }
    //});
}

-(void)setInt7Clicked:(UIButton*)sender {
    @try {
        someOther.testInt = 7;
        [self _refresh];
    } @catch (NSException *e) {
        [self updateTextViewWithString:[NSString stringWithFormat:@"Communications error: %@, %@", e.name, e.reason]];
    }
}

-(void)setInt10Clicked:(UIButton*)sender {
    @try {
        someOther.testInt = 10;
        [self _refresh];
    } @catch (NSException *e) {
        [self updateTextViewWithString:[NSString stringWithFormat:@"Communications error: %@, %@", e.name, e.reason]];
    }
}

-(void)setStringHelloClicked:(UIButton*)sender {
    @try {
        someOther.testString = @"Hello";
        [self _refresh];
    } @catch (NSException *e) {
        [self updateTextViewWithString:[NSString stringWithFormat:@"Communications error: %@, %@", e.name, e.reason]];
    }
}

-(void)setStringWorldClicked:(UIButton*)sender {
    @try {
        someOther.testString = @"World";
        [self _refresh];
    } @catch (NSException *e) {
        [self updateTextViewWithString:[NSString stringWithFormat:@"Communications error: %@, %@", e.name, e.reason]];
    }
}

-(void)refreshStateClicked:(UIButton*)sender {
    [self _refresh];
}

-(void)_refresh {
    @try {
        NSString *str = [NSString stringWithFormat:@"Refreshing...\nTestString: %@\nTestInt: %d\n", someOther.testString, someOther.testInt];
    
        [self updateTextViewWithString:str];
    } @catch (NSException *e) {
        [self updateTextViewWithString:[NSString stringWithFormat:@"Communications error: %@, %@", e.name, e.reason]];
    }
}

-(void)updateTextViewWithString:(NSString*)string {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *existingContent = self.textView.text;
        
        existingContent = [existingContent stringByAppendingFormat:@"\n%@", string];
        
        self.textView.text = existingContent;
    });
}

@end
