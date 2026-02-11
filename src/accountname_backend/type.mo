import RBTree "../util/motoko/StableCollections/RedBlackTree/RBTree";
import Value "../util/motoko/Value";
import Error "../util/motoko/Error";
import Result "../util/motoko/Result";
import Principal "mo:base/Principal";
import ICRC1T "../icrc1_canister/Types";
import Linker "linker";

module {
	public type Xccount = { owner : Principal; sub : Blob };
	public type Subs<T> = RBTree.Type<Blob, T>;
	public type Accounts<T> = RBTree.Type<Principal, Subs<T>>;
	public type Nats<T> = RBTree.Type<Nat, T>;
	public type Name = { name : Text; expires_at : Nat64 };
	public type Main = {
		name : Text;
		expires_at : Nat64;
		spenders : Accounts<(expires_at : ?Nat64)>;
	};
	public type User = RBTree.Type<(sub : Blob), Main>;
	public type Proxy = RBTree.Type<(sub : Blob), (main_p : Principal, main_sub : Blob, expires_at : Nat64)>;

	public type RegisterArg = {
		proxy_subaccount : ?Blob; //
		name : Text; // todo: validate
		amount : Nat; // icp/tcycles
		token : Principal;
		payer : ?ICRC1T.Account; //
		memo : ?Blob; //
		created_at : ?Nat64; //
	};
	public type RegisterErr = {
		#GenericError : Error.Type;
		#UnproxiedCaller;
		#UnknownProxy;
		#UnknownLengthTier;
		#UnknownDurationPackage : { xdr_permyriad_per_icp : Nat };
		#Locked;
		#Unnamed;
		#NameTooLong : { maximum_length : Nat };
		#NamedAccount : { name : Text; expires_at : Nat64 };
		#NameReserved : { by : ICRC1T.Account };
		#InsufficientLinkAllowance : { allowance : Nat };
		#InsufficientLinkCredits;
		#InsufficientTokenBalance : { balance : Nat };
		#InsufficientTokenAllowance : { allowance : Nat };
		#NoSufficientLinkAllowance : {
			total : Nat;
			maximum : { available : Nat; main : ?ICRC1T.Account };
		};
		#NoEligibleMain : {
			total : Nat;
			maximum_balance : { available : Nat; main : ?ICRC1T.Account };
			maximum_allowance : { available : Nat; main : ?ICRC1T.Account };
		};
		#CreatedInFuture : { time : Nat64 };
		#TooOld;
		#Duplicate : { of : Nat };
		#TransferFailed : Linker.TransferFrom1Err;
	};
	public type RegisterRes = Result.Type<Nat, RegisterErr>;

	public type TransferArg = {
		proxy_subaccount : ?Blob; //
		to : ICRC1T.Account; //
		expiry_reduction : ?Nat64; // fee
		memo : ?Blob; //
	};
	public type TransferErr = {
		#GenericError : Error.Type;
		#UnknownProxy;
		#SenderIsProxy : { of : ICRC1T.Account };
		#RecipientIsProxy : { of : ICRC1T.Account };
		#LockedSender;
		#UnnamedSender;
		#LockedRecipient;
		#NamedRecipient : { name : Text; expires_at : Nat64 };
		#InsufficientDuration : { remaining : Nat64 };
		#BadExpiryReduction : { expected_expiry_reduction : Nat64 };
	};
	public type TransferRes = Result.Type<Nat, TransferErr>;

	public type ApproveArg = {
		proxy_subaccount : ?Blob; //
		spender : ICRC1T.Account; //
		expires_at : ?Nat64; //
		expiry_reduction : ?Nat64; // fee
		memo : ?Blob; //
		created_at : ?Nat64;
	};
	public type ApproveErr = {
		#GenericError : Error.Type;
		#UnknownProxy;
		#SenderIsProxy : { of : ICRC1T.Account };
		#Locked;
		#Unnamed;
		#InsufficientDuration : { remaining : Nat64 };
		#BadExpiryReduction : { expected_expiry_reduction : Nat64 };
		#Expired : { time : Nat64 };
		#CreatedInFuture : { time : Nat64 };
		#TooOld;
		#Duplicate : { of : Nat };
	};
	public type ApproveRes = Result.Type<Nat, ApproveErr>;

	public type RevokeArg = {
		proxy_subaccount : ?Blob;
		spender : ICRC1T.Account;
		expiry_reduction : ?Nat64; // fee
		memo : ?Blob;
	};
	public type RevokeErr = {
		#GenericError : Error.Type;
		#UnknownProxy;
		#SenderIsProxy : { of : ICRC1T.Account };
		#Locked;
		#Unnamed;
		#InsufficientDuration : { remaining : Nat64 };
		#BadExpiryReduction : { expected_expiry_reduction : Nat64 };
		#UnknownSpender;
	};
	public type RevokeRes = Result.Type<Nat, RevokeErr>;

	public type TransferFromArg = {
		spender_subaccount : ?Blob;
		proxy : ICRC1T.Account;
		to : ICRC1T.Account;
		expiry_reduction : ?Nat64; // fee
		memo : ?Blob;
	};
	public type TransferFromErr = {
		#GenericError : Error.Type;
		#LockedSender;
		#UnnamedSender;
		#UnknownProxy;
		#SenderIsProxy : { of : ICRC1T.Account };
		#RecipientIsProxy : { of : ICRC1T.Account };
		#LockedRecipient;
		#NamedRecipient : { name : Text; expires_at : Nat64 };
		#InsufficientDuration : { remaining : Nat64 };
		#BadExpiryReduction : { expected_expiry_reduction : Nat64 };
		#UnknownSpender;
	};
	public type TransferFromRes = Result.Type<Nat, TransferFromErr>;

	public type ArgType = {
		#Register : RegisterArg;
		#Approve : ApproveArg;
	};

};
