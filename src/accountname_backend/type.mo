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
	public type Main = {
		name : Text;
		expires_at : Nat64;
		spenders : Accounts<(expires_at : ?Nat64)>;
	};
	public type Role = {
		#Proxy : (main : ICRC1T.Account, expires_at : Nat64);
		#Main : Main;
	};
	public type User = RBTree.Type<(sub : Blob), Role>;

	public type RegisterArg = {
		proxy_subaccount : ?Blob; //
		name : ?Text; // null if renewing
		amount : Nat; // icp
		fee : ?Nat; //
		memo : ?Blob; //
		created_at : ?Nat64; //
	};
	public type RegisterErr = {
		#GenericError : Error.Type;
		#UnproxiedCaller;
		#UnknownProxy;
		#Locked;
		#UnnamedAccount;
		#NameTooLong : { maximum_length : Nat };
		#NamedAccount : { name : Text; expires_at : Nat64 };
		#ReservedName : { main : ICRC1T.Account };
		#BadFee : { expected_fee : Nat };
		#InsufficientLinkAllowance : { allowance : Nat };
		#InsufficientLinkCredits;
		#InsufficientTokenBalance : { balance : Nat };
		#InsufficientTokenAllowance : { allowance : Nat };
		#CreatedInFuture : { time : Nat64 };
		#TooOld;
		#Duplicate : { of : Nat };
		#FailedTransfer : Linker.TransferFrom1Err;
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
		#SenderIsProxy : { main : ICRC1T.Account };
		#RecipientIsProxy : { main : ICRC1T.Account };
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
		#SenderIsProxy : { main : ICRC1T.Account };
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
		#SenderIsProxy : { main : ICRC1T.Account };
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
		#SenderIsProxy : { main : ICRC1T.Account };
		#RecipientIsProxy : { main : ICRC1T.Account };
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
