//
//  SecondViewController.m
//  SecurityCam
//
//  Created by Matt Clarke on 11/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import "SecondViewController.h"
#import "SCCameraViewController.h"

@interface SecondViewController ()

@end

@implementation SecondViewController

-(instancetype)init {
    self = [super init];
    
    if (self) {
        [self.navigationItem setTitle:@"Camera"];
        [self setTitle:@"Camera"];
        [self.navigationBar setBarStyle:UIBarStyleDefault];
    }
    
    return self;
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self setTitle:@"Camera"];
    [self.navigationItem setTitle:@"Camera"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    SCCameraViewController *table = [[SCCameraViewController alloc] init];
    [self setViewControllers:@[table] animated:NO];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
