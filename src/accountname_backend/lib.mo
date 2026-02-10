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
	public func getPrincipal<V>(tree : RBTree.Type<Principal, V>, k : Principal, default : V) : V = OptionBase.get(RBTree.get(tree, Principal.compare, k), default);

	public func getBlob<V>(tree : RBTree.Type<Blob, V>, k : Blob, default : V) : V = OptionBase.get(RBTree.get(tree, Blob.compare, k), default);

	public func savePrincipal<V>(tree : RBTree.Type<Principal, V>, k : Principal, v : V, is_insert : Bool) : RBTree.Type<Principal, V> = if (is_insert) RBTree.insert(tree, Principal.compare, k, v) else RBTree.delete(tree, Principal.compare, k);

	public func saveBlob<V>(tree : RBTree.Type<Blob, V>, k : Blob, v : V, is_insert : Bool) : RBTree.Type<Blob, V> = if (is_insert) RBTree.insert(tree, Blob.compare, k, v) else RBTree.delete(tree, Blob.compare, k);

	public func initMain() : T.Main = {
		name = "";
		expires_at = 0;
		spenders = RBTree.empty();
	};
	public func isMain(m : T.Main) : Bool = Text.size(m.name) > 0 or m.expires_at > 0 or RBTree.size(m.spenders) > 0;

	// public func forceMain(r : T.Role) : T.Main = switch r {
	//   case (#Main m) m;
	//   case _ initMain();
	// };
	// public func saveRole(u : T.User, s : Blob, r : T.Role) : T.User = switch r {
	//   case (#Main m) if (isMain(m)) RBTree.insert(u, Blob.compare, s, #Main m) else RBTree.delete(u, Blob.compare, s);
	//   case (#Proxy(main_a, expiry)) if (expiry > 0) RBTree.insert(u, Blob.compare, s, #Proxy(main_a, expiry)) else RBTree.delete(u, Blob.compare, s);
	// };

	public func dedupeRegister((ap, a) : (Principal, T.RegisterArg), (bp, b) : (Principal, T.RegisterArg)) : Order.Order {
		#equal;
	};

	public func dedupeApprove((ap, a) : (Principal, T.ApproveArg), (bp, b) : (Principal, T.ApproveArg)) : Order.Order {
		#equal;
	};

	public func compareProxyExpiry((at : Nat64, ap : Principal, as : Blob), (bt : Nat64, bp : Principal, bs : Blob)) : Order.Order {
		#equal; // todo: finish me
	};

	public func compareNameExpiry((at : Nat64, an : Text), (bt : Nat64, bn : Text)) : Order.Order {
		#equal; // todo: finish me
	};

	public func compareManagerExpiry(
		(
			at : Nat64,
			(afromowner : Principal, afromsub : Blob),
			(aspenderowner : Principal, aspendersub : Blob),
		),
		(
			bt : Nat64,
			(bfromowner : Principal, bfromsub : Blob),
			(bspenderowner : Principal, bspendersub : Blob),
		),
	) : Order.Order {
		#equal; // todo: finish me
	};
};
