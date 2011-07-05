/* libmoonshot - Moonshot client library
 * Copyright (c) 2011, JANET(UK)
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of JANET(UK) nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * Author: Sam Thursfield <samthursfield@codethink.co.uk>
 */

#include <dbus/dbus-glib.h>
#include <dbus/dbus.h>

#include "libmoonshot.h"
#include "libmoonshot-common.h"

#define MOONSHOT_DBUS_NAME "org.janet.Moonshot"
#define MOONSHOT_DBUS_PATH "/org/janet/moonshot"

/* This library is overly complicated currently due to the requirement
 * that it work on Debian Squeeze - this has GLib 2.24 which requires us
 * to use dbus-glib instead of GDBus. If/when this requirement is
 * dropped the DBus version of the library can be greatly simplified.
 */

/* Note that ideally this library would not depend on GLib. This would be
 * possible using libdbus directly and running our own message loop while
 * waiting for calls.
 */

static DBusGProxy *moonshot_dbus_proxy = NULL;

static DBusGProxy *dbus_connect (MoonshotError **error)
{
    DBusConnection  *connection;
    DBusError        dbus_error;
    DBusGConnection *g_connection;
    DBusGProxy      *g_proxy;
    GError          *g_error;
    dbus_bool_t      name_has_owner;

    g_return_val_if_fail (*error == NULL, NULL);

    dbus_error_init (&dbus_error);

    /* Check for moonshot server and start the service if possible. We use
     * libdbus here because dbus-glib doesn't handle autostarting the service.
     * If/when we move to GDBus this code can become a one-liner.
     */

    connection = dbus_bus_get (DBUS_BUS_SESSION, &dbus_error);

    if (dbus_error_is_set (&dbus_error)) {
        *error = moonshot_error_new (MOONSHOT_ERROR_IPC_ERROR,
                                     "DBus error: %s",
                                     dbus_error.message);
        dbus_error_free (&dbus_error);
        return NULL;
    }

    name_has_owner  = dbus_bus_name_has_owner (connection,
                                               MOONSHOT_DBUS_NAME,
                                               &dbus_error);

    if (dbus_error_is_set (&dbus_error)) {
        *error = moonshot_error_new (MOONSHOT_ERROR_IPC_ERROR,
                                     "DBus error: %s",
                                     dbus_error.message);
        dbus_error_free (&dbus_error);
        return NULL;
    }

    if (! name_has_owner) {
        dbus_bus_start_service_by_name (connection,
                                        MOONSHOT_DBUS_NAME,
                                        0,
                                        NULL,
                                        &dbus_error);

        if (dbus_error_is_set (&dbus_error)) {
            if (strcmp (dbus_error.name + 27, "ServiceUnknown") == 0) {
                /* Missing .service file; the moonshot-ui install is broken */
                *error = moonshot_error_new (MOONSHOT_ERROR_UNABLE_TO_START_SERVICE,
                                             "The Moonshot service was not found. "
                                             "Please make sure that moonshot-ui is "
                                             "correctly installed.");
            } else {
                *error = moonshot_error_new (MOONSHOT_ERROR_IPC_ERROR,
                                             "DBus error: %s",
                                             dbus_error.message);
            }
            dbus_error_free (&dbus_error);
            return NULL;
        }
    }

    /* Now the service should be running */
    g_error = NULL;

    g_connection = dbus_g_bus_get (DBUS_BUS_SESSION, &g_error);

    if (g_error != NULL) {
        *error = moonshot_error_new (MOONSHOT_ERROR_IPC_ERROR,
                                     "DBus error: %s",
                                     g_error->message);
        g_error_free (g_error);
        return NULL;
    }

    g_proxy = dbus_g_proxy_new_for_name_owner (g_connection,
                                               MOONSHOT_DBUS_NAME,
                                               MOONSHOT_DBUS_PATH,
                                               MOONSHOT_DBUS_NAME,
                                               &g_error);

    if (g_error != NULL) {
        *error = moonshot_error_new (MOONSHOT_ERROR_IPC_ERROR,
                                     "DBus error: %s",
                                     g_error->message);
        g_error_free (g_error);
        return NULL;
    }

    return g_proxy; 
}

int moonshot_get_identity (const char     *nai,
                           const char     *password,
                           const char     *service,
                           char          **nai_out,
                           char          **password_out,
                           char          **server_certificate_hash_out,
                           char          **ca_certificate_out,
                           char          **subject_name_constraint_out,
                           char          **subject_alt_name_constraint_out,
                           MoonshotError **error)
{
    GError   *g_error = NULL;
    int success;

    if (moonshot_dbus_proxy == NULL)
        moonshot_dbus_proxy = dbus_connect (error);

    if (*error != NULL)
        return;

    g_return_if_fail (DBUS_IS_G_PROXY (moonshot_dbus_proxy));

    dbus_g_proxy_call (moonshot_dbus_proxy,
                       "GetIdentity",
                       &g_error,
                       G_TYPE_STRING, nai,
                       G_TYPE_STRING, password,
                       G_TYPE_STRING, service,
                       G_TYPE_INVALID,
                       G_TYPE_STRING, nai_out,
                       G_TYPE_STRING, password_out,
                       G_TYPE_STRING, server_certificate_hash_out,
                       G_TYPE_STRING, ca_certificate_out,
                       G_TYPE_STRING, subject_name_constraint_out,
                       G_TYPE_STRING, subject_alt_name_constraint_out,
                       G_TYPE_BOOLEAN, &success,
                       G_TYPE_INVALID);

    if (g_error != NULL) {
        *error = moonshot_error_new (MOONSHOT_ERROR_IPC_ERROR,
                                     g_error->message);
        return FALSE;
    }

    if (success == FALSE) {
        *error = moonshot_error_new (MOONSHOT_ERROR_NO_IDENTITY_SELECTED,
                                     "No identity was returned by the Moonshot "
                                     "user interface.");
        return FALSE;
    }

    return TRUE;
}



    /**
     * Returns the default identity - most recently used.
     *
     * @param nai_out NAI stored in the ID card
     * @param password_out Password stored in the ID card
     *
     * @return true on success, false if no identities are stored
     */
