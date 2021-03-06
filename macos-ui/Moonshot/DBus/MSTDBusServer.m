//
//  MSTDBusServer.c
//  Moonshot
//
//  Created by Ivan on 11/21/17.
//

#include "MSTDBusServer.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <dbus/dbus.h>
#include <stdbool.h>
#import "AppDelegate.h"
#import "MSTIdentityDataLayer.h"

void dbusStartListening()
{
    DBusError error;
    dbus_error_init(&error);
    
    DBusConnection *connection = dbus_bus_get(DBUS_BUS_SESSION, &error);
    if (!connection || dbus_error_is_set(&error)) {
        perror("Moonshot.IdentitySelector Connection error.");
		return;
    }
    
    const int ret = dbus_bus_request_name(connection, "org.janet.Moonshot", DBUS_NAME_FLAG_REPLACE_EXISTING, &error);
    if (ret != DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER || dbus_error_is_set(&error)) {
        perror(" Moonshot.IdentitySelector Dbus Error.");
		return;
    }

	while (1 == 1) {
        dbus_connection_read_write(connection, 0);
        DBusMessage *const msg = dbus_connection_pop_message(connection);
        if (!msg) {
            continue;
        }
        if (dbus_message_is_method_call(msg, "org.janet.Moonshot", "GetIdentity")) {
			NSLog(@"GetIdentity");

            const char *nai;
            const char *password;
            const char *service;
            
            DBusError err;
            dbus_error_init(&err);
            DBusMessage *reply = NULL;
            if (!dbus_message_get_args(msg, &err,
                                       DBUS_TYPE_STRING, &nai,
                                       DBUS_TYPE_STRING, &password,
                                       DBUS_TYPE_STRING, &service,
                                       DBUS_TYPE_INVALID)) {
                
                perror("Moonshot.IdentitySelector Bad Input Params");
            } else {
                if (!(reply = dbus_message_new_method_return(msg))) {
                    perror("Moonshot.IdentitySelector Bad Output Type");
                } else {
                    NSString *strNai = [NSString stringWithUTF8String:nai];
                    NSString *strService = [NSString stringWithUTF8String:service];
                    NSString *strPassword = [NSString stringWithUTF8String:password];
                    AppDelegate *delegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
                    [delegate initiateIdentitySelectionFor:strNai service:strService password:strPassword connection:connection reply:reply];
                }
            }
        } else if (dbus_message_is_method_call(msg, "org.janet.Moonshot", "GetDefaultIdentity")) {
			NSLog(@"Moonshot.IdentitySelector GetDefaultIdentity");
			const char *nai;
			const char *password;
			const char *service;

			DBusError err;
			dbus_error_init(&err);
			DBusMessage *reply = NULL;
			if (!dbus_message_get_args(msg, &err,
									   DBUS_TYPE_STRING, &nai,
									   DBUS_TYPE_STRING, &password,
									   DBUS_TYPE_STRING, &service,
									   DBUS_TYPE_INVALID)) {

				perror("Moonshot.DefaultIdentitySelector  Bad Input Params");
			} else {
				if (!(reply = dbus_message_new_method_return(msg))) {
					perror("Moonshot.DefaultIdentitySelector Bad Output Type");
				} else {
					const char *empty = [@"" UTF8String];
					const int  success = 0;
					dbus_message_append_args(reply,
											 DBUS_TYPE_STRING, &empty,
											 DBUS_TYPE_STRING, &empty,
											 DBUS_TYPE_STRING, &empty,
											 DBUS_TYPE_STRING, &empty,
											 DBUS_TYPE_STRING, &empty,
											 DBUS_TYPE_STRING, &empty,
											 DBUS_TYPE_BOOLEAN, &success,
											 DBUS_TYPE_INVALID);

					dbus_connection_send(connection, reply, NULL);
					dbus_message_unref(reply);
				}
			}
        } else if (dbus_message_is_method_call(msg, "org.janet.Moonshot", "InstallIdCard")) {
			NSLog(@"Moonshot.IdentitySelector InstallIdCard");
        } else if (dbus_message_is_method_call(msg, "org.janet.Moonshot", "InstallIdCard2fa")) {
			NSLog(@"Moonshot.IdentitySelector InstallIdCard2fa");
        } else if (dbus_message_is_method_call(msg, "org.janet.Moonshot", "ConfirmCaCertificate")) {
			NSLog(@"Moonshot.IdentitySelector ConfirmCaCertificate");
			
			const char *identity_name;
			const char *realm;
			const char *hash_str;
			
			DBusError err;
			dbus_error_init(&err);
			DBusMessage *reply = NULL;
			if (!dbus_message_get_args(msg, &err,
									   DBUS_TYPE_STRING, &identity_name,
									   DBUS_TYPE_STRING, &realm,
									   DBUS_TYPE_STRING, &hash_str,
									   DBUS_TYPE_INVALID)) {
				
				perror("Moonshot.IdentitySelector Bad Input Params");
			} else {
				if (!(reply = dbus_message_new_method_return(msg))) {
					perror("Moonshot.IdentitySelector Bad Output Type");
				} else {
				}
                    AppDelegate *delegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
                    [delegate confirmCaCertForIdentityWithName:[NSString stringWithUTF8String:identity_name] realm:[NSString stringWithUTF8String:realm] certData:[NSString stringWithUTF8String:hash_str] connection:connection reply:reply];
			}
		} else {
			NSLog(@"Moonshot.IdentitySelector None");
		}
        dbus_message_unref(msg);
    }
}

