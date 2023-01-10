import Principal "mo:base/Principal";
import Utils "../helpers/Utils";
import Nat64 "mo:base/Nat64";
import Constants "../Constants";
import Result "mo:base/Result";

module {
    public func topUp(canisterId:Text) : async () {
        let canister = actor(canisterId) : actor { 
            topUp : shared () -> async ();
        };

        await canister.topUp();
    };
}