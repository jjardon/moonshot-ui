/*
 * Copyright (c) 2011-2016, JANET(UK)
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
 */
using Gee;

extern long get_encryption_key(char* buffer, int buflen);
extern int encrypt(char *plaintext, long plaintext_len, char *key, char *ciphertext);
extern int decrypt(char *ciphertext, long ciphertext_len, char *key, char *plaintext);

errordomain FlatFileError {
    ENCRYPTION
}


public class LocalFlatFileStore : Object, IIdentityCardStore {
    static MoonshotLogger logger = get_logger("LocalFlatFileStore");

    private Gee.List<IdCard> id_card_list;
    private const string FILE_NAME = "identities.txt";
    private bool encrypted = false;

    public void add_card(IdCard card) {
        id_card_list.add(card);
        store_id_cards();
    }

    public IdCard? update_card(IdCard card) {
        id_card_list.remove(card);
        id_card_list.add(card);
        store_id_cards();
        foreach(IdCard idcard in id_card_list) {
            if (idcard.display_name == card.display_name) {
                return idcard;
            }
        }
        logger.error(@"update_card: card '$(card.display_name)' was not found after re-loading!");
        return null;
    }

    public bool remove_card(IdCard card) {
        if (id_card_list.remove(card)) {
            store_id_cards();
            return true;
        }
        return false;
    }

    public Gee.List<IdCard> get_card_list() {
        return id_card_list;
    }

    public IIdentityCardStore.StoreType get_store_type() {
        return IIdentityCardStore.StoreType.FLAT_FILE;
    }

    public string get_store_name() {
        return encrypted ? "ENCRYPTED_FLAT_FILE" : "FLAT_FILE";
    }

    private void load_id_cards() {
        id_card_list.clear();
        var key_file = new KeyFile();
        var path = get_data_dir();
        var filename = Path.build_filename(path, FILE_NAME);
        logger.trace("load_id_cards: attempting to load from " + filename);
        uint8[] contents;

        try{
            FileStream? stream = FileStream.open(filename, "rb");
            if (stream == null)
                throw new FlatFileError.ENCRYPTION("File does not exist");
            stream.seek(0, FileSeek.END);
            long size = stream.tell ();
            stream.rewind ();
            contents = new uint8[size];
            stream.read(contents, size);
        }
        catch (GLib.Error e) {
            logger.error("load_id_cards: Error while loading keyfile %s: %s\n".printf(filename, e.message));
            return;
        }

        try{
            if (encrypted) {
                uint8 key[128];
                long keylen = get_encryption_key(key, 128);
                if (keylen < 0)
                    throw new FlatFileError.ENCRYPTION("Could not get the decryption key");
                uint8[] plaintext = new uint8[contents.length];
                int plainlen = decrypt(contents, contents.length, key, plaintext);
                if (plainlen < 0)
                    throw new FlatFileError.ENCRYPTION("Could not decrypt file.");
                plaintext.resize(plainlen);
                contents = plaintext;
            }
        }
        catch (FlatFileError.ENCRYPTION e) {
            logger.error("load_id_cards: Error while decrypting keyfile %s: %s\n".printf(filename, e.message));
            stderr.printf("load_id_cards: Error while decrypting keyfile %s: %s\n".printf(filename, e.message));
            Posix.exit(1);
        }

        try {
            key_file.load_from_data((string) contents, contents.length, KeyFileFlags.NONE);
        }
        catch (GLib.Error e) {
            logger.error("load_id_cards: Error while loading keyfile %s: %s\n".printf(filename, e.message));
            return;
        }

        var identities_uris = key_file.get_groups();
        foreach (string identity in identities_uris) {
            try {
                IdCard id_card = new IdCard();

                id_card.issuer = key_file.get_string(identity, "Issuer");
                id_card.username = key_file.get_string(identity, "Username");
                id_card.password = key_file.get_string(identity, "Password");
                id_card.update_services(key_file.get_string_list(identity, "Services"));
                id_card.display_name = key_file.get_string(identity, "DisplayName");
                if (key_file.has_key(identity, "StorePassword")) {
                    id_card.store_password = (key_file.get_string(identity, "StorePassword") == "yes");
                } else {
                    id_card.store_password = (id_card.password != null) && (id_card.password != "");
                }
                if (key_file.has_key(identity, "Has2FA")) {
                    id_card.has_2fa = (key_file.get_string(identity, "Has2FA") == "yes");
                }

                if (key_file.has_key(identity, "Rules-Patterns") &&
                    key_file.has_key(identity, "Rules-AlwaysConfirm")) {
                    string [] rules_patterns =    key_file.get_string_list(identity, "Rules-Patterns");
                    string [] rules_always_conf = key_file.get_string_list(identity, "Rules-AlwaysConfirm");

                    if (rules_patterns.length == rules_always_conf.length) {
                        Rule[] rules = new Rule[rules_patterns.length];
                        for (int i = 0; i < rules_patterns.length; i++) {
                            rules[i] = {rules_patterns[i], rules_always_conf[i]};
                        }
                        id_card.rules = rules;
                    }
                }

                // Trust anchor
                string ca_cert = key_file.get_string(identity, "CA-Cert").strip();
                string server_cert = key_file.get_string(identity, "ServerCert");
                string subject = key_file.get_string(identity, "Subject");
                string subject_alt = key_file.get_string(identity, "SubjectAlt");
                var ta = new TrustAnchor(ca_cert, server_cert, subject, subject_alt);
                string ta_datetime_added = get_string_setting(identity, "TA_DateTime_Added", "", key_file);
                if (ta_datetime_added != "") {
                    ta.set_datetime_added(ta_datetime_added);
                }
                id_card.set_trust_anchor_from_store(ta);
                id_card_list.add(id_card);
            }
            catch (Error e) {
                logger.error("load_id_cards: Error while loading keyfile %s: %s\n".printf(filename, e.message));
                //stdout.printf("Error while attempting to load from %s: %s\n", filename, e.message);
            }
        }
    }

