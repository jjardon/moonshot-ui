#include "libmoonshot.h"

#include <stdio.h>

int main (int argc, char *argv[])
{
    MoonshotError *error = NULL;
    int            success;

    char *nai,
         *password,
         *server_certificate_hash,
         *ca_certificate,
         *subject_name_constraint,
         *subject_alt_name_constraint;

    success = moonshot_get_default_identity (&nai,
                                             &password,
                                             &server_certificate_hash,
                                             &ca_certificate,
                                             &subject_name_constraint,
                                             &subject_alt_name_constraint,
                                             &error);

    if (success) {
        printf ("Got identity: %s %s\n", nai, password);

        moonshot_free (nai);
        moonshot_free (password);
        moonshot_free (server_certificate_hash);
        moonshot_free (ca_certificate);
        moonshot_free (subject_name_constraint);
        moonshot_free (subject_alt_name_constraint);

        return 0;
    }

    printf ("FAIL: %s\n", error->message);
    return 1;
}
