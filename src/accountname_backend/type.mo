import RBTree "../util/motoko/StableCollections/RedBlackTree/RBTree";
import Value "../util/motoko/Value";
import Error "../util/motoko/Error";
import Result "../util/motoko/Result";
import Principal "mo:base/Principal";
import ICRC1T "../icrc1_canister/Types";
import Linker "linker";

module {
	public let CHARS = (['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z']);
	public let NUMS = (['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']);

	public type PriceTier = {
		length : { min : Nat; max : Nat };
		tcycles_fee_multiplier : Nat;
	};
	public type DurationPackage = { years_base : Nat; months_bonus : Nat };
	public type Environment = {
		memo_size : { min : Nat; max : Nat };
		duration : {
			tx_window : Nat64;
			permitted_drift : Nat64;
		};
		service_provider : Principal;
		cmc : ?Text;
		max_update_batch_size : Nat;
		max_query_batch_size : Nat;
		max_take_value : Nat;
		name : {
			price_tiers : [PriceTier];
			duration : {
				max_expiry : Nat64;
				toll : Nat64;
				lock : Nat64;
				packages : [DurationPackage];
			};
		};
		archive : {
			max_update_batch_size : Nat;
			root : ?Principal;
			standby : ?Principal;
			min_tcycles : Nat;
		};
	};

	public type Xccount = { owner : Principal; sub : Blob };
	public type Subs<T> = RBTree.Type<Blob, T>;
	public type Accounts<T> = RBTree.Type<Principal, Subs<T>>;
	public type Nats<T> = RBTree.Type<Nat, T>;
	public type Name = { name : Text; expires_at : Nat64 };
	public type Main = {
		name : Text;
		expires_at : Nat64;
		locked_until : Nat64;
		spenders : Accounts<(expires_at : Nat64)>;
	};
	public type User = RBTree.Type<(sub : Blob), Main>;
	public type Proxy = RBTree.Type<(sub : Blob), (main_p : Principal, main_sub : Blob, expires_at : Nat64)>;

	public type RegisterArg = {
		proxy_subaccount : ?Blob; //
		name : Text;
		amount : Nat; // icp/tcycles
		token : Principal;
		main : ?ICRC1T.Account; //
		memo : ?Blob; //
		created_at : ?Nat64; //
	};
	public type RegisterErr = {
		#GenericError : Error.Type;
		#UnproxiedCaller;
		#UnknownProxy;
		#UnknownLengthTier;
		#UnknownDurationPackage : { xdr_permyriad_per_icp : Nat };
		#NameTooLong : { maximum_length : Nat };
		#NamedAccount : Name;
		#NameReserved : { by : ICRC1T.Account };
		#Locked : { until : Nat64 };
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
		time_toll : ?Nat64; // fee
		memo : ?Blob; //
	};
	public type TransferErr = {
		#GenericError : Error.Type;
		#UnknownProxy;
		#SenderLocked : { until : Nat64 };
		#UnnamedSender;
		#NamedRecipient : { name : Text; expires_at : Nat64 };
		#InsufficientTime : { remaining : Nat64 };
		#BadTimeToll : { expected_time_toll : Nat64 };
	};
	public type TransferRes = Result.Type<Nat, TransferErr>;

	public type ApproveArg = {
		proxy_subaccount : ?Blob; //
		spender : ICRC1T.Account; //
		expires_at : Nat64; //
		time_toll : ?Nat64; // fee
		memo : ?Blob; //
		created_at : ?Nat64;
	};
	public type ApproveErr = {
		#GenericError : Error.Type;
		#UnknownProxy;
		#SenderLocked : { until : Nat64 };
		#UnnamedSender;
		#InsufficientTime : { remaining : Nat64 };
		#BadTimeToll : { expected_time_toll : Nat64 };
		#Expired : { time : Nat64 };
		#ExpiresTooLate : { maximum_expiry : Nat64 };
		#CreatedInFuture : { time : Nat64 };
		#TooOld;
		#Duplicate : { of : Nat };
	};
	public type ApproveRes = Result.Type<Nat, ApproveErr>;

	public type RevokeArg = {
		proxy_subaccount : ?Blob;
		spender : ICRC1T.Account;
		time_toll : ?Nat64; // fee
		memo : ?Blob;
	};
	public type RevokeErr = {
		#GenericError : Error.Type;
		#UnknownProxy;
		#SenderLocked : { until : Nat64 };
		#UnnamedSender;
		#InsufficientTime : { remaining : Nat64 };
		#BadTimeToll : { expected_time_toll : Nat64 };
		#UnknownSpender;
	};
	public type RevokeRes = Result.Type<Nat, RevokeErr>;

	public type TransferFromArg = {
		spender_subaccount : ?Blob; //
		proxy : ICRC1T.Account; //
		to : ICRC1T.Account; //
		time_toll : ?Nat64; // fee
		memo : ?Blob; //
	};
	public type TransferFromErr = {
		#GenericError : Error.Type;
		#SenderLocked : { until : Nat64 };
		#UnnamedSender;
		#UnknownProxy;
		#NamedRecipient : { name : Text; expires_at : Nat64 };
		#InsufficientTime : { remaining : Nat64 };
		#BadTimeToll : { expected_time_toll : Nat64 };
		#UnknownSpender;
	};
	public type TransferFromRes = Result.Type<Nat, TransferFromErr>;

	public type ArgType = {
		#Register : RegisterArg;
		#Approve : ApproveArg;
	};

};
