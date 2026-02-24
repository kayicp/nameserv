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
import ICRC1L "../icrc1_canister/ICRC1";
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
		locked_until = 0;
		spenders = RBTree.empty();
	};
	public func isMain(m : T.Main) : Bool = Text.size(m.name) > 0 or RBTree.size(m.spenders) > 0;

	public func dedupeRegister((ap, a) : (Principal, T.RegisterArg), (bp, b) : (Principal, T.RegisterArg)) : Order.Order {
		switch (Option.compare(a.created_at, b.created_at, Nat64.compare)) {
			case (#equal) ();
			case other return other;
		};
		switch (Text.compare(a.name, b.name)) {
			case (#equal) ();
			case other return other;
		};
		switch (Nat.compare(a.amount, b.amount)) {
			case (#equal) ();
			case other return other;
		};
		switch (Principal.compare(a.token, b.token)) {
			case (#equal) ();
			case other return other;
		};
		switch (Option.compare(a.memo, b.memo, Blob.compare)) {
			case (#equal) ();
			case other return other;
		};
		switch (ICRC1L.compareAccount({ owner = ap; subaccount = a.proxy_subaccount }, { owner = bp; subaccount = b.proxy_subaccount })) {
			case (#equal) ();
			case other return other;
		};
		switch (Option.compare(a.main, b.main, ICRC1L.compareAccount)) {
			case (#equal) ();
			case other return other;
		};
		#equal;
	};

	public func dedupeApprove((ap, a) : (Principal, T.ApproveArg), (bp, b) : (Principal, T.ApproveArg)) : Order.Order {
		switch (Option.compare(a.created_at, b.created_at, Nat64.compare)) {
			case (#equal) ();
			case other return other;
		};
		switch (Nat64.compare(a.expires_at, b.expires_at)) {
			case (#equal) ();
			case other return other;
		};
		switch (Option.compare(a.time_toll, b.time_toll, Nat64.compare)) {
			case (#equal) ();
			case other return other;
		};
		switch (Option.compare(a.memo, b.memo, Blob.compare)) {
			case (#equal) ();
			case other return other;
		};
		switch (ICRC1L.compareAccount(a.spender, b.spender)) {
			case (#equal) ();
			case other return other;
		};
		switch (ICRC1L.compareAccount({ owner = ap; subaccount = a.proxy_subaccount }, { owner = bp; subaccount = b.proxy_subaccount })) {
			case (#equal) ();
			case other return other;
		};
		#equal;
	};

	public func compareProxyExpiry((at : Nat64, ap : Principal, as : Blob), (bt : Nat64, bp : Principal, bs : Blob)) : Order.Order {
		switch (Nat64.compare(at, bt)) {
			case (#equal) ();
			case other return other;
		};
		switch (Principal.compare(ap, bp)) {
			case (#equal) ();
			case other return other;
		};
		switch (Blob.compare(as, bs)) {
			case (#equal) ();
			case other return other;
		};
		#equal;
	};

	public func compareNameExpiry((at : Nat64, an : Text), (bt : Nat64, bn : Text)) : Order.Order {
		switch (Nat64.compare(at, bt)) {
			case (#equal) ();
			case other return other;
		};
		switch (Text.compare(an, bn)) {
			case (#equal) ();
			case other return other;
		};
		#equal;
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
		switch (Nat64.compare(at, bt)) {
			case (#equal) ();
			case other return other;
		};
		switch (Principal.compare(afromowner, bfromowner)) {
			case (#equal) ();
			case other return other;
		};
		switch (Blob.compare(afromsub, bfromsub)) {
			case (#equal) ();
			case other return other;
		};
		switch (Principal.compare(aspenderowner, bspenderowner)) {
			case (#equal) ();
			case other return other;
		};
		switch (Blob.compare(aspendersub, bspendersub)) {
			case (#equal) ();
			case other return other;
		};
		#equal;
	};

	public func valueRegister(caller : Principal, arg : T.RegisterArg, pay_id : Nat, now : Nat64, phash : ?Blob) : Value.Type {
		var tx = RBTree.empty<Text, Value.Type>();

		var map = RBTree.empty<Text, Value.Type>();
		map := Value.setNat(map, "xfer", ?pay_id);
		map := Value.setNat(map, "ts", ?Nat64.toNat(now));
		map := Value.setText(map, "op", ?"add_credits");
		map := Value.setMap(map, "tx", tx);
		map := Value.setBlob(map, "phash", phash);
		#Map(RBTree.array(map));
	};

	public func valueTransfer(caller : Principal, arg : T.TransferArg, now : Nat64, phash : ?Blob) : Value.Type {
		var tx = RBTree.empty<Text, Value.Type>();

		var map = RBTree.empty<Text, Value.Type>();
		map := Value.setNat(map, "ts", ?Nat64.toNat(now));
		map := Value.setText(map, "op", ?"add_credits");
		map := Value.setMap(map, "tx", tx);
		map := Value.setBlob(map, "phash", phash);
		#Map(RBTree.array(map));
	};

	public func valueApprove(caller : Principal, arg : T.ApproveArg, now : Nat64, phash : ?Blob) : Value.Type {
		var tx = RBTree.empty<Text, Value.Type>();

		var map = RBTree.empty<Text, Value.Type>();
		map := Value.setNat(map, "ts", ?Nat64.toNat(now));
		map := Value.setText(map, "op", ?"add_credits");
		map := Value.setMap(map, "tx", tx);
		map := Value.setBlob(map, "phash", phash);
		#Map(RBTree.array(map));
	};

	public func valueRevoke(caller : Principal, arg : T.RevokeArg, now : Nat64, phash : ?Blob) : Value.Type {
		var tx = RBTree.empty<Text, Value.Type>();

		var map = RBTree.empty<Text, Value.Type>();
		map := Value.setNat(map, "ts", ?Nat64.toNat(now));
		map := Value.setText(map, "op", ?"add_credits");
		map := Value.setMap(map, "tx", tx);
		map := Value.setBlob(map, "phash", phash);
		#Map(RBTree.array(map));
	};

	public func valueTransferFrom(caller : Principal, arg : T.TransferFromArg, now : Nat64, phash : ?Blob) : Value.Type {
		var tx = RBTree.empty<Text, Value.Type>();

		var map = RBTree.empty<Text, Value.Type>();
		map := Value.setNat(map, "ts", ?Nat64.toNat(now));
		map := Value.setText(map, "op", ?"add_credits");
		map := Value.setMap(map, "tx", tx);
		map := Value.setBlob(map, "phash", phash);
		#Map(RBTree.array(map));
	};

	public func validateName(t : Text) : Result.Type<(), Text> {
		var is_first = true;
		var last_underscore = false;

		label checking for (c in t.chars()) {
			for (x in T.CHARS.vals()) if (c == x) {
				is_first := false;
				last_underscore := false;
				continue checking;
			};
			if (is_first) {
				return #Err "First character must be small alphabets (a-z)";
			};
			for (x in T.NUMS.vals()) if (c == x) {
				last_underscore := false;
				continue checking;
			};
			if (c == '_') {
				if (last_underscore) {
					return #Err "Consecutive underscores are not allowed";
				};
				last_underscore := true;
				continue checking;
			};
			return #Err "Only small alphabets (a-z), numbers (0-9), and underscores (_) are allowed";
		};
		if (last_underscore) {
			return #Err "Name cannot end with an underscore";
		};
		#Ok;
	};
};
