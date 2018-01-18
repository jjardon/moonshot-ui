//
//  ConnectIdentityWindow.m
//  Moonshot
//
//  Created by Elena Jakjoska on 11/25/16.
//

#import "ConnectIdentityWindow.h"
#import "Identity+Utilities.h"
#import "NSWindow+Utilities.h"

@interface ConnectIdentityWindow ()
@property (weak) IBOutlet NSTextField *connectIdentityTitleTextField;
@property (weak) IBOutlet NSTextField *connectIdentityUserTitleTextField;
@property (weak) IBOutlet NSTextField *connectIdentityUserValueTextField;
@property (weak) IBOutlet NSTextField *connectIdentityPasswordTitleTextField;
@property (weak) IBOutlet NSSecureTextField *connectIdentityPasswordValueTextField;
@property (weak) IBOutlet NSButton *connectIdentityRememberPasswordButton;
@property (weak) IBOutlet NSButton *connectIdentityCancelButton;
@property (weak) IBOutlet NSButton *connectIdentityConnectButton;
@end

@implementation ConnectIdentityWindow

#pragma mark - Window Lifecycle

- (void)windowDidLoad {
    [super windowDidLoad];
    [self setupWindow];
}

#pragma mark - Setup Window

- (void)setupWindow {
    [self setupTextFields];
    [self setupButtons];
}

- (void)setupTextFields {
    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Enter_Password", @""),self.identityObject.displayName];
    [self.connectIdentityTitleTextField setStringValue:title];
    [self.connectIdentityUserTitleTextField setStringValue:NSLocalizedString(@"User_Nai", @"")];
    [self.connectIdentityUserValueTextField setStringValue:[NSString stringWithFormat:@"%@@%@",self.identityObject.username,self.identityObject.realm]];
    [self.connectIdentityPasswordTitleTextField setStringValue:NSLocalizedString(@"Password_Add",@"")];
}

#pragma mark - Setup Buttons

- (void)setupButtons {
    [self.connectIdentityConnectButton setTitle:NSLocalizedString(@"Connect_Identity_Button", @"")];
    [self.connectIdentityConnectButton setEnabled:[self isRequiredDataFilled]];
    [self.connectIdentityCancelButton setTitle:NSLocalizedString(@"Cancel_Button", @"")];
    [self.connectIdentityRememberPasswordButton setTitle:NSLocalizedString(@"Remember_Password", @"")];
	self.identityObject.passwordRemembered ? [self.connectIdentityRememberPasswordButton setState:NSControlStateValueOn] : [self.connectIdentityRememberPasswordButton setState:NSControlStateValueOff];
}

#pragma mark - Button Actions

- (IBAction)connectIdentityCancelButtonPressed:(id)sender {
    if ([self.delegate respondsToSelector:@selector(connectIdentityWindowCanceled:)]) {
        [self.delegate connectIdentityWindowCanceled:self.window];
    }
}

- (IBAction)connectIdentityConnectButtonPressed:(id)sender {
	if ([self.identityObject.password isEqualToString:self.connectIdentityPasswordValueTextField.stringValue]) {
		if ([self.delegate respondsToSelector:@selector(connectIdentityWindow:wantsToConnectIdentity:rememberPassword:)]) {
			self.identityObject.passwordRemembered = self.connectIdentityRememberPasswordButton.state;
			[self.delegate connectIdentityWindow:self.window wantsToConnectIdentity:self.identityObject rememberPassword:self.connectIdentityRememberPasswordButton.state];
		}
	} else {
		[self.window addAlertWithButtonTitle:NSLocalizedString(@"OK_Button", @"") secondButtonTitle:@"" messageText:NSLocalizedString(@"Alert_Incorrect_User_Pass_Messsage", @"") informativeText:NSLocalizedString(@"Alert_Incorrect_User_Pass_Info", @"") alertStyle:NSWarningAlertStyle completionHandler:^(NSModalResponse returnCode) {
			switch (returnCode) {
				case NSAlertFirstButtonReturn:
					break;
				default:
					break;
			}
		}];
	}

}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)notification {
    [self.connectIdentityConnectButton setEnabled:[self isRequiredDataFilled]];
}

- (BOOL)isRequiredDataFilled {
    BOOL connectIdentityButtonDisabled = [self.connectIdentityPasswordValueTextField.stringValue isEqualToString:@""] || [self.identityObject.password isEqualToString:@""];
    return !connectIdentityButtonDisabled;
}

@end