    private string get_data_dir() {
        string path;
        path = Path.build_filename(Environment.get_user_data_dir(),
                                   Config.PACKAGE_TARNAME);

        if (!FileUtils.test(path, FileTest.EXISTS)) {
            DirUtils.create_with_parents(path, 0700);
        }
        return path;
    }

    internal void store_id_cards() {
        var key_file = new KeyFile();
        foreach (IdCard id_card in this.id_card_list) {
            logger.trace(@"store_id_cards: Storing '$(id_card.display_name)'");

            /* workaround for Centos vala array property bug: use temp arrays */
            var rules = id_card.rules;
            string[] rules_patterns = new string[rules.length];
            string[] rules_always_conf = new string[rules.length];

            for (int i = 0; i < rules.length; i++) {
                rules_patterns[i] = rules[i].pattern;
                rules_always_conf[i] = rules[i].always_confirm;
            }

            key_file.set_string(id_card.display_name, "Issuer", id_card.issuer ?? "");
            key_file.set_string(id_card.display_name, "DisplayName", id_card.display_name ?? "");
            key_file.set_string(id_card.display_name, "Username", id_card.username ?? "");
            if (id_card.store_password && (id_card.password != null))
                key_file.set_string(id_card.display_name, "Password", id_card.password);
            else
                key_file.set_string(id_card.display_name, "Password", "");

            // Using id_card.services.to_array() seems to cause a crash, possibly due to
            // an unowned reference to the array.
            string[] svcs = new string[id_card.services.size];
            for (int i = 0; i < id_card.services.size; i++) {
                svcs[i] = id_card.services[i];
            }

            key_file.set_string_list(id_card.display_name, "Services", svcs);

            if (rules.length > 0) {
                key_file.set_string_list(id_card.display_name, "Rules-Patterns", rules_patterns);
                key_file.set_string_list(id_card.display_name, "Rules-AlwaysConfirm", rules_always_conf);
            }
            key_file.set_string(id_card.display_name, "StorePassword", id_card.store_password ? "yes" : "no");
            key_file.set_string(id_card.display_name, "Has2FA", id_card.has_2fa ? "yes" : "no");

            // Trust anchor
            key_file.set_string(id_card.display_name, "CA-Cert", id_card.trust_anchor.ca_cert);
            key_file.set_string(id_card.display_name, "Subject", id_card.trust_anchor.subject);
            key_file.set_string(id_card.display_name, "SubjectAlt", id_card.trust_anchor.subject_alt);
            key_file.set_string(id_card.display_name, "ServerCert", id_card.trust_anchor.server_cert);
            if (id_card.trust_anchor.datetime_added != "") {
                key_file.set_string(id_card.display_name, "TA_DateTime_Added", id_card.trust_anchor.datetime_added);
            }
            logger.trace(@"store_id_cards: Stored '$(id_card.display_name)'");
        }

        var text = key_file.to_data(null);
        var path = get_data_dir();
        var filename = Path.build_filename(path, FILE_NAME);
        uint8[] data;
        logger.trace("store_id_cards: attempting to store to " + filename);

        if (encrypted) {
            try {
                uint8 key[128];
                long keylen = get_encryption_key(key, 128);
                if (keylen < 0)
                    throw new FlatFileError.ENCRYPTION("Could not get the encryption key");
                uint8[] ciphertext = new uint8[text.length * 2];
                int cipherlen = encrypt(text.data, text.length, key, ciphertext);
                if (cipherlen < 0)
                    throw new FlatFileError.ENCRYPTION("Could not encrypt file.");
                ciphertext.resize(cipherlen);
                data = ciphertext;
            }
            catch (Error e) {
                logger.error("store_id_cards: Error while encrypting keyfile: %s\n".printf(e.message));
                stdout.printf("Error encrypting keyfile:  %s\n", e.message);
                return;
            }
        }
        else {
            data = text.data;
        }

        try {
            FileStream stream = FileStream.open(filename, "wb");
            stream.write(data, 1);
        }
        catch (GLib.Error e)  {
            logger.error("store_id_cards: Error while saving keyfile: %s\n".printf(e.message));
            stdout.printf("Error:  %s\n", e.message);
        }

        load_id_cards();
    }

    public LocalFlatFileStore() {
        id_card_list = new LinkedList<IdCard>();

        /* Check whether there is a key available. We get 1 byte so we avoid copying the whole key */
        uint8 key[1];
        long keylen = get_encryption_key(key, 1);
        if (keylen > 0)
            encrypted = true;
        load_id_cards();
    }
}

