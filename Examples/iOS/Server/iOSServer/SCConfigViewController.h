//
//  SCConfigViewController.h
//  SecurityCam
//
//  Created by Matt Clarke on 04/04/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCConfigViewController : UIViewController <UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource>

@property (nonatomic, strong) UILabel *serviceHeader;
@property (nonatomic, strong) UIView *serviceBacker;
@property (nonatomic, strong) UITextField *serviceNameField;
@property (nonatomic, strong) UITextField *portNumberField;

@property (nonatomic, strong) UILabel *accessHeader;
@property (nonatomic, strong) UIView *accessBacker;
@property (nonatomic, strong) UILabel *accessControlsLabel;
@property (nonatomic, strong) UISwitch *accessControlsSwitch;
@property (nonatomic, strong) UITextField *usernameField;
@property (nonatomic, strong) UITextField *passwordField;

@property (nonatomic, strong) UILabel *encryptionHeader;
@property (nonatomic, strong) UIView *encryptionBacker;
@property (nonatomic, strong) UIPickerView *encryptionPicker;

@property (nonatomic, strong) UIView *serverBacker;
@property (nonatomic, strong) UILabel *serverStatusLabel;
@property (nonatomic, strong) UIButton *startServerButton;
@property (nonatomic, strong) UIButton *stopServerButton;

@end
