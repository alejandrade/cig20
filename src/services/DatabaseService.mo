import Transaction "../models/Transaction";
import Constants "../Constants";
import Types "../models/types";

module {

    private type Transaction = Transaction.Transaction;

    public func putTransaction(canisterId:Text,transaction:Transaction) : async Text {
        let canister = actor(canisterId) : actor { 
            putTransaction: (Transaction)  -> async Text;
        };

        await canister.putTransaction(transaction);
    };

    public func getCanistersByPK(canisterId:Text,pk:Text) : async [Text] {
        let canister = actor(canisterId) : actor { 
            getCanistersByPK: (Text) -> async [Text]; 
        };

        await canister.getCanistersByPK(pk);
    };
}
