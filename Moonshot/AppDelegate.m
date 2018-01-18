//
//  AppDelegate.m
//  Moonshot
//
//  Created by Elena Jakjoska on 10/13/16.
//

#import "AppDelegate.h"
#import "AboutWindow.h"
#import "MSTConstants.h"
#import "MainViewController.h"
#import "MSTIdentitySelectorViewController.h"
#import "MSTDBusServer.h"
#import "Identity.h"
#import "MSTIdentityDataLayer.h"

@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *window;
@property (nonatomic, strong) IBOutlet NSViewController *viewController;
@property (nonatomic, strong) NSOperationQueue *dbusQueue;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [self setIdentityManagerViewController];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification {

}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

#pragma mark - Set Content ViewController

- (void)setIdentitySelectorViewController:(MSTGetIdentityAction *)getIdentityAction {
    NSStoryboard *storyBoard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    _viewController = [storyBoard instantiateControllerWithIdentifier:@"MSTIdentitySelectorViewController"];
    ((MSTIdentitySelectorViewController *)_viewController).getIdentityAction = getIdentityAction;
    [[[NSApplication sharedApplication] windows][0] setContentViewController:_viewController];
    [[[NSApplication sharedApplication] windows][0]  setTitle:NSLocalizedString(@"Identity_Selector_Window_Title", @"")];
}

- (void)setIdentityManagerViewController {
    NSStoryboard *storyBoard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    _viewController = [storyBoard instantiateControllerWithIdentifier:@"MainViewController"];
    [[[NSApplication sharedApplication] windows][0] setContentViewController:_viewController];
    [[[NSApplication sharedApplication] windows][0]  setTitle:NSLocalizedString(@"Identity_Manager_Window_Title", @"")];
}

#pragma mark - Button Actions

- (IBAction)about:(id)sender {
    [[AboutWindow defaultController] showWindow:self];
}

- (IBAction)addNewIdentity:(id)sender {
   // [[NSNotificationCenter defaultCenter] postNotificationName:MST_ADD_IDENTITY_NOTIFICATION object:nil];
	[self startListeningForDBusConnections];
}

- (IBAction)editIdentity:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:MST_EDIT_IDENTITY_NOTIFICATION object:nil];
}

- (IBAction)removeIdentity:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:MST_REMOVE_IDENTITY_NOTIFICATION object:nil];
}

#pragma mark - Get Identity Action
- (void)initiateIdentitySelectionFor:(NSString *)nai service:(NSString *)service password:(NSString *)password connection:(DBusConnection *)connection reply:(DBusMessage *)reply {
	
	Identity *existingIdentitySelection = [self getExistingIdentitySelectionFor:nai service:service password:password];
	if (existingIdentitySelection) {
		NSString *combinedNaiOut = @"";
		if (existingIdentitySelection.username.length && existingIdentitySelection.realm.length) {
			combinedNaiOut = [NSString stringWithFormat:@"%@@%@",existingIdentitySelection.username,existingIdentitySelection.realm];
		}
		const char *nai_out = [combinedNaiOut UTF8String];
		const char *password_out = existingIdentitySelection.password == nil ? "" : [existingIdentitySelection.password UTF8String];
		const char *server_certificate_hash_out = [@"" UTF8String];
		const char *ca_certificate_out = [@"" UTF8String];
		const char *subject_name_constraint_out = [@"" UTF8String];
		const char *subject_alt_name_constraint_out = [@"" UTF8String];
		const int  success = [existingIdentitySelection.identityId isEqualToString:MST_NO_IDENTITY] ? 0 : 1;
		
		dbus_message_append_args(reply,
								 DBUS_TYPE_STRING, &nai_out,
								 DBUS_TYPE_STRING, &password_out,
								 DBUS_TYPE_STRING, &server_certificate_hash_out,
								 DBUS_TYPE_STRING, &ca_certificate_out,
								 DBUS_TYPE_STRING, &subject_name_constraint_out,
								 DBUS_TYPE_STRING, &subject_alt_name_constraint_out,
								 DBUS_TYPE_BOOLEAN, &success,
								 DBUS_TYPE_INVALID);
		
		dbus_connection_send(connection, reply, NULL);
		dbus_message_unref(reply);
	} else {
		MSTGetIdentityAction *getIdentity = [[MSTGetIdentityAction alloc] initFetchIdentityFor:nai service:service password:password connection:connection reply:reply];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self setIdentitySelectorViewController:getIdentity];
		});
	}
}

- (Identity *)getExistingIdentitySelectionFor:(NSString *)nai service:(NSString *)service password:(NSString *)password {
	return [[MSTIdentityDataLayer sharedInstance] getExistingIdentitySelectionFor:nai service:service password:password];
}

- (void)startListeningForDBusConnections {
	if (!self.dbusQueue) {
		self.dbusQueue = [[NSOperationQueue alloc] init];
		self.dbusQueue.maxConcurrentOperationCount = 1;
	}

	if (self.dbusQueue.operationCount == 0) {
		[self.dbusQueue addOperationWithBlock:^{
			dbusStartListening();
		}];
	}
}

@end
