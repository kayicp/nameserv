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
		managers : Accounts<(expires_at : ?Nat64)>;
	};
	public type Role = {
		#Proxy : (main : ICRC1T.Account, expires_at : Nat64);
		#Main : Main;
	};
	public type User = RBTree.Type<(sub : Blob), Role>;

	public type RegisterArg = {
		subaccount : ?Blob;
		name : Text;
		amount : Nat; // icp
		fee : ?Nat;
		memo : ?Blob;
		created_at : ?Nat64;
	};
	public type RegisterErr = {
		#GenericError : Error.Type;
		#UnknownPrice;
		#BadFee : { expected_fee : Nat };
		#InsufficientLinkAllowance : { allowance : Nat };
		#InsufficientTokenBalance : { balance : Nat };
		#InsufficientTokenAllowance : { allowance : Nat };
		#Locked : { amount : Nat };
		#CreatedInFuture : { time : Nat64 };
		#TooOld;
		#Duplicate : { of : Nat };
		#FailedTransfer : Linker.TransferFrom1Err;
	};
	public type RegisterRes = Result.Type<Nat, RegisterErr>;

	public type TransferArg = {
		from_subaccount : ?Blob;
		to : ICRC1T.Account;
		expiry_reduction : ?Nat64; // fee
		memo : ?Blob;
	};
	public type TransferErr = {

	};
	public type TransferRes = Result.Type<Nat, TransferErr>;

	public type ApproveArg = {
		from_subaccount : ?Blob;
		manager : ICRC1T.Account;
		expires_at : ?Nat64;
		expiry_reduction : ?Nat64; // fee
		memo : ?Blob;
		created_at : ?Nat64;
	};
	public type ApproveErr = {

	};
	public type ApproveRes = Result.Type<Nat, ApproveErr>;

	public type TransferFromArg = {
		manager_subaccount : ?Blob;
		from : ICRC1T.Account;
		to : ICRC1T.Account;
		expiry_reduction : ?Nat64; // fee
		memo : ?Blob;
	};
	public type TransferFromErr = {

	};
	public type TransferFromRes = Result.Type<Nat, TransferFromErr>;

	public type ArgType = {
		#Register : RegisterArg;
		#Approve : ApproveArg;
	};

};
