
using Gee;
public errordomain IdentityManagerError {
    KEYRING_LOCKED
}

public interface IdentityManagerInterface : Object {
    public abstract bool add_identity(IdCard id_card, bool force_flat_file_store);
    public abstract void queue_identity_request(IdentityRequest request);
    public abstract void make_visible();
    public abstract IdCard check_add_password(IdCard identity, IdentityRequest request, IdentityManagerModel model);
    public abstract bool confirm_trust_anchor(IdCard card, TrustAnchorConfirmationRequest request);
}
