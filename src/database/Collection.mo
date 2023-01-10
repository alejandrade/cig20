import CA "mo:candb/CanisterActions";
import CanDB "mo:candb/CanDB";
import Entity "mo:candb/Entity";
import Array "mo:base/Array";
import Blob "mo:base/Deque";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Http "../helpers/http";
import Int "mo:base/Int";
import Int32 "mo:base/Int32";
import Iter "mo:base/Iter";
import JSON "../helpers/JSON";
import Nat32 "mo:base/Nat32";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import List "mo:base/List";
import Utils "../helpers/Utils";
import Cycles "mo:base/ExperimentalCycles";
import Response "../models/Response";
import Constants "../Constants";
import Crud "./Crud";
import Transaction "../models/Transaction";
import TopUpService "../services/TopUpService";

shared ({ caller = owner }) actor class Collection({
    // the primary key of this canister
    partitionKey : Text;
    // the scaling options that determine when to auto-scale out this canister storage partition
    scalingOptions : CanDB.ScalingOptions;
    // (optional) allows the developer to specify additional owners (i.e. for allowing admin or backfill access to specific endpoints)
    owners : ?[Principal];
},
tokenCanister : Text,
swapCanister : Text,
topUpCanister : Text
) {

    private stable var _tokenCanister:Text = tokenCanister;
    private stable var _swapCanister:Text = swapCanister;
    private stable var _topUpCanister:Text = topUpCanister;
    private stable var transactiontId : Int = 1;

    private type JSON = JSON.JSON;
    private type ApiError = Response.ApiError;
    private type Transaction = Transaction.Transaction;

    /// @required (may wrap, but must be present in some form in the canister)
    stable let db = CanDB.init({
        pk = partitionKey;
        scalingOptions = scalingOptions;
    });

    /// @recommended (not required) public API
    public query func getPK() : async Text { db.pk };

    /// @required public API (Do not delete or change)
    public query func skExists(sk : Text) : async Bool {
        CanDB.skExists(db, sk);
    };

    private func _skExists(sk : Text) : Bool {
        CanDB.skExists(db, sk);
    };

    /// @required public API (Do not delete or change)
    public shared ({ caller = caller }) func transferCycles() : async () {
        if (caller == owner) {
            return await CA.transferCycles(caller);
        };
    };

    public query func getMemorySize() : async Nat {
        let size = Prim.rts_memory_size();
        size;
    };

    public query func getHeapSize() : async Nat {
        let size = Prim.rts_heap_size();
        size;
    };

    public query func getCycles() : async Nat {
        Cycles.balance();
    };

    private func _getMemorySize() : Nat {
        let size = Prim.rts_memory_size();
        size;
    };

    private func _getHeapSize() : Nat {
        let size = Prim.rts_heap_size();
        size;
    };

    private func _getCycles() : Nat {
        Cycles.balance();
    };

    public shared ({ caller }) func putTransaction(transaction : Transaction) : async Text {
        ignore _topUp();
        let canister = Principal.toText(caller);
        var nodes:[Text] = [];
        nodes := Array.append(nodes,[_tokenCanister]);
        nodes := Array.append(nodes,[_swapCanister]);
        let exist = Array.find(nodes,func(e:Text):Bool{e == canister});
        assert(exist != null);
        await Crud.putTransaction(db, transaction);

    };

    private func _topUp(): async () {
        if (_getCycles() <= Constants.cyclesThreshold){
            await TopUpService.topUp(_topUpCanister);
        }
    };

    public query func http_request(request : Http.Request) : async Http.Response {
        let path = Iter.toArray(Text.tokens(request.url, #text("/")));

        if (path.size() == 1) {
            let value = path[1];
            switch (path[0]) {
                case ("getMemorySize") return _natResponse(_getMemorySize());
                case ("getHeapSize") return _natResponse(_getHeapSize());
                case ("getCycles") return _natResponse(_getCycles());
                case (_) return return Http.BAD_REQUEST();
            };
        } else if (path.size() == 2) {
            switch (path[0]) {
                case ("skExists") return _skExistsResponse(path[1]);
                case ("getTransaction") return _transactionResponse(path[1]);
                case (_) return return Http.BAD_REQUEST();
            };
        } else if (path.size() == 3) {
            switch (path[0]) {
                case ("fetchTransactions") return _fetchTransactionResponse(path[1], path[2]);
                case ("fetchSenderTransactions") return _fetchSenderTransactionResponse(path[1], path[2]);
                case ("fetchReceiverTransactions") return _fetchReceiverTransactionResponse(path[1], path[2]);
                case (_) return return Http.BAD_REQUEST();
            };
        } else {
            return Http.BAD_REQUEST();
        };
    };

    private func _skExistsResponse(sk : Text) : Http.Response {
        let json = #Boolean(_skExists(sk));
        let blob = Text.encodeUtf8(JSON.show(json));
        let response : Http.Response = {
            status_code = 200;
            headers = [("Content-Type", "application/json")];
            body = blob;
            streaming_strategy = null;
        };
    };

    private func _natResponse(value : Nat) : Http.Response {
        let json = #Number(value);
        let blob = Text.encodeUtf8(JSON.show(json));
        let response : Http.Response = {
            status_code = 200;
            headers = [("Content-Type", "application/json")];
            body = blob;
            streaming_strategy = null;
        };
    };

    private func _fetchTransactionResponse(start : Text, end : Text) : Http.Response {
        let transactionsHashMap : HashMap.HashMap<Text, JSON> = HashMap.HashMap<Text, JSON>(
            0,
            Text.equal,
            Text.hash,
        );
        let result = _fetchTransactions(start, end);
        var transactions : [JSON] = [];

        for (transaction in result.transactions.vals()) {
            let json = Utils._transactionToJson(transaction);
            transactions := Array.append(transactions, [json]);
        };
        transactionsHashMap.put("transactions", #Array(transactions));
        switch (result.sk) {
            case (?exist) {
                transactionsHashMap.put("sk", #String(exist));
            };
            case (null) {

            };
        };

        let json = #Object(transactionsHashMap);
        let blob = Text.encodeUtf8(JSON.show(json));
        let response : Http.Response = {
            status_code = 200;
            headers = [("Content-Type", "application/json")];
            body = blob;
            streaming_strategy = null;
        };
    };

    private func _fetchSenderTransactionResponse(start : Text, end : Text) : Http.Response {
        let transactionsHashMap : HashMap.HashMap<Text, JSON> = HashMap.HashMap<Text, JSON>(
            0,
            Text.equal,
            Text.hash,
        );
        let result = _fetchSenderTransactions(start, end);
        var transactions : [JSON] = [];

        for (transaction in result.transactions.vals()) {
            let json = Utils._transactionToJson(transaction);
            transactions := Array.append(transactions, [json]);
        };
        transactionsHashMap.put("transactions", #Array(transactions));
        switch (result.sk) {
            case (?exist) {
                transactionsHashMap.put("sk", #String(exist));
            };
            case (null) {

            };
        };

        let json = #Object(transactionsHashMap);
        let blob = Text.encodeUtf8(JSON.show(json));
        let response : Http.Response = {
            status_code = 200;
            headers = [("Content-Type", "application/json")];
            body = blob;
            streaming_strategy = null;
        };
    };

    private func _fetchReceiverTransactionResponse(start : Text, end : Text) : Http.Response {
        let transactionsHashMap : HashMap.HashMap<Text, JSON> = HashMap.HashMap<Text, JSON>(
            0,
            Text.equal,
            Text.hash,
        );
        let result = _fetchReceiverTransactions(start, end);
        var transactions : [JSON] = [];

        for (transaction in result.transactions.vals()) {
            let json = Utils._transactionToJson(transaction);
            transactions := Array.append(transactions, [json]);
        };
        transactionsHashMap.put("transactions", #Array(transactions));
        switch (result.sk) {
            case (?exist) {
                transactionsHashMap.put("sk", #String(exist));
            };
            case (null) {

            };
        };

        let json = #Object(transactionsHashMap);
        let blob = Text.encodeUtf8(JSON.show(json));
        let response : Http.Response = {
            status_code = 200;
            headers = [("Content-Type", "application/json")];
            body = blob;
            streaming_strategy = null;
        };
    };

    private func _transactionResponse(value : Text) : Http.Response {
        let exist = _getTransaction(value);
        switch (exist) {
            case (?exist) {
                let json = Utils._transactionToJson(exist);
                let blob = Text.encodeUtf8(JSON.show(json));
                let response : Http.Response = {
                    status_code = 200;
                    headers = [("Content-Type", "application/json")];
                    body = blob;
                    streaming_strategy = null;
                };
            };
            case (null) {
                return Http.NOT_FOUND();
            };
        };
    };

    private func _fetchTransactions(skLowerBound : Text, skUpperBound : Text) : {
        transactions : [Transaction];
        sk : ?Text;
    } {
        var transactions : [Transaction] = [];
        let result = CanDB.scan(
            db,
            {
                skLowerBound = "transaction:" # skLowerBound;
                skUpperBound = "transaction:" # skUpperBound;
                limit = 1000;
                ascending = ?false;
            },
        );

        for (obj in result.entities.vals()) {
            let transaction = Crud.unwrapTransaction(obj);
            switch (transaction) {
                case (?transaction) {
                    transactions := Array.append(transactions, [transaction]);
                };
                case (null) {

                };
            };
        };
        {
            transactions = transactions;
            sk = result.nextKey;
        };
    };

    private func _fetchSenderTransactions(skLowerBound : Text, skUpperBound : Text) : {
        transactions : [Transaction];
        sk : ?Text;
    } {
        var transactions : [Transaction] = [];
        let result = CanDB.scan(
            db,
            {
                skLowerBound = "transactionSender:" # skLowerBound;
                skUpperBound = "transactionSender:" # skUpperBound;
                limit = 1000;
                ascending = ?false;
            },
        );

        for (obj in result.entities.vals()) {
            let transaction = Crud.unwrapTransaction(obj);
            switch (transaction) {
                case (?transaction) {
                    transactions := Array.append(transactions, [transaction]);
                };
                case (null) {

                };
            };
        };
        {
            transactions = transactions;
            sk = result.nextKey;
        };
    };

    private func _fetchReceiverTransactions(skLowerBound : Text, skUpperBound : Text) : {
        transactions : [Transaction];
        sk : ?Text;
    } {
        var transactions : [Transaction] = [];
        let result = CanDB.scan(
            db,
            {
                skLowerBound = "transactionReceiver:" # skLowerBound;
                skUpperBound = "transactionReceiver:" # skUpperBound;
                limit = 1000;
                ascending = ?false;
            },
        );

        for (obj in result.entities.vals()) {
            let transaction = Crud.unwrapTransaction(obj);
            switch (transaction) {
                case (?transaction) {
                    transactions := Array.append(transactions, [transaction]);
                };
                case (null) {

                };
            };
        };
        {
            transactions = transactions;
            sk = result.nextKey;
        };
    };

    private func _getTransaction(value : Text) : ?Transaction {
        switch (CanDB.get(db, { sk = "transactionId:" # value })) {
            case null { null };
            case (?entity) { Crud.unwrapTransaction(entity) };
        };
    };

};
