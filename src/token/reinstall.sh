#!/bin/bash

dfx canister --network ic install database --mode reinstall

dfx canister --network ic install reflectionDatabase --mode reinstall

dfx canister --network ic install taxCollector --mode reinstall

dfx canister --network ic install token\
	--argument="(
        \"data:image/jpeg;base64,$(base64 icon.png)\",
        \"Your Coin\",
        \"YC\",
        8,
        100000000000000000000,
        principal \"$(dfx identity get-principal)\", 
        0, 
        )" \
    --mode reinstall    
