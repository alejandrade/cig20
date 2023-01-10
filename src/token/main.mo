/**
 * Module     : token.mo
 * Copyright  : 2021 DFinance Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : DFinance Team <hello@dfinance.ai>
 * Stability  : Experimental
 */

import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Types "../models/types";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Float "mo:base/Float";
import Array "mo:base/Array";
import List "mo:base/List";
import Option "mo:base/Option";
import Blob "mo:base/Blob";
import Order "mo:base/Order";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Constants "../Constants";
import DatabaseService "../services/DatabaseService";
import Utils "../helpers/Utils";
import SHA256 "mo:crypto/SHA/SHA256";
import JSON "../helpers/JSON";
import Transaction "../models/Transaction";
import Http "../helpers/http";
import Response "../models/Response";
import TopUpService "../services/TopUpService";
import Cycles "mo:base/ExperimentalCycles";
import Prim "mo:prim";


shared(msg) actor class Token(
    _logo: Text,
    _name: Text,
    _symbol: Text,
    _decimals: Nat8,
    _totalSupply: Nat,
    _owner: Principal,
    _fee: Nat,
    _database:Text,
    _topUpCanister:Text
    ) = this {

    private type Transaction = Transaction.Transaction;
    type Operation = Types.Operation;
    type TransactionStatus = Types.TransactionStatus;
    type TxRecord = Types.TxRecord;
    type Metadata = {
        logo : Text;
        name : Text;
        symbol : Text;
        decimals : Nat8;
        totalSupply : Nat;
        owner : Principal;
        fee : Nat;
    };
    // returns tx index or error msg
    public type TxReceipt = Types.TxReceipt;
    private type JSON = JSON.JSON;
    private stable var transactionPercentage:Float = 0.11;
    private stable var owner_ : Principal = _owner;
    private stable var database_ : Text = _database;
    private stable var topUpCanister_ : Text = _topUpCanister;
    private stable var logo_ : Text = _logo;
    private stable var name_ : Text = _name;
    private stable var decimals_ : Nat8 = _decimals;
    private stable var symbol_ : Text = _symbol;
    private stable var totalSupply_ : Nat = _totalSupply;
    private stable var blackhole : Principal = Principal.fromText("aaaaa-aa");
    private stable var feeTo : Principal = owner_;
    private stable var fee : Nat = _fee;
    private stable var balanceEntries : [(Principal, Nat)] = [];
    private stable var allowanceEntries : [(Principal, [(Principal, Nat)])] = [];
    private var balances = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
    private var allowances = HashMap.HashMap<Principal, HashMap.HashMap<Principal, Nat>>(1, Principal.equal, Principal.hash);

    private let supply = Utils.natToFloat(totalSupply_);
    private stable var isBurnt = false;

    private var log = "";

    let burnAmount:Nat = 50000000000000000000;
    let distributionWalletAmount = Float.mul(supply,0.2);
    let liquidityWalletAmount = Float.mul(supply,0.2);
    let marketingWalletAmount = Float.mul(supply,0.01);
    let teamWalletAmount = Float.mul(supply,0.09);

    private stable let genesis : TxRecord = {
        caller = ?owner_;
        op = #mint;
        index = 0;
        from = blackhole;
        to = owner_;
        amount = totalSupply_;
        fee = 0;
        timestamp = Time.now();
        status = #succeeded;
    };
    
    private stable var txcounter: Nat = 0;
    private stable var burnt: Nat = 0;

    public query func getMemorySize(): async Nat {
        let size = Prim.rts_memory_size();
        size;
    };

    public query func getHeapSize(): async Nat {
        let size = Prim.rts_heap_size();
        size;
    };

    public query func getCycles(): async Nat {
        Prim.cyclesBalance();
    };

    private func _getMemorySize(): Nat {
        let size = Prim.rts_memory_size();
        size;
    };

    private func _getHeapSize(): Nat {
        let size = Prim.rts_heap_size();
        size;
    };

    private func _getCycles(): Nat {
        Prim.cyclesBalance();
    };

    private func _topUp(): async () {
        if (_getCycles() <= Constants.cyclesThreshold){
            await TopUpService.topUp(topUpCanister_);
        }
    };

    private func _chargeFee(from: Principal, fee: Nat) {
        if(fee > 0) {
            _transfer(from, feeTo, fee);
        };
    };

    private func _transfer(from: Principal, to: Principal, value: Nat) {
        let from_balance = _balanceOf(from);
        let from_balance_new : Nat = from_balance - value;
        if (from_balance_new != 0) { balances.put(from, from_balance_new); }
        else { balances.delete(from); };

        let to_balance = _balanceOf(to);
        let to_balance_new : Nat = to_balance + value;
        if (to_balance_new != 0) { balances.put(to, to_balance_new); };
    };

    private func _transactonFactory(amount:Int, sender:Text, receiver:Text, tax:Int, transactionType:Text) : Transaction {
        let now = Time.now();

        let _transaction = {
            sender = sender;
            receiver = receiver;
            amount = amount;
            fee = tax;
            timeStamp = now;
            hash = "";
            transactionType = transactionType;
        };

        let hash = Utils._transactionToHash(_transaction);

        {
            sender = sender;
            receiver = receiver;
            amount = amount;
            fee = tax;
            timeStamp = now;
            hash = hash;
            transactionType = transactionType;
        };
    };

    private func _putTransacton(amount:Int, sender:Text, receiver:Text, tax:Int, transactionType:Text) : async Text {
        let now = Time.now();

        let _transaction = {
            sender = sender;
            receiver = receiver;
            amount = amount;
            fee = tax;
            timeStamp = now;
            hash = "";
            transactionType = transactionType;
        };

        let hash = Utils._transactionToHash(_transaction);

        let transaction = {
            sender = sender;
            receiver = receiver;
            amount = amount;
            fee = tax;
            timeStamp = now;
            hash = hash;
            transactionType = transactionType;
        };

        let _canisters = await DatabaseService.getCanistersByPK(database_,"group#ledger");
        let canisters = List.fromArray<Text>(_canisters);
        let exist = List.last(canisters);

        switch(exist){
            case(?exist){
                return await DatabaseService.putTransaction(exist,transaction);
            };
            case(null){
                return "";
            };
        };
    };

    private func _balanceOf(who: Principal) : Nat {
        switch (balances.get(who)) {
            case (?balance) { return balance; };
            case (_) { return 0; };
        }
    };

    private func _allowance(owner: Principal, spender: Principal) : Nat {
        switch(allowances.get(owner)) {
            case (?allowance_owner) {
                switch(allowance_owner.get(spender)) {
                    case (?allowance) { return allowance; };
                    case (_) { return 0; };
                }
            };
            case (_) { return 0; };
        }
    };

    private func u64(i: Nat): Nat64 {
        Nat64.fromNat(i)
    };

    /*
    *   Core interfaces:
    *       update calls:
    *           transfer/transferFrom/approve
    *       query calls:
    *           logo/name/symbol/decimal/totalSupply/balanceOf/allowance/getMetadata
    *           historySize/getTransaction/getTransactions
    */

    private func _transactionToHash(transaction:Transaction): Text {
        let json = Utils._transactionToJson(transaction);
        JSON.show(json);
    };

    /// Transfers value amount of tokens to Principal to.
    public shared(msg) func transfer(to: Principal, value: Nat) : async TxReceipt {
        ignore _topUp();
        let _tax:Float = Float.mul(Utils.natToFloat(value), transactionPercentage);
        let tax = Utils.floatToNat(_tax);
        if (_balanceOf(msg.caller) < value + fee) { return #Err(#InsufficientBalance); };
        txcounter := txcounter + 1;
        var _txcounter = txcounter;
        _transfer(msg.caller, to, value - tax);
        ignore _insertTransfer(msg.caller,to, value,tax);
        return #Ok(_txcounter);  
    };

    private func _insertTransfer(from:Principal,to:Principal, value:Nat,tax:Nat): async () {
        try{
            _chargeFee(from, fee);
            let hash = await _putTransacton(value, Principal.toText(from), Principal.toText(to), tax, "transfer");
        }catch(e){
            log := Error.message(e)
        };
    };

    /// Transfers value amount of tokens from Principal from to Principal to.
    public shared(msg) func transferFrom(from: Principal, to: Principal, value: Nat) : async TxReceipt {
        ignore _topUp();
        let _tax:Float = Float.mul(Utils.natToFloat(value), transactionPercentage);
        let tax = Utils.floatToNat(_tax);
        if (_balanceOf(from) < value + fee) { return #Err(#InsufficientBalance); };
        let allowed : Nat = _allowance(from, msg.caller);
        if (allowed < value + fee) { return #Err(#InsufficientAllowance); };
        txcounter := txcounter + 1;
        var _txcounter = txcounter;
        _chargeFee(from, fee);
        _transfer(from, to, value - tax);
        let allowed_new : Nat = allowed - value - fee;
        if (allowed_new != 0) {
            let allowance_from = Types.unwrap(allowances.get(from));
            allowance_from.put(msg.caller, allowed_new);
            allowances.put(from, allowance_from);
        } else {
            if (allowed != 0) {
                let allowance_from = Types.unwrap(allowances.get(from));
                allowance_from.delete(msg.caller);
                if (allowance_from.size() == 0) { allowances.delete(from); }
                else { allowances.put(from, allowance_from); };
            };
        };
        ignore _insertTransferFrom(from, to, value ,tax);
        return #Ok(_txcounter);
    };

    private func _insertTransferFrom(from:Principal, to:Principal, value:Nat,tax:Nat): async() {
         try{
            let hash = await _putTransacton(value, Principal.toText(from), Principal.toText(to), tax, "transferFrom");
        }catch(e){
            log := Error.message(e);
        };
    };

    /// Allows spender to withdraw from your account multiple times, up to the value amount.
    /// If this function is called again it overwrites the current allowance with value.
    public shared(msg) func approve(spender: Principal, value: Nat) : async TxReceipt {
        await _topUp();
        if(_balanceOf(msg.caller) < fee) { return #Err(#InsufficientBalance); };
        txcounter := txcounter + 1;
        var _txcounter = txcounter;
        _chargeFee(msg.caller, fee);
        let v = value + fee;
        if (value == 0 and Option.isSome(allowances.get(msg.caller))) {
            let allowance_caller = Types.unwrap(allowances.get(msg.caller));
            allowance_caller.delete(spender);
            if (allowance_caller.size() == 0) { allowances.delete(msg.caller); }
            else { allowances.put(msg.caller, allowance_caller); };
        } else if (value != 0 and Option.isNull(allowances.get(msg.caller))) {
            var temp = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
            temp.put(spender, v);
            allowances.put(msg.caller, temp);
        } else if (value != 0 and Option.isSome(allowances.get(msg.caller))) {
            let allowance_caller = Types.unwrap(allowances.get(msg.caller));
            allowance_caller.put(spender, v);
            allowances.put(msg.caller, allowance_caller);
        };
        return #Ok(_txcounter);
    };

    public shared(msg) func mint(to: Principal, value: Nat): async TxReceipt {
        if(msg.caller != owner_) {
            return #Err(#Unauthorized);
        };
        txcounter := txcounter + 1;
        var _txcounter = txcounter;
        let to_balance = _balanceOf(to);
        totalSupply_ += value;
        balances.put(to, to_balance + value);
        return #Ok(txcounter);
    };

    public shared(msg) func burn(amount: Nat): async TxReceipt {
        await _topUp();
        let from_balance = _balanceOf(msg.caller);
        if(from_balance < amount) {
            return #Err(#InsufficientBalance);
        };
        txcounter := txcounter + 1;
        var _txcounter = txcounter;
        totalSupply_ -= amount;
        balances.put(msg.caller, from_balance - amount);
        burnt := burnt + amount;
        let hash = await _putTransacton(amount, Principal.toText(msg.caller), "", 0, "burn");
        return #Ok(txcounter);
    };

    public query func logo() : async Text {
        return logo_;
    };

    public query func name() : async Text {
        return name_;
    };

    public query func symbol() : async Text {
        return symbol_;
    };

    public query func decimals() : async Nat8 {
        return decimals_;
    };

    public query func totalSupply() : async Nat {
        return Utils.floatToNat(supply);
    };

    public query func getTokenFee() : async Nat {
        return fee;
    };

    public query func balanceOf(who: Principal) : async Nat {
        return _balanceOf(who);
    };

    public query func allowance(owner: Principal, spender: Principal) : async Nat {
        return _allowance(owner, spender);
    };

    public query func getMetadata() : async Metadata {
        return {
            logo = logo_;
            name = name_;
            symbol = symbol_;
            decimals = decimals_;
            totalSupply = totalSupply_;
            owner = owner_;
            fee = fee;
        };
    };

    /// Get transaction history size
    public query func historySize() : async Nat {
        return txcounter;
    };

    /*
    *   Optional interfaces:
    *       setName/setLogo/setFee/setFeeTo/setOwner
    *       getUserTransactionsAmount/getUserTransactions
    *       getTokenInfo/getHolders/getUserApprovals
    */
    public shared(msg) func setName(name: Text) {
        assert(msg.caller == owner_);
        name_ := name;
    };

    public shared(msg) func setLogo(logo: Text) {
        assert(msg.caller == owner_);
        logo_ := logo;
    };

    public shared(msg) func setFeeTo(to: Principal) {
        assert(msg.caller == owner_);
        feeTo := to;
    };

    public shared(msg) func setFee(_fee: Nat) {
        assert(msg.caller == owner_);
        fee := _fee;
    };

    public shared(msg) func setOwner(_owner: Principal) {
        assert(msg.caller == owner_);
        owner_ := _owner;
    };

    public type TokenInfo = {
        metadata: Metadata;
        feeTo: Principal;
        // status info
        historySize: Nat;
        deployTime: Time.Time;
        holderNumber: Nat;
        cycles: Nat;
    };
    public query func getTokenInfo(): async TokenInfo {
        {
            metadata = {
                logo = logo_;
                name = name_;
                symbol = symbol_;
                decimals = decimals_;
                totalSupply = totalSupply_;
                owner = owner_;
                fee = fee;
            };
            feeTo = feeTo;
            historySize = txcounter;
            deployTime = genesis.timestamp;
            holderNumber = balances.size();
            cycles = Cycles.balance();
        }
    };

    public query func getHolders(start: Nat, limit: Nat) : async [(Principal, Nat)] {
        let temp =  Iter.toArray(balances.entries());
        func order (a: (Principal, Nat), b: (Principal, Nat)) : Order.Order {
            return Nat.compare(b.1, a.1);
        };
        let sorted = Array.sort(temp, order);
        let limit_: Nat = if(start + limit > temp.size()) {
            temp.size() - start
        } else {
            limit
        };
        let res = Array.init<(Principal, Nat)>(limit_, (owner_, 0));
        for (i in Iter.range(0, limit_ - 1)) {
            res[i] := sorted[i+start];
        };
        return Array.freeze(res);
    };

    public query func getAllowanceSize() : async Nat {
        var size : Nat = 0;
        for ((k, v) in allowances.entries()) {
            size += v.size();
        };
        return size;
    };

    public query func getUserApprovals(who : Principal) : async [(Principal, Nat)] {
        switch (allowances.get(who)) {
            case (?allowance_who) {
                return Iter.toArray(allowance_who.entries());
            };
            case (_) {
                return [];
            };
        }
    };

    /*
    * upgrade functions
    */
    system func preupgrade() {
        balanceEntries := Iter.toArray(balances.entries());
        var size : Nat = allowances.size();
        var temp : [var (Principal, [(Principal, Nat)])] = Array.init<(Principal, [(Principal, Nat)])>(size, (owner_, []));
        size := 0;
        for ((k, v) in allowances.entries()) {
            temp[size] := (k, Iter.toArray(v.entries()));
            size += 1;
        };
        allowanceEntries := Array.freeze(temp);
    };

    system func postupgrade() {
        balances := HashMap.fromIter<Principal, Nat>(balanceEntries.vals(), 1, Principal.equal, Principal.hash);
        balanceEntries := [];
        for ((k, v) in allowanceEntries.vals()) {
            let allowed_temp = HashMap.fromIter<Principal, Nat>(v.vals(), 1, Principal.equal, Principal.hash);
            allowances.put(k, allowed_temp);
        };
        allowanceEntries := [];
    };

    public query func http_request(request : Http.Request) : async Http.Response {
        let path = Iter.toArray(Text.tokens(request.url, #text("/")));
        if (path.size() == 1) {
            switch (path[0]) {
                case ("burnt") return _natResponse(burnt);
                case ("log") return _textResponse(log);
                case (_) return return Http.BAD_REQUEST();
            };
        } else if (path.size() == 2) {
            switch (path[0]) {
                case ("balance") return _natResponse(_balanceOf(Principal.fromText(path[1])));
                case (_) return return Http.BAD_REQUEST();
            };
        } else {
            return Http.BAD_REQUEST();
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

    private func _textResponse(value : Text) : Http.Response {
        let json = #String(value);
        let blob = Text.encodeUtf8(JSON.show(json));
        let response : Http.Response = {
            status_code = 200;
            headers = [("Content-Type", "application/json")];
            body = blob;
            streaming_strategy = null;
        };
    };
};
