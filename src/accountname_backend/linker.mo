import RBTree "../util/motoko/StableCollections/RedBlackTree/RBTree";
import Value "../util/motoko/Value";
import Error "../util/motoko/Error";
import Result "../util/motoko/Result";
import ICRC1T "../icrc1_canister/Types";

module {
	public let ID = "lhuc4-nqaaa-aaaan-qz3gq-cai";
	public type Allowance1Arg = {
		token : Principal;
		main : ICRC1T.Account;
		proxy : ICRC1T.Account;
		spender : ICRC1T.Account;
	};
	public type AllowancesOfRes = {
		total : Nat;
		results : [TokenApproval];
		callbacks : [Callback_8];
	};
	public type Approve1Arg = {
		token : Principal;
		main_subaccount : ?Blob;
		memo : ?Blob;
		created_at : ?Nat64;
		proxy : ICRC1T.Account;
		amount : Nat;
		expected_allowance : ?Nat;
		expires_at : Nat64;
		spender : ICRC1T.Account;
	};
	public type Approve1Err = {
		#GenericError : Type;
		#Duplicate : { of : Nat };
		#InsufficientLinkCredits;
		#ProxyIsMain;
		#ExpiresTooLate : { maximum_expiry : Nat64 };
		#CallerIsProxy : { of : ICRC1T.Account };
		#CreatedInFuture : { time : Nat64 };
		#LinkAllowanceChanged : { allowance : Nat };
		#TooOld;
		#Expired : { time : Nat64 };
		#ProxyReserved : { by : ICRC1T.Account };
	};
	public type Approve1Res = { #Ok : Nat; #Err : Approve1Err };
	public type Callback = {
		args : SubaccountsOfArg;
		query_func : shared query SubaccountsOfArg -> async SubaccountsOfRes;
	};
	public type Callback_1 = {
		args : TokensOfArg;
		query_func : shared query TokensOfArg -> async TokensOfRes;
	};
	public type Callback_2 = {
		args : SpendersOfArg;
		query_func : shared query SpendersOfArg -> async SpendersOfRes;
	};
	public type Callback_3 = {
		args : SpenderSubsOfArg;
		query_func : shared query SpenderSubsOfArg -> async SpenderSubsOfRes;
	};
	public type Callback_4 = {
		args : ProxySubsOfArg;
		query_func : shared query ProxySubsOfArg -> async ProxySubsOfRes;
	};
	public type Callback_5 = {
		args : ProxiesOfArg;
		query_func : shared query ProxiesOfArg -> async ProxiesOfRes;
	};
	public type Callback_6 = {
		args : MainsOfArg;
		query_func : shared query MainsOfArg -> async MainsOfRes;
	};
	public type Callback_7 = {
		args : SubmainsOfArg;
		query_func : shared query SubmainsOfArg -> async SubmainsOfRes;
	};
	public type Callback_8 = {
		args : [Allowance1Arg];
		query_func : shared query [Allowance1Arg] -> async AllowancesOfRes;
	};
	public type Callback_9 = {
		args : [ICRC1T.Account];
		query_func : shared query [ICRC1T.Account] -> async CreditsOfRes;
	};
	public type Canister = actor {
		accl_credit_packages : shared query () -> async [CreditPackage];
		accl_credits_of : shared query [ICRC1T.Account] -> async CreditsOfRes;
		accl_icrc1_allowances_of : shared query [
			Allowance1Arg
		] -> async AllowancesOfRes;
		accl_icrc1_approve : shared [Approve1Arg] -> async [Approve1Res];
		accl_icrc1_main_subaccounts_of : shared query SubmainsOfArg -> async SubmainsOfRes;
		accl_icrc1_mains_of : shared query MainsOfArg -> async MainsOfRes;
		accl_icrc1_proxies_of : shared query ProxiesOfArg -> async ProxiesOfRes;
		accl_icrc1_proxy_subaccounts_of : shared query ProxySubsOfArg -> async ProxySubsOfRes;
		accl_icrc1_spender_subaccounts_of : shared query SpenderSubsOfArg -> async SpenderSubsOfRes;
		accl_icrc1_spenders_of : shared query SpendersOfArg -> async SpendersOfRes;
		accl_icrc1_tokens_of : shared query TokensOfArg -> async TokensOfRes;
		accl_icrc1_transfer_from : shared TransferFrom1Arg -> async TransferFrom1Res;
		accl_mint_credits : shared TopupArg -> async TopupRes;
		accl_service_provider : shared query () -> async ICRC1T.Account;
		accl_subaccounts_of : shared query SubaccountsOfArg -> async SubaccountsOfRes;
	};
	public type CreditPackage = {
		credits : Nat;
		tcycles_fee_multiplier : Nat;
		bonus : Nat;
	};
	public type CreditsOfRes = {
		total : Nat;
		results : [Nat];
		callbacks : [Callback_9];
	};
	public type MainsOfArg = {
		token : Principal;
		previous : ?Principal;
		take : ?Nat;
		proxy : ICRC1T.Account;
		spender : ICRC1T.Account;
	};
	public type MainsOfRes = {
		total : Nat;
		results : [Principal];
		callbacks : [Callback_6];
	};
	public type ProxiesOfArg = {
		previous : ?Principal;
		main : ICRC1T.Account;
		take : ?Nat;
	};
	public type ProxiesOfRes = {
		total : Nat;
		results : [Principal];
		callbacks : [Callback_5];
	};
	public type ProxySubsOfArg = {
		previous : ?Blob;
		proxy_owner : Principal;
		main : ICRC1T.Account;
		take : ?Nat;
	};
	public type ProxySubsOfRes = {
		total : Nat;
		results : [Blob];
		callbacks : [Callback_4];
	};
	public type SpenderSubsOfArg = {
		previous : ?Blob;
		spender_owner : Principal;
		take : ?Nat;
		proxy : ICRC1T.Account;
	};
	public type SpenderSubsOfRes = {
		total : Nat;
		results : [Blob];
		callbacks : [Callback_3];
	};
	public type SpendersOfArg = {
		previous : ?Principal;
		take : ?Nat;
		proxy : ICRC1T.Account;
	};
	public type SpendersOfRes = {
		total : Nat;
		results : [Principal];
		callbacks : [Callback_2];
	};
	public type SubaccountsOfArg = {
		previous : ?Blob;
		take : ?Nat;
		main_owner : Principal;
	};
	public type SubaccountsOfRes = {
		total : Nat;
		results : [Blob];
		callbacks : [Callback];
	};
	public type SubmainsOfArg = {
		token : Principal;
		previous : ?Blob;
		take : ?Nat;
		main_owner : Principal;
		proxy : ICRC1T.Account;
		spender : ICRC1T.Account;
	};
	public type SubmainsOfRes = {
		total : Nat;
		results : [Blob];
		callbacks : [Callback_7];
	};
	public type TokenApproval = { allowance : Nat; expires_at : Nat64 };
	public type TokensOfArg = {
		previous : ?Principal;
		take : ?Nat;
		proxy : ICRC1T.Account;
		spender : ICRC1T.Account;
	};
	public type TokensOfRes = {
		total : Nat;
		results : [Principal];
		callbacks : [Callback_1];
	};
	public type TopupArg = {
		token : Principal;
		main_subaccount : ?Blob;
		memo : ?Blob;
		created_at : ?Nat64;
		amount : Nat;
	};
	public type TopupErr = {
		#GenericError : Type;
		#Duplicate : { of : Nat };
		#CreatedInFuture : { time : Nat64 };
		#InsufficientTokenAllowance : { allowance : Nat };
		#UnknownPrice;
		#TooOld;
		#TransferFailed : TransferFromError;
		#InsufficientTokenBalance : { balance : Nat };
	};
	public type TopupRes = { #Ok : Nat; #Err : TopupErr };
	public type TransferFrom1Arg = {
		to : ICRC1T.Account;
		token : Principal;
		spender_subaccount : ?Blob;
		main : ?ICRC1T.Account;
		memo : ?Blob;
		created_at : ?Nat64;
		proxy : ICRC1T.Account;
		amount : Nat;
	};
	public type TransferFrom1Err = {
		#GenericError : Type;
		#UnknownSpender;
		#Duplicate : { of : Nat };
		#InsufficientLinkCredits;
		#InsufficientLinkAllowance : { allowance : Nat };
		#CreatedInFuture : { time : Nat64 };
		#InsufficientTokenAllowance : { allowance : Nat };
		#UnknownProxy;
		#NoPayableMain : {
			maximum_allowance : { main : ?ICRC1T.Account; available : Nat };
			total_checked : Nat;
			maximum_balance : { main : ?ICRC1T.Account; available : Nat };
		};
		#TooOld;
		#NoUsableLinkAllowance : {
			total_active : Nat;
			total_valid : Nat;
			maximum : { main : ?ICRC1T.Account; available : Nat };
		};
		#TransferFailed : TransferFromError;
		#InsufficientTokenBalance : { balance : Nat };
		#UnknownToken;
	};
	public type TransferFrom1Res = {
		#Ok : { block_index : Nat; main : ICRC1T.Account };
		#Err : TransferFrom1Err;
	};
	public type TransferFromError = {
		#GenericError : Type;
		#TemporarilyUnavailable;
		#InsufficientAllowance : { allowance : Nat };
		#BadBurn : { min_burn_amount : Nat };
		#Duplicate : { duplicate_of : Nat };
		#BadFee : { expected_fee : Nat };
		#CreatedInFuture : { ledger_time : Nat64 };
		#TooOld;
		#InsufficientFunds : { balance : Nat };
	};
	public type Type = { message : Text; error_code : Nat };
};
