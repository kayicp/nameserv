import T "type";
import Blob "mo:core/Blob";
import Nat "mo:base/Nat";
import Principal "mo:core/Principal";
import Order "mo:core/Order";
import Nat64 "mo:core/Nat64";
import Nat8 "mo:base/Nat8";
import RBTree "../util/motoko/StableCollections/RedBlackTree/RBTree";
import Value "../util/motoko/Value";
import Subaccount "../util/motoko/Subaccount";
import Option "../util/motoko/Option";
import OptionBase "mo:base/Option";
import Text "mo:base/Text";
import ICRC1T "../icrc1_canister/Types";
import Error "../util/motoko/Error";
import Result "../util/motoko/Result";
import Linker "linker";

module {
	public func initMain() : T.Main = {
		name = "";
		expires_at = 0;
		managers = RBTree.empty();
	};
	public func isMain(m : T.Main) : Bool = Text.size(m.name) > 0 or m.expires_at > 0 or RBTree.size(m.managers) > 0;

	public func getRole(u : T.User, s : Blob) : T.Role = switch (RBTree.get(u, Blob.compare, s)) {
		case (?found) found;
		case _ #Main(initMain());
	};
	public func getOwner<V>(acs : T.Accounts<V>, p : Principal) : RBTree.Type<Blob, V> = switch (RBTree.get(acs, Principal.compare, p)) {
		case (?found) found;
		case _ RBTree.empty();
	};
	public func saveOwner<V>(acs : T.Accounts<V>, p : Principal, ac : RBTree.Type<Blob, V>) : T.Accounts<V> = if (RBTree.size(ac) > 0) RBTree.insert(acs, Principal.compare, p, ac) else RBTree.delete(acs, Principal.compare, p);

	public func saveSub<V>(subs : T.Subs<V>, b : Blob, v : V) : T.Subs<V> = if (RBTree.size(subs) > 0) RBTree.insert(subs, Blob.compare, b, v) else RBTree.delete(subs, Blob.compare, b);

	public func forceMain(r : T.Role) : T.Main = switch r {
		case (#Main m) m;
		case _ initMain();
	};
	public func saveRole(u : T.User, s : Blob, r : T.Role) : T.User = switch r {
		case (#Main m) if (isMain(m)) RBTree.insert(u, Blob.compare, s, #Main m) else RBTree.delete(u, Blob.compare, s);
		case (#Proxy(main_a, expiry)) if (expiry > 0) RBTree.insert(u, Blob.compare, s, #Proxy(main_a, expiry)) else RBTree.delete(u, Blob.compare, s);
	};

	public func dedupeRegister((ap, a): (Principal, T.RegisterArg), (bp, b): (Principal, T.RegisterArg)) : Order.Order {
		#equal
	};

	public func dedupeApprove((ap, a): (Principal, T.ApproveArg), (bp, b): (Principal, T.ApproveArg)) : Order.Order {
		#equal
	};
};
