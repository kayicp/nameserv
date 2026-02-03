import RBTree "../util/motoko/StableCollections/RedBlackTree/RBTree";
import T "type";
import L "lib";
import Result "../util/motoko/Result";
import Value "../util/motoko/Value";
import LEB128 "mo:leb128";
import MerkleTree "../util/motoko/MerkleTree";
import CertifiedData "mo:base/CertifiedData";
import ArchiveT "../util/motoko/Archive/Types";
import ArchiveL "../util/motoko/Archive";
import Archive "../util/motoko/Archive/Canister";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Nat64 "mo:base/Nat64";
import Error "../util/motoko/Error";
import ICRC3T "../util/motoko/ICRC-3/Types";
import Subaccount "../util/motoko/Subaccount";
import Cycles "mo:core/Cycles";
import Time64 "../util/motoko/Time64";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import OptionX "../util/motoko/Option";
import ICRC1L "../icrc1_canister/ICRC1";
import ICRC1T "../icrc1_canister/Types";
import Linker "linker";

shared (install) persistent actor class Canister(
  // deploy : {
  //   #Init : T.Environment;
  //   #Upgrade;
  // }
) = Self {
  var tip_cert = MerkleTree.empty();
  func updateTipCert() = CertifiedData.set(MerkleTree.treeHash(tip_cert));
  system func postupgrade() = updateTipCert(); // https://gist.github.com/nomeata/f32fcd2a6692df06e38adedf9ca1877

  var env = {
    available = true;
    memo_size = { min = 1; max = 32 };
    duration = {
      tx_window = Time64.HOURS(24);
      permitted_drift = Time64.MINUTES(2);
      proxy_validity = Time64.DAYS(30);
    };
    service_provider = install.caller;
    max_update_batch_size = 1;
    max_query_batch_size = 1;
    max_take_value = 1;
    name = {
      price_tiers = [
        { len = { min = 1; max = 1 }; fee_mult = 10_000_000 }, // 1000
        { len = { min = 2; max = 2 }; fee_mult = 5_000_000 }, // 500
        { len = { min = 3; max = 3 }; fee_mult = 1_000_000 }, // 100
        { len = { min = 4; max = 4 }; fee_mult = 500_000 }, // 50
        { len = { min = 5; max = 5 }; fee_mult = 250_000 }, // 25
        { len = { min = 6; max = 6 }; fee_mult = 100_000 }, // 10
        { len = { min = 7; max = 7 }; fee_mult = 50_000 }, // 5
        { len = { min = 8; max = 8 }; fee_mult = 20_000 }, // 2
        { len = { min = 9; max = 9 }; fee_mult = 10_000 }, // 1
        { len = { min = 10; max = 19 }; fee_mult = 5_000 }, // 0.5
        { len = { min = 20; max = 32 }; fee_mult = 2_000 }, // 0.2
      ];
      duration = {
        reduction = Time64.HOURS(12);
        renewable = Time64.DAYS(2);
        packages = [
          { yr = 1; mos_bonus = 2 },
          { yr = 3; mos_bonus = 12 },
          { yr = 5; mos_bonus = 24 },
        ];
      };

    };
    archive = {
      max_update_batch_size = 10;
      root = null;
      standby = null;
      min_tcycles = 4;
    };
  };
  // switch deploy {
  //   case (#Init i) updateTipCert(env := i);
  //   case _ ();
  // };

  var blocks = RBTree.empty<Nat, ArchiveT.Block>();
  var users = RBTree.empty<Principal, T.User>();
  var proxy_expiries = RBTree.empty<(Nat64, Principal, Blob), ()>();
  var spender_expiries = RBTree.empty<(Nat64, from : (Principal, Blob), spender : (Principal, Blob)), ()>();

  var names = RBTree.empty<Text, (Principal, Blob)>();
  var name_expiries = RBTree.empty<(Nat64, Text), ()>();

  var register_dedupes = RBTree.empty<(Principal, T.RegisterArg), Nat>();
  var approve_dedupes = RBTree.empty<(Principal, T.ApproveArg), Nat>();

  public shared ({ caller }) func accn_register(arg : T.RegisterArg) : async T.RegisterRes {
    let now = syncTrim();
    if (not env.available) return Error.text("Unavailable");
    let proxy_a = { owner = caller; subaccount = arg.proxy_subaccount };
    if (not ICRC1L.validateAccount(proxy_a)) return Error.text("Caller account is invalid");

    switch (checkMemo(arg.memo)) {
      case (#Err err) return #Err err;
      case _ ();
    };
    switch (arg.fee) {
      case (?defined) if (defined > 0) return #Err(#BadFee { expected_fee = 0 });
      case _ ();
    };
    let icp_p = Principal.fromText(ICRC1T.ICP_ID);
    let (icp, accl) = (actor (ICRC1T.ICP_ID) : ICRC1T.Canister, actor (Linker.ID) : Linker.Canister);
    let new_main_a = switch ((await accl.accountlink_main_accounts_of([proxy_a]))[0]) {
      case (?found) found;
      case _ return #Err(#UnproxiedCaller);
    };
    let accl_p = Principal.fromText(Linker.ID);
    let self_a = { owner = Principal.fromActor(Self); subaccount = null };
    let link_arg = { proxy = proxy_a; spender = self_a; token = icp_p };
    let (icp_fee_call, link_limit_call) = (icp.icrc1_fee(), accl.accountlink_icrc1_allowances_of([link_arg]));
    let (icp_fee, link) = (await icp_fee_call, (await link_limit_call)[0]);
    let amount_and_fee = arg.amount + icp_fee;
    if (link.allowance < amount_and_fee) return #Err(#InsufficientLinkAllowance link);
    switch (link.expires_at) {
      case (?found) if (found < now) return #Err(#InsufficientLinkAllowance { allowance = 0 });
      case _ ();
    };
    let (icp_bal_call, link_credit, icp_allow_call) = (icp.icrc1_balance_of(new_main_a), accl.accountlink_credits_of([new_main_a]), icp.icrc2_allowance({ account = new_main_a; spender = { owner = accl_p; subaccount = null } }));
    let (icp_bal, accl_credits, icp_aprv) = (await icp_bal_call, (await link_credit)[0], await icp_allow_call);
    if (accl_credits == 0) return #Err(#InsufficientLinkCredits);
    if (icp_bal < amount_and_fee) return #Err(#InsufficientTokenBalance { balance = icp_bal });
    if (icp_aprv.allowance < amount_and_fee) return #Err(#InsufficientTokenAllowance icp_aprv);
    switch (icp_aprv.expires_at) {
      case (?found) if (found < now) return #Err(#InsufficientTokenAllowance { allowance = 0 });
      case _ ();
    };
    var proxy_u = getUser(proxy_a.owner);
    let proxy_sub = Subaccount.get(proxy_a.subaccount);
    let (old_main_a, old_proxy_expiry) = switch (L.getRole(proxy_u, proxy_sub)) {
      case (#Main m_u) if (L.isMain(m_u)) return #Err(#UnknownProxy) else (new_main_a, 0 : Nat64);
      case (#Proxy old) old;
    };
    var main_u = getUser(new_main_a.owner);
    let main_sub = Subaccount.get(new_main_a.subaccount);
    var main = L.forceMain(L.getRole(main_u, main_sub));
    var locker = L.getOwner(main.spenders, self_a.owner);
    if (RBTree.size(locker) > 0) return #Err(#Locked);

    let (new_name, name_size, name_start) = switch (arg.name) {
      case (?defined) {
        let name_size = Text.size(defined);
        if (name_size == 0) return Error.text("Name must not be empty");
        let maximum_length = env.name.price_tiers[env.name.price_tiers.size() - 1].len.max;
        if (name_size > maximum_length) return #Err(#NameTooLong { maximum_length });
        let start_expiry = if (defined == main.name) {
          // todo: time extension, no validation
          Nat64.max(now, main.expires_at);
        } else {
          if (main.expires_at > now) return #Err(#NamedAccount main);
          // todo: validate
          switch (RBTree.get(names, Text.compare, defined)) {
            case (?(name_p, name_sub)) if (name_p != new_main_a.owner or name_sub != main_sub) return #Err(#ReservedName { main = { owner = name_p; subaccount = Subaccount.opt(name_sub) } });
            case _ ();
          };
          now; // name belongs to caller, or no one
        };
        (defined, name_size, start_expiry);
      };
      case _ {
        let name_size = Text.size(main.name);
        if (name_size == 0) return #Err(#UnnamedAccount);
        (main.name, name_size, Nat64.max(now, main.expires_at)); // time extension
      };
    };
    var fee_base = 0;
    label sizing for (tier in env.name.price_tiers.vals()) if (name_size >= tier.len.min and name_size <= tier.len.max) {
      fee_base := tier.fee_mult * icp_fee;
      break sizing;
    };
    if (fee_base == 0) return Error.text("No price tiers for the length of the name");
    var selected_package = { yr = 0; mos_bonus = 0; total = 0 };
    label timing for (package in env.name.duration.packages.vals()) {
      let total = package.yr * fee_base;
      if (arg.amount == total) {
        selected_package := { package with total };
        break timing;
      };
    };
    if (selected_package.total == 0) return Error.text("No duration package fits the payment amount");
    let new_name_expiry = name_start + Time64.DAYS(Nat64.fromNat(selected_package.yr * 365)) + Time64.DAYS(Nat64.fromNat(selected_package.mos_bonus * 30));

    switch (checkIdempotency(caller, #Register arg, arg.created_at, now)) {
      case (#Err err) return #Err err;
      case _ ();
    };
    let (old_name, old_name_expiry) = (main.name, main.expires_at);
    let self_sub = Subaccount.get(self_a.subaccount);
    locker := RBTree.insert(locker, Blob.compare, self_sub, null);
    var spenders = L.saveOwner(main.spenders, self_a.owner, locker);
    main := { main with spenders };
    main := { main with name = new_name };
    main := { main with expires_at = new_name_expiry };

    func save<T>(ret : T) : T {
      main_u := L.saveRole(main_u, main_sub, #Main main);
      saveUser(new_main_a.owner, main_u, ret);
    };
    save(); // lock main

    names := RBTree.insert(names, Text.compare, new_name, (new_main_a.owner, main_sub)); // lock name

    proxy_u := getUser(proxy_a.owner);
    proxy_u := L.saveRole(proxy_u, proxy_sub, #Proxy(new_main_a, 1));
    saveUser(proxy_a.owner, proxy_u, ()); // lock proxy

    func unlock<T>(ret : T) : T {
      proxy_u := getUser(proxy_a.owner);
      proxy_u := L.saveRole(proxy_u, proxy_sub, #Proxy(old_main_a, old_proxy_expiry));
      saveUser(proxy_a.owner, proxy_u, ());

      if (Text.size(old_name) == 0) names := RBTree.delete(names, Text.compare, new_name);

      main_u := getUser(new_main_a.owner);
      main := L.forceMain(L.getRole(main_u, main_sub));
      locker := L.getOwner(main.spenders, self_a.owner);
      locker := RBTree.delete(locker, Blob.compare, self_sub);
      spenders := L.saveOwner(main.spenders, self_a.owner, locker);
      main := { main with spenders };
      main := { main with name = old_name };
      main := { main with expires_at = old_name_expiry };
      ret;
    };
    let pay_arg = {
      spender_subaccount = null;
      token = icp_p;
      proxy = proxy_a;
      amount = arg.amount;
      to = { owner = env.service_provider; subaccount = null };
      memo = null;
      created_at = null;
    };
    let pay_res = try await accl.accountlink_icrc1_transfer_from(pay_arg) catch (e) return save(unlock(#Err(Error.convert(e))));
    let pay_id = switch (unlock(pay_res)) {
      case (#Ok ok) ok;
      case (#Err err) return save(#Err(#FailedTransfer err));
    };
    main := { main with name = new_name };
    main := { main with expires_at = new_name_expiry };
    save(); // confirm main

    names := RBTree.insert(names, Text.compare, new_name, (new_main_a.owner, main_sub)); // confirm name
    name_expiries := RBTree.delete(name_expiries, L.compareNameExpiry, (old_name_expiry, old_name));
    name_expiries := RBTree.insert(name_expiries, L.compareNameExpiry, (new_name_expiry, new_name), ());

    let new_proxy_expiry = now + env.duration.proxy_validity;
    proxy_u := getUser(proxy_a.owner);
    proxy_u := L.saveRole(proxy_u, proxy_sub, #Proxy(new_main_a, new_proxy_expiry));
    saveUser(proxy_a.owner, proxy_u, ()); // confirm proxy

    proxy_expiries := RBTree.delete(proxy_expiries, L.compareProxyExpiry, (old_proxy_expiry, proxy_a.owner, proxy_sub));
    proxy_expiries := RBTree.insert(proxy_expiries, L.compareProxyExpiry, (new_proxy_expiry, proxy_a.owner, proxy_sub), ());

    let (block_id, phash) = ArchiveL.getPhash(blocks);
    if (arg.created_at != null) register_dedupes := RBTree.insert(register_dedupes, L.dedupeRegister, (caller, arg), block_id);
    // newBlock(block_id, L.valueDeposit(caller, sub, arg, depo_id, now, phash)); // todo: all value*() must store proxy and main?

    // ignore await* sendBlock();
    #Ok block_id;
  };

  public shared ({ caller }) func accn_transfer(args : [T.TransferArg]) : async [T.TransferRes] {
    let now = syncTrim();
    if (args.size() == 0) return [];
    if (not env.available) return [Error.text("Unavailable")];
    let arg = args[0];
    let proxy_a = { owner = caller; subaccount = arg.proxy_subaccount };
    if (not ICRC1L.validateAccount(proxy_a)) return [Error.text("Caller account is invalid")];
    if (not ICRC1L.validateAccount(arg.to)) return [Error.text("Recipient account is invalid")];

    switch (checkMemo(arg.memo)) {
      case (#Err err) return [#Err err];
      case _ ();
    };
    var proxy_u = getUser(proxy_a.owner);
    let proxy_sub = Subaccount.get(proxy_a.subaccount);
    let (from_a, old_proxy_expiry) = switch (L.getRole(proxy_u, proxy_sub)) {
      case (#Proxy found) found;
      case (#Main _) return [#Err(#UnknownProxy)];
    };
    var from_u = getUser(from_a.owner);
    let from_sub = Subaccount.get(from_a.subaccount);
    var from_main = switch (L.getRole(from_u, from_sub)) {
      case (#Main found) found;
      case (#Proxy(main, _)) return [#Err(#SenderIsProxy { main })];
    };
    if (Text.size(from_main.name) == 0 or from_main.expires_at < now) return [#Err(#UnnamedSender)];
    let (self_p, self_sub) = (Principal.fromActor(Self), Subaccount.get(null));

    let remaining = from_main.expires_at - now;
    if (remaining < env.name.duration.reduction) return [#Err(#InsufficientDuration { remaining })];

    var from_locker = L.getOwner(from_main.spenders, self_p);
    if (RBTree.size(from_locker) > 0) return [#Err(#LockedSender)];
    switch (arg.expiry_reduction) {
      case (?defined) if (defined != env.name.duration.reduction) return [#Err(#BadExpiryReduction { expected_expiry_reduction = env.name.duration.reduction })];
      case _ ();
    };
    var to_u = getUser(arg.to.owner);
    let to_sub = Subaccount.get(arg.to.subaccount);
    if (from_a.owner == arg.to.owner and from_sub == to_sub) return [Error.text("Self-transfer is not allowed")];
    if (proxy_a.owner == arg.to.owner and proxy_sub == to_sub) return [Error.text("Proxy cannot receive")];

    var to_main = switch (L.getRole(to_u, to_sub)) {
      case (#Main found) found;
      case (#Proxy(main, _)) return [#Err(#RecipientIsProxy { main })];
    };
    if (Text.size(to_main.name) > 0 and to_main.expires_at > now) return [#Err(#NamedRecipient to_main)];
    var to_locker = L.getOwner(to_main.spenders, self_p);
    if (RBTree.size(to_locker) > 0) return [#Err(#LockedRecipient)];

    to_main := { to_main with name = from_main.name };
    to_main := {
      to_main with expires_at = from_main.expires_at - env.name.duration.reduction
    };
    to_u := L.saveRole(to_u, to_sub, #Main to_main);
    saveUser(arg.to.owner, to_u, ());

    names := RBTree.insert(names, Text.compare, to_main.name, (arg.to.owner, to_sub));
    name_expiries := RBTree.delete(name_expiries, L.compareNameExpiry, (from_main.expires_at, from_main.name));
    name_expiries := RBTree.insert(name_expiries, L.compareNameExpiry, (to_main.expires_at, to_main.name), ());

    from_u := getUser(from_a.owner);
    from_main := L.forceMain(L.getRole(from_u, from_sub));
    from_main := { from_main with name = "" };
    from_main := { from_main with expires_at = 0 };
    from_u := L.saveRole(from_u, from_sub, #Main from_main);
    saveUser(from_a.owner, from_u, ());

    let new_proxy_expiry = now + env.duration.proxy_validity;
    proxy_u := getUser(proxy_a.owner);
    proxy_u := L.saveRole(proxy_u, proxy_sub, #Proxy(from_a, new_proxy_expiry));
    saveUser(proxy_a.owner, proxy_u, ()); // confirm proxy

    proxy_expiries := RBTree.delete(proxy_expiries, L.compareProxyExpiry, (old_proxy_expiry, proxy_a.owner, proxy_sub));
    proxy_expiries := RBTree.insert(proxy_expiries, L.compareProxyExpiry, (new_proxy_expiry, proxy_a.owner, proxy_sub), ());

    let (block_id, phash) = ArchiveL.getPhash(blocks);
    // newBlock(block_id, L.valueDeposit(caller, sub, arg, depo_id, now, phash)); // todo: all value*() must store proxy and main?

    // ignore await* sendBlock();
    [#Ok block_id];
  };

  public shared ({ caller }) func accn_approve(args : [T.ApproveArg]) : async [T.ApproveRes] {
    let now = syncTrim();
    if (args.size() == 0) return [];
    if (not env.available) return [Error.text("Unavailable")];
    let arg = args[0];
    let proxy_a = { owner = caller; subaccount = arg.proxy_subaccount };
    if (not ICRC1L.validateAccount(proxy_a)) return [Error.text("Caller account is invalid")];
    if (not ICRC1L.validateAccount(arg.spender)) return [Error.text("Manager account is invalid")];
    let (self_p, self_sub) = (Principal.fromActor(Self), Subaccount.get(null));
    if (arg.spender.owner == self_p) return [Error.text("Cannot approve this canister")];

    switch (checkMemo(arg.memo)) {
      case (#Err err) return [#Err err];
      case _ ();
    };
    var proxy_u = getUser(proxy_a.owner);
    let proxy_sub = Subaccount.get(proxy_a.subaccount);
    let (from_a, old_proxy_expiry) = switch (L.getRole(proxy_u, proxy_sub)) {
      case (#Proxy found) found;
      case (#Main _) return [#Err(#UnknownProxy)];
    };
    var from_u = getUser(from_a.owner);
    let from_sub = Subaccount.get(from_a.subaccount);
    let spender_sub = Subaccount.get(arg.spender.subaccount);
    if (from_a.owner == arg.spender.owner and from_sub == spender_sub) return [Error.text("Self-approve is not allowed")];
    if (proxy_a.owner == arg.spender.owner and proxy_sub == spender_sub) return [Error.text("Proxy cannot be a spender")];

    var from_main = switch (L.getRole(from_u, from_sub)) {
      case (#Main found) found;
      case (#Proxy(main, _)) return [#Err(#SenderIsProxy { main })];
    };
    if (Text.size(from_main.name) == 0 or from_main.expires_at < now) return [#Err(#Unnamed)];

    let remaining = from_main.expires_at - now;
    if (remaining < env.name.duration.reduction) return [#Err(#InsufficientDuration { remaining })];

    let from_locker = L.getOwner(from_main.spenders, self_p);
    if (RBTree.size(from_locker) > 0) return [#Err(#Locked)];
    switch (arg.expiry_reduction) {
      case (?defined) if (defined != env.name.duration.reduction) return [#Err(#BadExpiryReduction { expected_expiry_reduction = env.name.duration.reduction })];
      case _ ();
    };
    switch (arg.expires_at) {
      case (?defined) if (defined < now) return [#Err(#Expired { time = now })];
      case _ ();
    };
    switch (checkIdempotency(caller, #Approve arg, arg.created_at, now)) {
      case (#Err err) return [#Err err];
      case _ ();
    };
    var from_spender = L.getOwner(from_main.spenders, arg.spender.owner);
    let old_spender_expiry = Option.get(RBTree.get(from_spender, Blob.compare, spender_sub), null);
    from_spender := RBTree.insert(from_spender, Blob.compare, spender_sub, arg.expires_at);
    let spenders = L.saveOwner(from_main.spenders, arg.spender.owner, from_spender);
    from_main := { from_main with spenders };

    let old_name_expiry = from_main.expires_at;
    let new_name_expiry = from_main.expires_at - env.name.duration.reduction;
    from_main := { from_main with expires_at = new_name_expiry };
    from_u := L.saveRole(from_u, from_sub, #Main from_main);
    saveUser(from_a.owner, from_u, ());

    switch old_spender_expiry {
      case (?found) spender_expiries := RBTree.delete(spender_expiries, L.compareManagerExpiry, (found, (from_a.owner, from_sub), (arg.spender.owner, spender_sub)));
      case _ ();
    };
    switch (arg.expires_at) {
      case (?found) spender_expiries := RBTree.insert(spender_expiries, L.compareManagerExpiry, (found, (from_a.owner, from_sub), (arg.spender.owner, spender_sub)), ());
      case _ ();
    };
    name_expiries := RBTree.delete(name_expiries, L.compareNameExpiry, (old_name_expiry, from_main.name));
    name_expiries := RBTree.insert(name_expiries, L.compareNameExpiry, (new_name_expiry, from_main.name), ());

    let new_proxy_expiry = now + env.duration.proxy_validity;
    proxy_u := getUser(proxy_a.owner);
    proxy_u := L.saveRole(proxy_u, proxy_sub, #Proxy(from_a, new_proxy_expiry));
    saveUser(proxy_a.owner, proxy_u, ()); // confirm proxy

    proxy_expiries := RBTree.delete(proxy_expiries, L.compareProxyExpiry, (old_proxy_expiry, proxy_a.owner, proxy_sub));
    proxy_expiries := RBTree.insert(proxy_expiries, L.compareProxyExpiry, (new_proxy_expiry, proxy_a.owner, proxy_sub), ());

    let (block_id, phash) = ArchiveL.getPhash(blocks);
    if (arg.created_at != null) approve_dedupes := RBTree.insert(approve_dedupes, L.dedupeApprove, (caller, arg), block_id);
    // newBlock(block_id, L.valueDeposit(caller, sub, arg, depo_id, now, phash)); // todo: all value*() must store proxy and main?

    // ignore await* sendBlock();
    [#Ok block_id];
  };

  public shared ({ caller }) func accn_revoke(args : [T.RevokeArg]) : async [T.RevokeRes] {
    let now = syncTrim();
    if (args.size() == 0) return [];
    if (not env.available) return [Error.text("Unavailable")];
    let arg = args[0];
    let proxy_a = { owner = caller; subaccount = arg.proxy_subaccount };
    if (not ICRC1L.validateAccount(proxy_a)) return [Error.text("Caller account is invalid")];
    if (not ICRC1L.validateAccount(arg.spender)) return [Error.text("Manager account is invalid")];
    let (self_p, self_sub) = (Principal.fromActor(Self), Subaccount.get(null));
    if (arg.spender.owner == self_p) return [Error.text("Cannot revoke this canister")];

    switch (checkMemo(arg.memo)) {
      case (#Err err) return [#Err err];
      case _ ();
    };
    var proxy_u = getUser(proxy_a.owner);
    let proxy_sub = Subaccount.get(proxy_a.subaccount);
    let (from_a, old_proxy_expiry) = switch (L.getRole(proxy_u, proxy_sub)) {
      case (#Proxy found) found;
      case (#Main _) return [#Err(#UnknownProxy)];
    };
    var from_u = getUser(from_a.owner);
    let from_sub = Subaccount.get(from_a.subaccount);
    var from_main = switch (L.getRole(from_u, from_sub)) {
      case (#Main found) found;
      case (#Proxy(main, _)) return [#Err(#SenderIsProxy { main })];
    };
    if (Text.size(from_main.name) == 0 or from_main.expires_at < now) return [#Err(#Unnamed)];

    let remaining = from_main.expires_at - now;
    if (remaining < env.name.duration.reduction) return [#Err(#InsufficientDuration { remaining })];

    let from_locker = L.getOwner(from_main.spenders, self_p);
    if (RBTree.size(from_locker) > 0) return [#Err(#Locked)];
    switch (arg.expiry_reduction) {
      case (?defined) if (defined != env.name.duration.reduction) return [#Err(#BadExpiryReduction { expected_expiry_reduction = env.name.duration.reduction })];
      case _ ();
    };
    var from_spender = L.getOwner(from_main.spenders, arg.spender.owner);
    let spender_sub = Subaccount.get(arg.spender.subaccount);
    let old_spender_expiry = switch (RBTree.get(from_spender, Blob.compare, spender_sub)) {
      case (?found) found;
      case _ return [#Err(#UnknownSpender)];
    };
    from_spender := RBTree.delete(from_spender, Blob.compare, spender_sub);
    let spenders = L.saveOwner(from_main.spenders, arg.spender.owner, from_spender);
    from_main := { from_main with spenders };

    let old_name_expiry = from_main.expires_at;
    let new_name_expiry = from_main.expires_at - env.name.duration.reduction;
    from_main := { from_main with expires_at = new_name_expiry };
    from_u := L.saveRole(from_u, from_sub, #Main from_main);
    saveUser(from_a.owner, from_u, ());

    switch old_spender_expiry {
      case (?found) spender_expiries := RBTree.delete(spender_expiries, L.compareManagerExpiry, (found, (from_a.owner, from_sub), (arg.spender.owner, spender_sub)));
      case _ ();
    };
    name_expiries := RBTree.delete(name_expiries, L.compareNameExpiry, (old_name_expiry, from_main.name));
    name_expiries := RBTree.insert(name_expiries, L.compareNameExpiry, (new_name_expiry, from_main.name), ());

    let new_proxy_expiry = now + env.duration.proxy_validity;
    proxy_u := getUser(proxy_a.owner);
    proxy_u := L.saveRole(proxy_u, proxy_sub, #Proxy(from_a, new_proxy_expiry));
    saveUser(proxy_a.owner, proxy_u, ()); // confirm proxy

    proxy_expiries := RBTree.delete(proxy_expiries, L.compareProxyExpiry, (old_proxy_expiry, proxy_a.owner, proxy_sub));
    proxy_expiries := RBTree.insert(proxy_expiries, L.compareProxyExpiry, (new_proxy_expiry, proxy_a.owner, proxy_sub), ());

    let (block_id, phash) = ArchiveL.getPhash(blocks);
    // newBlock(block_id, L.valueDeposit(caller, sub, arg, depo_id, now, phash)); // todo: all value*() must store proxy and main?

    // ignore await* sendBlock();
    [#Ok block_id];
  };

  public shared ({ caller }) func accn_transfer_from(args : [T.TransferFromArg]) : async [T.TransferFromRes] {
    let now = syncTrim();
    if (args.size() == 0) return [];
    if (not env.available) return [Error.text("Unavailable")];
    let arg = args[0];
    let spender_a = { owner = caller; subaccount = arg.spender_subaccount };
    if (not ICRC1L.validateAccount(spender_a)) return [Error.text("Caller account is invalid")];
    if (not ICRC1L.validateAccount(arg.proxy)) return [Error.text("Proxy account is invalid")];
    if (not ICRC1L.validateAccount(arg.to)) return [Error.text("Recipient account is invalid")];

    let spender_sub = Subaccount.get(spender_a.subaccount);
    let proxy_sub = Subaccount.get(arg.proxy.subaccount);
    if (arg.proxy.owner == spender_a.owner and proxy_sub == spender_sub) return [Error.text("Caller cannot spend")];
    let to_sub = Subaccount.get(arg.to.subaccount);
    if (arg.proxy.owner == arg.to.owner and proxy_sub == to_sub) return [Error.text("Proxy cannot receive")];

    switch (checkMemo(arg.memo)) {
      case (#Err err) return [#Err err];
      case _ ();
    };
    var proxy_u = getUser(arg.proxy.owner);
    let (from_a, old_proxy_expiry) = switch (L.getRole(proxy_u, proxy_sub)) {
      case (#Proxy found) found;
      case (#Main _) return [#Err(#UnknownProxy)];
    };
    let from_sub = Subaccount.get(from_a.subaccount);
    if (from_a.owner == spender_a.owner and from_sub == spender_sub) return [Error.text("Caller cannot send")];
    if (from_a.owner == arg.to.owner and from_sub == to_sub) return [Error.text("Self-transfer is not allowed")];

    var from_u = getUser(from_a.owner);
    var from_main = switch (L.getRole(from_u, from_sub)) {
      case (#Main found) found;
      case (#Proxy(main, _)) return [#Err(#SenderIsProxy { main })];
    };
    if (Text.size(from_main.name) == 0 or from_main.expires_at < now) return [#Err(#UnnamedSender)];
    let (self_p, self_sub) = (Principal.fromActor(Self), Subaccount.get(null));

    let remaining = from_main.expires_at - now;
    if (remaining < env.name.duration.reduction) return [#Err(#InsufficientDuration { remaining })];

    let from_locker = L.getOwner(from_main.spenders, self_p);
    if (RBTree.size(from_locker) > 0) return [#Err(#LockedSender)];
    switch (arg.expiry_reduction) {
      case (?defined) if (defined != env.name.duration.reduction) return [#Err(#BadExpiryReduction { expected_expiry_reduction = env.name.duration.reduction })];
      case _ ();
    };
    var from_spender = L.getOwner(from_main.spenders, spender_a.owner);
    let approval_expiry = switch (RBTree.get(from_spender, Blob.compare, spender_sub)) {
      case (?found) found;
      case _ return [#Err(#UnknownSpender)];
    };
    switch approval_expiry {
      case (?found) if (found < now) return [#Err(#UnknownSpender)];
      case _ ();
    };
    var to_u = getUser(arg.to.owner);
    var to_main = switch (L.getRole(to_u, to_sub)) {
      case (#Main found) found;
      case (#Proxy(main, _)) return [#Err(#RecipientIsProxy { main })];
    };
    if (Text.size(to_main.name) > 0 and to_main.expires_at > now) return [#Err(#NamedRecipient to_main)];
    var to_locker = L.getOwner(to_main.spenders, self_p);
    if (RBTree.size(to_locker) > 0) return [#Err(#LockedRecipient)];

    to_main := { to_main with name = from_main.name };
    to_main := {
      to_main with expires_at = from_main.expires_at - env.name.duration.reduction
    };
    to_u := L.saveRole(to_u, to_sub, #Main to_main);
    saveUser(arg.to.owner, to_u, ());

    names := RBTree.insert(names, Text.compare, to_main.name, (arg.to.owner, to_sub));
    name_expiries := RBTree.delete(name_expiries, L.compareNameExpiry, (from_main.expires_at, from_main.name));
    name_expiries := RBTree.insert(name_expiries, L.compareNameExpiry, (to_main.expires_at, to_main.name), ());

    from_u := getUser(from_a.owner);
    from_main := L.forceMain(L.getRole(from_u, from_sub));
    from_main := { from_main with name = "" };
    from_main := { from_main with expires_at = 0 };
    from_spender := RBTree.delete(from_spender, Blob.compare, spender_sub);
    let spenders = L.saveOwner(from_main.spenders, spender_a.owner, from_spender);
    from_main := { from_main with spenders };
    from_u := L.saveRole(from_u, from_sub, #Main from_main);
    saveUser(from_a.owner, from_u, ());

    switch approval_expiry {
      case (?found) spender_expiries := RBTree.delete(spender_expiries, L.compareManagerExpiry, (found, (from_a.owner, from_sub), (spender_a.owner, spender_sub)));
      case _ ();
    };
    let (block_id, phash) = ArchiveL.getPhash(blocks);
    // newBlock(block_id, L.valueDeposit(caller, sub, arg, depo_id, now, phash)); // todo: all value*() must store proxy and main?

    // ignore await* sendBlock();
    [#Ok block_id];
  };

  // todo: replace error texts to variants regarding main/proxy

  func getUser(p : Principal) : T.User = switch (RBTree.get(users, Principal.compare, p)) {
    case (?found) found;
    case _ RBTree.empty();
  };
  func saveUser<Return>(p : Principal, u : T.User, r : Return) : Return {
    users := if (RBTree.size(u) > 0) RBTree.insert(users, Principal.compare, p, u) else RBTree.delete(users, Principal.compare, p);
    r;
  };

  func newBlock(block_id : Nat, val : Value.Type) {
    let valh = Value.hash(val);
    let idh = Blob.fromArray(LEB128.toUnsignedBytes(block_id));
    blocks := RBTree.insert(blocks, Nat.compare, block_id, { val; valh; idh; locked = false });

    tip_cert := MerkleTree.empty();
    tip_cert := MerkleTree.put(tip_cert, [Text.encodeUtf8(ICRC3T.LAST_BLOCK_INDEX)], idh);
    tip_cert := MerkleTree.put(tip_cert, [Text.encodeUtf8(ICRC3T.LAST_BLOCK_HASH)], valh);
    updateTipCert();
  };

  func checkMemo(m : ?Blob) : Result.Type<(), Error.Generic> = switch m {
    case (?defined) {
      if (defined.size() < env.memo_size.min) return Error.text("Memo size must be larger than " # debug_show env.memo_size.min);
      if (defined.size() > env.memo_size.max) return Error.text("Memo size must be smaller than " # debug_show env.memo_size.max);
      #Ok;
    };
    case _ #Ok;
  };
  func checkIdempotency(caller : Principal, opr : T.ArgType, created_at : ?Nat64, now : Nat64) : Result.Type<(), { #CreatedInFuture : { time : Nat64 }; #TooOld; #Duplicate : { of : Nat } }> {
    let ct = switch created_at {
      case (?defined) defined;
      case _ return #Ok;
    };
    let start_time = now - env.duration.tx_window - env.duration.permitted_drift;
    if (ct < start_time) return #Err(#TooOld);
    let end_time = now + env.duration.permitted_drift;
    if (ct > end_time) return #Err(#CreatedInFuture { time = now });
    let find_dupe = switch opr {
      case (#Register arg) RBTree.get(register_dedupes, L.dedupeRegister, (caller, arg));
      case (#Approve arg) RBTree.get(approve_dedupes, L.dedupeApprove, (caller, arg));
    };
    switch find_dupe {
      case (?of) #Err(#Duplicate { of });
      case _ #Ok;
    };
  };
  func syncTrim() : Nat64 {
    let now = Time64.nanos();
    now;
  };
};
