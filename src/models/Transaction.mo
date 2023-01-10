import Types "../models/types";
import Time "mo:base/Time";

module {

    type TxReceipt = Types.TxReceipt;

    public type Transaction = {
        sender:Text;
        receiver:Text;
        amount:Int;
        fee:Int;
        timeStamp:Time.Time;
        hash:Text;
        transactionType:Text;
    };
}