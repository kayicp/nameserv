import RBTree "../util/motoko/StableCollections/RedBlackTree/RBTree";
import Value "../util/motoko/Value";
import Error "../util/motoko/Error";
import Result "../util/motoko/Result";
import ICRC1T "../icrc1_canister/Types";

module {
	public let ID = "lhuc4-nqaaa-aaaan-qz3gq-cai";
	type TransferFromError = {
		#GenericError : Error.Type;
		#TemporarilyUnavailable;
		#InsufficientAllowance : { allowance : Nat };
		#BadBurn : { min_burn_amount : Nat };
		#Duplicate : { duplicate_of : Nat };
		#BadFee : { expected_fee : Nat };
		#CreatedInFuture : { ledger_time : Nat64 };
		#TooOld;
		#InsufficientFunds : { balance : Nat };
	};
	public type Allowance1Arg = {
		proxy : ICRC1T.Account;
		spender : ICRC1T.Account;
		token : Principal;
	};
	public type TokenApproval = {
		allowance : Nat;
		expires_at : ?Nat64;
	};
	public type TransferFrom1Arg = {
		spender_subaccount : ?Blob;
		token : Principal;
		proxy : ICRC1T.Account;
		amount : Nat;
		to : ICRC1T.Account;
		memo : ?Blob;
		created_at : ?Nat64;
	};
	public type TransferFrom1Err = {
		#GenericError : Error.Type;
		#Locked : { amount : Nat };
		#InsufficientBalance;
		#InsufficientAllowance : { allowance : Nat };
		#Unproxied; // proxy is not proxied
		#CreatedInFuture : { time : Nat64 };
		#TooOld;
		#Duplicate : { of : Nat };
		#TransferFailed : TransferFromError;
	};
	public type TransferFrom1Res = Result.Type<Nat, TransferFrom1Err>;
	public type Canister = actor {
		accountlink_main_accounts_of : shared query [ICRC1T.Account] -> async [?ICRC1T.Account];
		accountlink_subaccounts_of : shared query (Principal, ?Blob, ?Nat) -> async [Blob];
		accountlink_proxies_of : shared query (ICRC1T.Account, ?Principal, ?Nat) -> async [Principal];
		accountlink_proxy_subaccounts_of : shared query (ICRC1T.Account, Principal, ?Blob, ?Nat) -> async [Blob];
		accountlink_spenders_of : shared query (ICRC1T.Account, ICRC1T.Account, ?Principal, ?Nat) -> async [Principal];
		accountlink_spender_subaccounts_of : shared query (ICRC1T.Account, ICRC1T.Account, Principal, ?Blob, ?Nat) -> async [Blob];
		accountlink_icrc1_tokens_of : shared query (ICRC1T.Account, ICRC1T.Account, ICRC1T.Account, ?Principal, ?Nat) -> async [Principal];
		accountlink_icrc1_allowances_of : shared query [Allowance1Arg] -> async [TokenApproval];
		accountlink_credits_of : shared query (args : [ICRC1T.Account]) -> async [Nat];

		accountlink_icrc1_transfer_from : shared TransferFrom1Arg -> async TransferFrom1Res;
	};
};
