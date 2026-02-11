module {
	public let ID = "lhuc4-nqaaa-aaaan-qz3gq-cai";
	public type Account = { owner : Principal; subaccount : ?Blob };
	public type Allowance1Arg = {
		token : Principal;
		main : Account;
		proxy : Account;
		spender : Account;
	};
	public type AllowancesOfRes = {
		total : Nat;
		results : [TokenApproval];
		callbacks : [Callback_9];
	};
	public type Approve1Arg = {
		token : Principal;
		main_subaccount : ?Blob;
		memo : ?Blob;
		created_at : ?Nat64;
		proxy : Account;
		amount : Nat;
		expected_allowance : ?Nat;
		expires_at : Nat64;
		spender : Account;
	};
	public type Approve1Err = {
		#GenericError : Type;
		#Duplicate : { of : Nat };
		#InsufficientLinkCredits;
		#ProxyIsMain;
		#ExpiresTooLate : { maximum_expiry : Nat64 };
		#CallerIsProxy : { of : Account };
		#CreatedInFuture : { time : Nat64 };
		#LinkAllowanceChanged : { allowance : Nat };
		#TooOld;
		#Expired : { time : Nat64 };
		#ProxyReserved : { by : Account };
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
	public type Callback_10 = {
		args : [Account];
		query_func : shared query [Account] -> async CreditsOfRes;
	};
	public type Callback_2 = {
		args : Filter1Arg;
		query_func : shared query Filter1Arg -> async Filter1Res;
	};
	public type Callback_3 = {
		args : SpendersOfArg;
		query_func : shared query SpendersOfArg -> async SpendersOfRes;
	};
	public type Callback_4 = {
		args : SpenderSubsOfArg;
		query_func : shared query SpenderSubsOfArg -> async SpenderSubsOfRes;
	};
	public type Callback_5 = {
		args : ProxySubsOfArg;
		query_func : shared query ProxySubsOfArg -> async ProxySubsOfRes;
	};
	public type Callback_6 = {
		args : ProxiesOfArg;
		query_func : shared query ProxiesOfArg -> async ProxiesOfRes;
	};
	public type Callback_7 = {
		args : MainsOfArg;
		query_func : shared query MainsOfArg -> async MainsOfRes;
	};
	public type Callback_8 = {
		args : SubmainsOfArg;
		query_func : shared query SubmainsOfArg -> async SubmainsOfRes;
	};
	public type Callback_9 = {
		args : [Allowance1Arg];
		query_func : shared query [Allowance1Arg] -> async AllowancesOfRes;
	};
	public type Canister = actor {
		accl_credit_packages : shared query () -> async [CreditPackage];
		accl_credits : shared query [Account] -> async CreditsOfRes;
		accl_icrc1_allowances : shared query [
			Allowance1Arg
		] -> async AllowancesOfRes;
		accl_icrc1_approve : shared [Approve1Arg] -> async [Approve1Res];
		accl_icrc1_main_subaccounts : shared query SubmainsOfArg -> async SubmainsOfRes;
		accl_icrc1_mains : shared query MainsOfArg -> async MainsOfRes;
		accl_icrc1_proxies : shared query ProxiesOfArg -> async ProxiesOfRes;
		accl_icrc1_proxy_subaccounts : shared query ProxySubsOfArg -> async ProxySubsOfRes;
		accl_icrc1_spender_subaccounts : shared query SpenderSubsOfArg -> async SpenderSubsOfRes;
		accl_icrc1_spenders : shared query SpendersOfArg -> async SpendersOfRes;
		accl_icrc1_sufficient_allowances : shared query Filter1Arg -> async Filter1Res;
		accl_icrc1_tokens : shared query TokensOfArg -> async TokensOfRes;
		accl_icrc1_transfer_from : shared TransferFrom1Arg -> async TransferFrom1Res;
		accl_mint_credits : shared TopupArg -> async TopupRes;
		accl_service_provider : shared query () -> async Account;
		accl_subaccounts : shared query SubaccountsOfArg -> async SubaccountsOfRes;
	};
	public type CreditPackage = {
		credits : Nat;
		tcycles_fee_multiplier : Nat;
		bonus : Nat;
	};
	public type CreditsOfRes = {
		total : Nat;
		results : [Nat];
		callbacks : [Callback_10];
	};
	public type Filter1Arg = {
		token : Principal;
		previous : ?Account;
		take : ?Nat;
		allowance : Nat;
		proxy : Account;
		spender : Account;
	};
	public type Filter1Res = {
		total : Nat;
		results : [FilteredAllowance];
		callbacks : [Callback_2];
	};
	public type FilteredAllowance = {
		main : Account;
		allowance : Nat;
		expires_at : Nat64;
	};
	public type MainsOfArg = {
		token : Principal;
		previous : ?Principal;
		take : ?Nat;
		proxy : Account;
		spender : Account;
	};
	public type MainsOfRes = {
		total : Nat;
		results : [Principal];
		callbacks : [Callback_7];
	};
	public type ProxiesOfArg = {
		previous : ?Principal;
		main : Account;
		take : ?Nat;
	};
	public type ProxiesOfRes = {
		total : Nat;
		results : [Principal];
		callbacks : [Callback_6];
	};
	public type ProxySubsOfArg = {
		previous : ?Blob;
		proxy_owner : Principal;
		main : Account;
		take : ?Nat;
	};
	public type ProxySubsOfRes = {
		total : Nat;
		results : [Blob];
		callbacks : [Callback_5];
	};
	public type SpenderSubsOfArg = {
		previous : ?Blob;
		spender_owner : Principal;
		take : ?Nat;
		proxy : Account;
	};
	public type SpenderSubsOfRes = {
		total : Nat;
		results : [Blob];
		callbacks : [Callback_4];
	};
	public type SpendersOfArg = {
		previous : ?Principal;
		take : ?Nat;
		proxy : Account;
	};
	public type SpendersOfRes = {
		total : Nat;
		results : [Principal];
		callbacks : [Callback_3];
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
		proxy : Account;
		spender : Account;
	};
	public type SubmainsOfRes = {
		total : Nat;
		results : [Blob];
		callbacks : [Callback_8];
	};
	public type TokenApproval = { allowance : Nat; expires_at : Nat64 };
	public type TokensOfArg = {
		previous : ?Principal;
		take : ?Nat;
		proxy : Account;
		spender : Account;
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
		#UnknownPrice : { xdr_permyriad_per_icp : Nat };
		#TooOld;
		#TransferFailed : TransferFromError;
		#InsufficientTokenBalance : { balance : Nat };
	};
	public type TopupRes = { #Ok : Nat; #Err : TopupErr };
	public type TransferFrom1Arg = {
		to : Account;
		token : Principal;
		spender_subaccount : ?Blob;
		main : ?Account;
		memo : ?Blob;
		created_at : ?Nat64;
		proxy : Account;
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
		#NoEligibleMain : {
			maximum_allowance : { main : ?Account; available : Nat };
			total_checked : Nat;
			maximum_balance : { main : ?Account; available : Nat };
		};
		#TooOld;
		#NoSufficientLinkAllowance : {
			total_active : Nat;
			total_valid : Nat;
			maximum : { main : ?Account; available : Nat };
		};
		#TransferFailed : TransferFromError;
		#InsufficientTokenBalance : { balance : Nat };
		#UnknownToken;
	};
	public type TransferFrom1Res = {
		#Ok : { block_index : Nat; main : Account };
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
