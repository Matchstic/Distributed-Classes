//
//  SCConfigViewController.m
//  SecurityCam
//
//  Created by Matt Clarke on 11/03/2017.
//  Copyright © 2017 Matt Clarke. All rights reserved.
//

#import "SCConfigViewController.h"
#import <DistributedClasses.h>

@interface SCConfigViewController ()

@end

@implementation SCConfigViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
     [[self navigationItem] setTitle:@"Config"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)loadView {
    self.view = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    // Service name. (placeholder as com.matchstic.testserver)
    self.serviceHeader = [[UILabel alloc] init];
    self.serviceHeader.text = @"SERVER DETAILS";
    self.serviceHeader.font = [UIFont systemFontOfSize:14];
    self.serviceHeader.textColor = [UIColor grayColor];
    
    [self.view addSubview:self.serviceHeader];
    
    self.serviceBacker = [[UIView alloc] initWithFrame:CGRectZero];
    self.serviceBacker.backgroundColor = [UIColor whiteColor];
    
    [self.view addSubview:self.serviceBacker];
    
    self.serviceNameField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.serviceNameField.placeholder = @"Service name...";
    self.serviceNameField.textColor = [UIColor darkTextColor];
    self.serviceNameField.font = [UIFont systemFontOfSize:18];
    self.serviceNameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.serviceNameField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.serviceNameField.returnKeyType = UIReturnKeyDone;
    self.serviceNameField.delegate = self;
    
    [self.serviceBacker addSubview:self.serviceNameField];
    
    self.portNumberField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.portNumberField.placeholder = @"Port number...";
    self.portNumberField.textColor = [UIColor darkTextColor];
    self.portNumberField.font = [UIFont systemFontOfSize:18];
    self.portNumberField.keyboardType = UIKeyboardTypeNumberPad;
    self.portNumberField.returnKeyType = UIReturnKeyDone;
    self.portNumberField.delegate = self;
    
    UIToolbar* numberToolbar = [[UIToolbar alloc]initWithFrame:CGRectZero];
    numberToolbar.barStyle = UIBarStyleDefault;
    numberToolbar.items = @[[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                            [[UIBarButtonItem alloc]initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(didClickDoneForNumberPad)]];
    [numberToolbar sizeToFit];
    self.portNumberField.inputAccessoryView = numberToolbar;
    
    [self.serviceBacker addSubview:self.portNumberField];
    
    // Access controls if needed.
    
    self.accessHeader = [[UILabel alloc] initWithFrame:CGRectZero];
    self.accessHeader.text = @"ACCESS CONTROLS";
    self.accessHeader.font = [UIFont systemFontOfSize:14];
    self.accessHeader.textColor = [UIColor grayColor];
    
    [self.view addSubview:self.accessHeader];
    
    self.accessBacker = [[UIView alloc] initWithFrame:CGRectZero];
    self.accessBacker.backgroundColor = [UIColor whiteColor];
    
    [self.view addSubview:self.accessBacker];
    
    // Switch, username, password
    
    self.accessControlsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.accessControlsLabel.text = @"Use Access Controls";
    self.accessControlsLabel.font = [UIFont systemFontOfSize:18];
    self.accessControlsLabel.textColor = [UIColor darkTextColor];
    
    [self.accessBacker addSubview:self.accessControlsLabel];
    
    self.accessControlsSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    [self.accessControlsSwitch setOn:NO];
    
    [self.accessBacker addSubview:self.accessControlsSwitch];
    
    self.usernameField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.usernameField.placeholder = @"Username...";
    self.usernameField.textColor = [UIColor darkTextColor];
    self.usernameField.font = [UIFont systemFontOfSize:18];
    self.usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.usernameField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.usernameField.returnKeyType = UIReturnKeyDone;
    self.usernameField.delegate = self;
    
    [self.accessBacker addSubview:self.usernameField];
    
    self.passwordField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.passwordField.placeholder = @"Password...";
    self.passwordField.textColor = [UIColor darkTextColor];
    self.passwordField.font = [UIFont systemFontOfSize:18];
    self.passwordField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.passwordField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.passwordField.returnKeyType = UIReturnKeyDone;
    self.passwordField.delegate = self;
    self.passwordField.secureTextEntry = YES;
    
    [self.accessBacker addSubview:self.passwordField];
    
    // Picker for encryption mode.
    
    self.encryptionHeader = [[UILabel alloc] initWithFrame:CGRectZero];
    self.encryptionHeader.text = @"ENCRYPTION MODE";
    self.encryptionHeader.font = [UIFont systemFontOfSize:14];
    self.encryptionHeader.textColor = [UIColor grayColor];
    
    [self.view addSubview:self.encryptionHeader];
    
    self.encryptionBacker = [[UIView alloc] initWithFrame:CGRectZero];
    self.encryptionBacker.backgroundColor = [UIColor whiteColor];
    
    [self.view addSubview:self.encryptionBacker];
    
    self.encryptionPicker = [[UIPickerView alloc] initWithFrame:CGRectZero];
    self.encryptionPicker.delegate = self;
    self.encryptionPicker.dataSource = self;
    [self.encryptionPicker selectRow:2 inComponent:0 animated:NO];
    
    [self.encryptionBacker addSubview:self.encryptionPicker];
    
    // Button to start server.
    
    self.serverBacker = [[UIView alloc] initWithFrame:CGRectZero];
    self.serverBacker.backgroundColor = [UIColor whiteColor];
    
    [self.view addSubview:self.serverBacker];
    
    self.serverStatusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.serverStatusLabel.text = @"Status: stopped";
    self.serverStatusLabel.font = [UIFont systemFontOfSize:18];
    self.serverStatusLabel.textColor = [UIColor darkTextColor];
    
    [self.serverBacker addSubview:self.serverStatusLabel];
    
    self.startServerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startServerButton setTitle:@"Run Server" forState:UIControlStateNormal];
    [self.startServerButton addTarget:self action:@selector(didClickStartServerButton:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.serverBacker addSubview:self.startServerButton];
    
    self.stopServerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.stopServerButton setTitle:@"Stop Server" forState:UIControlStateNormal];
    [self.stopServerButton addTarget:self action:@selector(didClickStopServerButton:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.serverBacker addSubview:self.stopServerButton];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

-(void)didClickDoneForNumberPad {
    [self.portNumberField resignFirstResponder];
}

-(void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    // layout wotsits and then set scrollview contentSize.
    
    CGFloat y = 22;
    
    // Service details
    self.serviceHeader.frame = CGRectMake(10, y, self.view.frame.size.width - 20, 22);
    
    y += self.serviceHeader.frame.size.height;
    
    
    CGFloat serviceY = 0;
    self.serviceNameField.frame = CGRectMake(10, serviceY, self.view.frame.size.width - 10, 44);
    
    serviceY += self.serviceNameField.frame.size.height;
    
    self.portNumberField.frame = CGRectMake(10, serviceY, self.view.frame.size.width - 10, 44);
    self.portNumberField.inputAccessoryView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.portNumberField.inputAccessoryView.frame.size.height);
    
    serviceY += self.portNumberField.frame.size.height;
    
    self.serviceBacker.frame = CGRectMake(0, y, self.view.frame.size.width, serviceY);
    
    y += serviceY + 22;
    
    // Access controls
    self.accessHeader.frame = CGRectMake(10, y, self.view.frame.size.width - 20, 22);
    
    y += self.accessHeader.frame.size.height;
    
    CGFloat accessY = 0;
    self.accessControlsLabel.frame = CGRectMake(10, accessY, self.view.frame.size.width - self.accessControlsSwitch.frame.size.width - 10, 44);
    self.accessControlsSwitch.frame = CGRectMake(self.view.frame.size.width - self.accessControlsSwitch.frame.size.width - 10, accessY + (44-31)/2, self.accessControlsSwitch.frame.size.width, 31);
    
    accessY += self.accessControlsLabel.frame.size.height;
    
    self.usernameField.frame =  CGRectMake(10, accessY, self.view.frame.size.width - 10, 44);
    
    accessY += self.usernameField.frame.size.height;
    
    self.passwordField.frame =  CGRectMake(10, accessY, self.view.frame.size.width - 10, 44);
    
    accessY += self.passwordField.frame.size.height;
    
    self.accessBacker.frame = CGRectMake(0, y, self.view.frame.size.width, accessY);
    
    y += accessY + 22;
    
    // Encryption selection.
    self.encryptionHeader.frame = CGRectMake(10, y, self.view.frame.size.width - 20, 22);
    
    y += self.encryptionHeader.frame.size.height;
    
    CGFloat encryptionY = 0;
    self.encryptionPicker.frame = CGRectMake(0, encryptionY, self.view.frame.size.width, self.encryptionPicker.frame.size.height);
    
    encryptionY += self.encryptionPicker.frame.size.height;
    
    self.encryptionBacker.frame = CGRectMake(0, y, self.view.frame.size.width, encryptionY);
    
    y += encryptionY + 44;
    
    // Server status et al.
    
    CGFloat serverY = 0;
    self.serverStatusLabel.frame = CGRectMake(10, serverY, self.view.frame.size.width - 10, 44);
    
    serverY += self.serverStatusLabel.frame.size.height;
    
    self.startServerButton.frame = CGRectMake(10, serverY, self.view.frame.size.width - 10, 44);
    
    serverY += self.startServerButton.frame.size.height;
    
    self.stopServerButton.frame = CGRectMake(10, serverY, self.view.frame.size.width - 10, 44);
    
    serverY += self.stopServerButton.frame.size.height;
    
    self.serverBacker.frame = CGRectMake(0, y, self.view.frame.size.width, serverY);
    
    y += serverY + 22;
    
    // contentSize.
    [(UIScrollView*)self.view setContentSize:CGSizeMake(self.view.frame.size.width, y)];
}

-(void)showErrorWithTitle:(NSString*)title andMessage:(NSString*)message {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)didClickStartServerButton:(id)sender {
    // First, service name and stuff.
    unsigned int portNumber = 0;
    @try {
        portNumber = [self.portNumberField.text intValue];
    } @catch (NSException *e) {
        [self showErrorWithTitle:@"Error" andMessage:@"Port number must be a postive integer"];
        return;
    }
    
    if (!self.serviceNameField.text || [self.serviceNameField.text isEqualToString:@""]) {
        [self showErrorWithTitle:@"Error" andMessage:@"A service name must be provided"];
        return;
    }
    
    // Create auth module.
    DCNSBasicAuthentication *auth;
    
    if (self.accessControlsSwitch.isOn) {
        if (!self.usernameField.text || [self.usernameField.text isEqualToString:@""]) {
            [self showErrorWithTitle:@"Error" andMessage:@"A username must be provided if using access controls"];
            return;
        }
        
        if (!self.passwordField.text || [self.passwordField.text isEqualToString:@""]) {
            [self showErrorWithTitle:@"Error" andMessage:@"A password must be provided if using access controls"];
            return;
        }
        
        auth = [DCNSBasicAuthentication createAuthenticationModuleWithUsername:self.usernameField.text andPassword:self.passwordField.text];
    } else {
        auth = [DCNSBasicAuthentication createAuthenticationModuleWithTransportEncryptionOnly:kDCNSBasicEncryptionChaCha];
    }
    
    // Set encryption mode.
    switch ([self.encryptionPicker selectedRowInComponent:0]) {
        case 0:
            // None.
            auth.encryptionMode = kDCNSBasicEncryptionNone;
            break;
        case 1:
            // XOR
            auth.encryptionMode = kDCNSBasicEncryptionXOR;
            break;
        case 2:
            // AES-128
            auth.encryptionMode = kDCNSBasicEncryptionAES128;
            break;
        case 3:
            // ChaCha20
            auth.encryptionMode = kDCNSBasicEncryptionChaCha;
            break;
        default:
            auth.encryptionMode = kDCNSBasicEncryptionNone;
            break;
    }
    
    NSError *error;
    
    // We will use remote, as an iOS device cannot run as a local-only server.
    [DCNSServer initialiseAsRemoteWithService:self.serviceNameField.text portNumber:portNumber authenticationDelegate:auth andError:&error];
    
    if (!error) {
        // Success!
        self.serverStatusLabel.text = @"Status: running";
    } else {
        [self showErrorWithTitle:@"Error" andMessage:[NSString stringWithFormat:@"Couldn't start server:\n%@", error.localizedFailureReason]];
    }
}

-(void)didClickStopServerButton:(id)sender {
    [DCNSServer shutdownServer];
    self.serverStatusLabel.text = @"Status: stopped";
}

#pragma mark UIPickerView stuff

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return 5;
}

-(NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    // Set encryption mode.
    switch (row) {
        case 0:
            // None.
            return @"None";
        case 1:
            // XOR
            return @"XOR'd bytes";
        case 2:
            // AES-128
            return @"AES-128";
        case 3:
            // ChaCha20
            return @"ChaCha20";
        default:
            return @"None";
    }
}

@end
