//
//  FirstViewController.m
//  SecurityCam
//
//  Created by Matt Clarke on 11/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import "FirstViewController.h"
#import "SCConfigViewController.h"

@interface FirstViewController ()

@end

@implementation FirstViewController

-(instancetype)init {
    self = [super init];
    
    if (self) {
        [self.navigationItem setTitle:@"Config"];
        [self setTitle:@"Config"];
        [self.navigationBar setBarStyle:UIBarStyleDefault];
    }
    
    return self;
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self setTitle:@"Config"];
    [self.navigationItem setTitle:@"Config"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    SCConfigViewController *table = [[SCConfigViewController alloc] init];
    [self setViewControllers:@[table] animated:NO];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
