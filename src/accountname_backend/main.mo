import RBTree "../util/motoko/StableCollections/RedBlackTree/RBTree";
import Queue "../util/motoko/StableCollections/Queue";
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
import CMC "../util/motoko/CMC/types";

shared (install) persistent actor class Canister(
  deploy : {
    #Init : T.Environment;
    #Upgrade;
  }
) = Self {
  var tip_cert = MerkleTree.empty();
  func updateTipCert() = CertifiedData.set(MerkleTree.treeHash(tip_cert));
  system func postupgrade() = updateTipCert(); // https://gist.github.com/nomeata/f32fcd2a6692df06e38adedf9ca1877

  var env : T.Environment = {
    memo_size = { min = 1; max = 32 };
    duration = {
      tx_window = Time64.HOURS(24);
      permitted_drift = Time64.MINUTES(2);
    };
    service_provider = install.caller;
    cmc = ?CMC.ID;
    max_update_batch_size = 1;
    max_query_batch_size = 1;
    max_take_value = 1;
    name = {
      price_tiers = [
        { length = { min = 1; max = 1 }; tcycles_fee_multiplier = 10_000_000 }, // 1000
        { length = { min = 2; max = 2 }; tcycles_fee_multiplier = 5_000_000 }, // 500
        { length = { min = 3; max = 3 }; tcycles_fee_multiplier = 2_500_000 }, // 250
        { length = { min = 4; max = 4 }; tcycles_fee_multiplier = 1_000_000 }, // 100
        { length = { min = 5; max = 5 }; tcycles_fee_multiplier = 500_000 }, // 50
        { length = { min = 6; max = 6 }; tcycles_fee_multiplier = 250_000 }, // 25
        { length = { min = 7; max = 7 }; tcycles_fee_multiplier = 100_000 }, // 10
        { length = { min = 8; max = 8 }; tcycles_fee_multiplier = 50_000 }, // 5
        { length = { min = 9; max = 9 }; tcycles_fee_multiplier = 20_000 }, // 2
        { length = { min = 10; max = 19 }; tcycles_fee_multiplier = 10_000 }, // 1
        { length = { min = 20; max = 32 }; tcycles_fee_multiplier = 5_000 }, // 0.5 TCYCLES
      ];
      duration = {
        max_expiry = Time64.DAYS(30);
        toll = Time64.HOURS(2);
        lock = Time64.SECONDS(20);
        packages = [
          { years_base = 1; months_bonus = 2 },
          { years_base = 3; months_bonus = 12 },
          { years_base = 5; months_bonus = 36 },
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
  switch deploy {
    case (#Init i) updateTipCert(env := i);
    case _ ();
  };
  var blocks = RBTree.empty<Nat, ArchiveT.Block>();
  var users = RBTree.empty<Principal, T.User>();
  var proxies = RBTree.empty<Principal, T.Proxy>();
  var proxy_expiries = RBTree.empty<(Nat64, Principal, Blob), ()>();
  var operator_expiries = RBTree.empty<(Nat64, from : (Principal, Blob), operator : (Principal, Blob)), ()>();

  var names = RBTree.empty<Text, (Principal, Blob)>();
  var name_expiries = RBTree.empty<(Nat64, Text), ()>();

  var register_dedupes = RBTree.empty<(Principal, T.RegisterArg), Nat>();
  var approve_dedupes = RBTree.empty<(Principal, T.ApproveArg), Nat>();

  public shared query func iiname_service_provider() : async ICRC1T.Account = async ({
    owner = env.service_provider;
    subaccount = null;
  });

  public shared query func iiname_price_tiers() : async [{
    length : { min : Nat; max : Nat };
    tcycles_fee_multiplier : Nat;
  }] = async env.name.price_tiers;

  public shared query func iiname_duration_packages() : async [{
    years_base : Nat;
    months_bonus : Nat;
  }] = async env.name.duration.packages;

  public shared ({ caller }) func iiname_register(arg : T.RegisterArg) : async T.RegisterRes {
    let now = syncTrim();
    let proxy_a = { owner = caller; subaccount = arg.proxy_subaccount };
    if (not ICRC1L.validateAccount(proxy_a)) return Error.text("Caller account is invalid");

    switch (checkMemo(arg.memo)) {
      case (#Err err) return #Err err;
      case _ ();
    };
    let token_text = Principal.toText(arg.token);
    let is_icp = token_text == ICRC1T.ICP_ID;
    if (not is_icp and token_text != ICRC1T.TCYCLES_ID) return Error.text("Unsupported token; Only ICP (" # ICRC1T.ICP_ID # ") and TCYCLES (" # ICRC1T.TCYCLES_ID # ") are allowed");

    let self_a = { owner = Principal.fromActor(Self); subaccount = null };
    let (icp_token, tcycles_token) = (actor (ICRC1T.ICP_ID) : ICRC1T.Canister, actor (ICRC1T.TCYCLES_ID) : ICRC1T.Canister);
    let icp_xdr_call = switch (env.cmc) {
      case (?p_txt) {
        let cmc = actor (p_txt) : CMC.Self;
        cmc.get_icp_xdr_conversion_rate();
      };
      case _ async ({
        certificate = "" : Blob;
        data = {
          xdr_permyriad_per_icp = 10_000 : Nat64;
          timestamp_seconds = now / Time64.SECONDS(1);
        };
        hash_tree = "" : Blob;
      });
    };
    let (icp_fee_call, tcycles_fee_call) = (icp_token.icrc1_fee(), tcycles_token.icrc1_fee());
    let (icp_xdr, icp_fee, tcycles_fee) = (await icp_xdr_call, await icp_fee_call, await tcycles_fee_call);

    let name_len = Text.size(arg.name);
    if (name_len == 0) return Error.text("Name must not be empty");
    let maximum_length = env.name.price_tiers[env.name.price_tiers.size() - 1].length.max;
    if (name_len > maximum_length) return #Err(#NameTooLong { maximum_length });
    switch (L.validateName(arg.name)) {
      case (#Err err) return Error.text(err);
      case _ ();
    };
    var fee_base = 0;
    label sizing for (tier in env.name.price_tiers.vals()) if (name_len >= tier.length.min and name_len <= tier.length.max) {
      fee_base := tier.tcycles_fee_multiplier * tcycles_fee;
      break sizing;
    };
    if (fee_base == 0) return #Err(#UnknownLengthTier);
    var selected_package = { years_base = 0; months_bonus = 0; total = 0 };
    let xdr_permyriad_per_icp = Nat64.toNat(icp_xdr.data.xdr_permyriad_per_icp);
    label timing for (package in env.name.duration.packages.vals()) {
      let total_tcycles = package.years_base * fee_base;
      // icp = (cycles * icp_decimals * per_myriad) / (1T per XDR * xdr_permyriad_per_icp)
      let total = if (is_icp) (total_tcycles * 100_000_000 * 10_000) / (1_000_000_000_000 * xdr_permyriad_per_icp) else total_tcycles;
      if (arg.amount == total) {
        selected_package := { package with total };
        break timing;
      };
    };
    if (selected_package.total == 0) return #Err(#UnknownDurationPackage { xdr_permyriad_per_icp });

    let (token_can, token_fee) = if (is_icp) (icp_token, icp_fee) else (tcycles_token, tcycles_fee);
    let xfer_and_fee = arg.amount + token_fee;
    let linker = actor (Linker.ID) : Linker.Canister;
    let (main_a, main_sub) = switch (arg.main) {
      case (?main_a) {
        let links_call = linker.iilink_icrc1_allowances([{
          arg with main = main_a;
          proxy = proxy_a;
          spender = self_a;
        }]);
        let (token_bal_call, token_aprv_call) = (token_can.icrc1_balance_of(main_a), token_can.icrc2_allowance({ account = main_a; spender = self_a }));
        let (link, token_bal, token_aprv) = ((await links_call).results[0], await token_bal_call, await token_aprv_call);
        if (link.allowance < xfer_and_fee) return #Err(#InsufficientLinkAllowance link);
        if (link.expires_at < now) return #Err(#InsufficientLinkAllowance { allowance = 0 });
        if (token_bal < xfer_and_fee) return #Err(#InsufficientTokenBalance { balance = token_bal });
        if (token_aprv.allowance < xfer_and_fee) return #Err(#InsufficientTokenAllowance token_aprv);
        switch (token_aprv.expires_at) {
          case (?found) if (found < now) return #Err(#InsufficientTokenAllowance { allowance = 0 });
          case _ ();
        };
        (main_a, Subaccount.get(main_a.subaccount));
      };
      case _ {
        let links = await linker.iilink_icrc1_sufficient_allowances({
          arg with proxy = proxy_a;
          spender = self_a;
          allowance = xfer_and_fee;
          previous = null;
          take = null;
        });
        var calls = Queue.empty<(Linker.FilteredAllowance, Blob, async Nat, async ICRC1T.Allowance)>();
        var maximum_allowance = { available = 0; main = null : ?ICRC1T.Account };
        for (filtered in links.results.vals()) {
          if (filtered.allowance > maximum_allowance.available) maximum_allowance := {
            available = filtered.allowance;
            main = ?filtered.main;
          };
          let main_sub = Subaccount.get(filtered.main.subaccount);
          calls := Queue.insertHead(calls, (filtered, main_sub, token_can.icrc1_balance_of(filtered.main), token_can.icrc2_allowance({ account = filtered.main; spender = self_a })));
        };
        let total_calls = Queue.size(calls);
        if (total_calls == 0) return #Err(#NoSufficientLinkAllowance { total = links.results.size(); maximum = maximum_allowance });

        var maximum_balance = { available = 0; main = null : ?ICRC1T.Account };
        maximum_allowance := maximum_balance;
        var allowances = RBTree.empty<Nat, T.Accounts<ICRC1T.Account>>();
        label calling for ((filtered, main_sub, bal_call, aprv_call) in Queue.iterTail(calls)) {
          let (bal, aprv) = (await bal_call, await aprv_call);
          switch (aprv.expires_at) {
            case (?found) if (found < now) continue calling;
            case _ ();
          };
          if (bal > maximum_balance.available) maximum_balance := {
            available = bal;
            main = ?filtered.main;
          };
          if (aprv.allowance > maximum_allowance.available) maximum_allowance := {
            available = aprv.allowance;
            main = ?filtered.main;
          };
          var main_ps = Option.get(RBTree.get(allowances, Nat.compare, filtered.allowance), RBTree.empty());
          var main_subs = L.getPrincipal(main_ps, filtered.main.owner, RBTree.empty());
          main_subs := L.saveBlob(main_subs, main_sub, filtered.main, bal >= xfer_and_fee and aprv.allowance >= xfer_and_fee);
          main_ps := L.savePrincipal(main_ps, filtered.main.owner, main_subs, RBTree.size(main_subs) > 0);
          allowances := if (RBTree.size(main_ps) > 0) RBTree.insert(allowances, Nat.compare, filtered.allowance, main_ps) else RBTree.delete(allowances, Nat.compare, filtered.allowance);
        };
        var payer : ?(ICRC1T.Account, Blob) = null;
        label find_nearest for ((allowance, main_ps) in RBTree.entries(allowances)) {
          for ((main_p, main_subs) in RBTree.entries(main_ps)) {
            for ((main_sub, main_a) in RBTree.entries(main_subs)) {
              payer := ?(main_a, main_sub);
              break find_nearest;
            };
          };
        };
        switch payer {
          case (?found) found;
          case _ return #Err(#NoEligibleMain { total = total_calls; maximum_balance; maximum_allowance });
        };
      };
    };
    var main_u = L.getPrincipal(users, main_a.owner, RBTree.empty());
    var main = L.getBlob(main_u, main_sub, L.initMain());
    func save<T>(ret : T) : T {
      main_u := L.saveBlob(main_u, main_sub, main, L.isMain(main));
      users := L.savePrincipal(users, main_a.owner, main_u, RBTree.size(main_u) > 0);
      ret;
    };
    let start_expiry = if (main.name == "") now else {
      if (main.locked_until > now) return #Err(#Locked { until = main.locked_until });
      if (main.expires_at > now) {
        // old name active
        if (main.name != arg.name) return #Err(#NamedAccount main);
        main.expires_at; // allow time extension
      } else now;
    };
    switch (RBTree.get(names, Text.compare, arg.name)) {
      case (?(reserver_p, reserver_sub)) if (reserver_p != main_a.owner or reserver_sub != main_sub) {
        let reserver = L.getBlob(L.getPrincipal(users, reserver_p, RBTree.empty()), reserver_sub, L.initMain());
        if (reserver.name == arg.name and (reserver.locked_until > now or reserver.expires_at > now)) return #Err(#NameReserved { by = { owner = reserver_p; subaccount = Subaccount.opt(reserver_sub) } });
      };
      case _ ();
    };
    switch (checkIdempotency(caller, #Register arg, arg.created_at, now)) {
      case (#Err err) return #Err err;
      case _ ();
    };
    let (old_name, old_name_expiry) = (main.name, main.expires_at);
    main := { main with name = arg.name };
    let locked_until = now + env.name.duration.lock;
    main := { main with locked_until; expires_at = locked_until };
    save(); // lock main

    names := RBTree.insert(names, Text.compare, arg.name, (main_a.owner, main_sub)); // lock name

    func unlock<T>(ret : T) : T {
      if (arg.name != old_name) names := RBTree.delete(names, Text.compare, arg.name);

      main_u := L.getPrincipal(users, main_a.owner, RBTree.empty());
      main := L.getBlob(main_u, main_sub, main);
      main := { main with name = old_name };
      main := { main with expires_at = old_name_expiry };
      main := { main with locked_until = 0 };
      ret;
    };
    let pay_arg = {
      main = ?main_a;
      spender_subaccount = null;
      token = arg.token;
      proxy = proxy_a;
      amount = arg.amount;
      to = { owner = env.service_provider; subaccount = null };
      memo = null;
      created_at = null;
    };
    let pay_res = try await linker.iilink_icrc1_transfer_from(pay_arg) catch (e) return save(unlock(#Err(Error.convert(e))));
    let pay_id = switch (unlock(pay_res)) {
      case (#Ok ok) ok.block_index;
      case (#Err err) return save(#Err(#TransferFailed err));
    };
    let new_name_expiry = start_expiry + Time64.DAYS(Nat64.fromNat(selected_package.years_base * 365)) + Time64.DAYS(Nat64.fromNat(selected_package.months_bonus * 30));
    main := { main with name = arg.name };
    main := { main with expires_at = new_name_expiry };
    save(); // confirm main

    names := RBTree.delete(names, Text.compare, old_name);
    names := RBTree.insert(names, Text.compare, arg.name, (main_a.owner, main_sub)); // confirm name

    name_expiries := RBTree.delete(name_expiries, L.compareNameExpiry, (old_name_expiry, old_name));
    name_expiries := RBTree.insert(name_expiries, L.compareNameExpiry, (new_name_expiry, arg.name), ());

    var proxy_ptr = L.getPrincipal(proxies, proxy_a.owner, RBTree.empty());
    let proxy_sub = Subaccount.get(proxy_a.subaccount);
    let (old_main_p, old_main_sub, old_proxy_expiry) = L.getBlob(proxy_ptr, proxy_sub, (main_a.owner, main_sub, 0 : Nat64));
    proxy_ptr := L.saveBlob(proxy_ptr, proxy_sub, (main_a.owner, main_sub, new_name_expiry), true);
    proxies := L.savePrincipal(proxies, proxy_a.owner, proxy_ptr, true); // confirm proxy

    proxy_expiries := RBTree.delete(proxy_expiries, L.compareProxyExpiry, (old_proxy_expiry, proxy_a.owner, proxy_sub));
    proxy_expiries := RBTree.insert(proxy_expiries, L.compareProxyExpiry, (new_name_expiry, proxy_a.owner, proxy_sub), ());

    let (block_id, phash) = ArchiveL.getPhash(blocks);
    if (arg.created_at != null) register_dedupes := RBTree.insert(register_dedupes, L.dedupeRegister, (caller, arg), block_id);
    newBlock(block_id, L.valueRegister(caller, arg, main_a, new_name_expiry, pay_id, now, if (is_icp) xdr_permyriad_per_icp else 0, phash));

    // ignore await* sendBlock();
    #Ok block_id;
  };

  public shared ({ caller }) func iiname_transfer(args : [T.TransferArg]) : async [T.TransferRes] {
    let now = syncTrim();
    if (args.size() == 0) return [];
    let arg = args[0];
    let proxy_a = { owner = caller; subaccount = arg.proxy_subaccount };
    if (not ICRC1L.validateAccount(proxy_a)) return [Error.text("Caller account is invalid")];
    if (not ICRC1L.validateAccount(arg.to)) return [Error.text("Recipient account is invalid")];

    switch (checkMemo(arg.memo)) {
      case (#Err err) return [#Err err];
      case _ ();
    };
    switch (arg.time_toll) {
      case (?defined) if (defined != env.name.duration.toll) return [#Err(#BadTimeToll { expected_time_toll = env.name.duration.toll })];
      case _ ();
    };
    var proxy_ptr = L.getPrincipal(proxies, proxy_a.owner, RBTree.empty());
    let proxy_sub = Subaccount.get(proxy_a.subaccount);
    let (from_p, from_sub, old_proxy_expiry) = switch (RBTree.get(proxy_ptr, Blob.compare, proxy_sub)) {
      case (?found) found;
      case _ return [#Err(#UnknownProxy)];
    };
    var from_u = L.getPrincipal(users, from_p, RBTree.empty());
    var from_main = L.getBlob(from_u, from_sub, L.initMain());
    if (from_main.name == "" or from_main.expires_at < now) return [#Err(#UnnamedSender)];
    if (from_main.locked_until > now) return [#Err(#SenderLocked { until = from_main.locked_until })];
    let remaining = from_main.expires_at - now;
    if (remaining < env.name.duration.toll) return [#Err(#InsufficientTime { remaining })];

    var to_u = L.getPrincipal(users, arg.to.owner, RBTree.empty());
    let to_sub = Subaccount.get(arg.to.subaccount);
    if (from_p == arg.to.owner and from_sub == to_sub) return [Error.text("Self-transfer is not allowed")];
    if (proxy_a.owner == arg.to.owner and proxy_sub == to_sub) return [Error.text("Proxy cannot receive")];

    var to_main = L.getBlob(to_u, to_sub, L.initMain());
    if (to_main.name != "" and (to_main.expires_at > now or to_main.locked_until > now)) return [#Err(#NamedRecipient to_main)];

    let new_name_expiry = from_main.expires_at - env.name.duration.toll;
    to_main := { to_main with name = from_main.name };
    to_main := { to_main with expires_at = new_name_expiry };
    to_u := L.saveBlob(to_u, to_sub, to_main, true);
    users := L.savePrincipal(users, arg.to.owner, to_u, true);

    names := RBTree.insert(names, Text.compare, to_main.name, (arg.to.owner, to_sub));

    name_expiries := RBTree.delete(name_expiries, L.compareNameExpiry, (from_main.expires_at, from_main.name));
    name_expiries := RBTree.insert(name_expiries, L.compareNameExpiry, (to_main.expires_at, to_main.name), ());

    from_u := L.getPrincipal(users, from_p, RBTree.empty());
    from_main := L.getBlob(from_u, from_sub, from_main);
    from_main := { from_main with name = ""; expires_at = 0 };
    from_u := L.saveBlob(from_u, from_sub, from_main, L.isMain(from_main));
    users := L.savePrincipal(users, from_p, from_u, RBTree.size(from_u) > 0);

    let (block_id, phash) = ArchiveL.getPhash(blocks);
    newBlock(block_id, L.valueTransfer(caller, arg, from_p, Subaccount.opt(from_sub), Nat64.toNat(env.name.duration.toll), now, phash));

    // ignore await* sendBlock();
    [#Ok block_id];
  };

  public shared ({ caller }) func iiname_approve(args : [T.ApproveArg]) : async [T.ApproveRes] {
    let now = syncTrim();
    if (args.size() == 0) return [];
    let arg = args[0];
    let proxy_a = { owner = caller; subaccount = arg.proxy_subaccount };
    if (not ICRC1L.validateAccount(proxy_a)) return [Error.text("Caller account is invalid")];
    if (not ICRC1L.validateAccount(arg.operator)) return [Error.text("Operator account is invalid")];

    switch (checkMemo(arg.memo)) {
      case (#Err err) return [#Err err];
      case _ ();
    };
    switch (arg.time_toll) {
      case (?defined) if (defined != env.name.duration.toll) return [#Err(#BadTimeToll { expected_time_toll = env.name.duration.toll })];
      case _ ();
    };
    var proxy_ptr = L.getPrincipal(proxies, proxy_a.owner, RBTree.empty());
    let proxy_sub = Subaccount.get(proxy_a.subaccount);
    let (from_p, from_sub, old_proxy_expiry) = switch (RBTree.get(proxy_ptr, Blob.compare, proxy_sub)) {
      case (?found) found;
      case _ return [#Err(#UnknownProxy)];
    };
    var from_u = L.getPrincipal(users, from_p, RBTree.empty());
    let operator_sub = Subaccount.get(arg.operator.subaccount);
    if (from_p == arg.operator.owner and from_sub == operator_sub) return [Error.text("Self-approve is not allowed")];
    if (proxy_a.owner == arg.operator.owner and proxy_sub == operator_sub) return [Error.text("Proxy cannot be a operator")];

    var from_main = L.getBlob(from_u, from_sub, L.initMain());
    if (from_main.name == "" or from_main.expires_at < now) return [#Err(#UnnamedSender)];
    if (from_main.locked_until > now) return [#Err(#SenderLocked { until = from_main.locked_until })];
    let remaining = from_main.expires_at - now;
    if (remaining < env.name.duration.toll) return [#Err(#InsufficientTime { remaining })];

    if (arg.expires_at < now) return [#Err(#Expired { time = now })];
    let maximum_expiry = now + env.name.duration.max_expiry;
    if (arg.expires_at > maximum_expiry) return [#Err(#ExpiresTooLate { maximum_expiry })];

    switch (checkIdempotency(caller, #Approve arg, arg.created_at, now)) {
      case (#Err err) return [#Err err];
      case _ ();
    };
    var from_operator = L.getPrincipal(from_main.operators, arg.operator.owner, RBTree.empty());
    let old_operator_expiry = L.getBlob(from_operator, operator_sub, 0 : Nat64);
    from_operator := RBTree.insert(from_operator, Blob.compare, operator_sub, arg.expires_at);
    let operators = L.savePrincipal(from_main.operators, arg.operator.owner, from_operator, true);
    from_main := { from_main with operators };

    let old_name_expiry = from_main.expires_at;
    let new_name_expiry = from_main.expires_at - env.name.duration.toll;
    from_main := { from_main with expires_at = new_name_expiry };
    from_u := L.saveBlob(from_u, from_sub, from_main, L.isMain(from_main));
    users := L.savePrincipal(users, from_p, from_u, RBTree.size(from_u) > 0);

    operator_expiries := RBTree.delete(operator_expiries, L.compareManagerExpiry, (old_operator_expiry, (from_p, from_sub), (arg.operator.owner, operator_sub)));
    operator_expiries := RBTree.insert(operator_expiries, L.compareManagerExpiry, (arg.expires_at, (from_p, from_sub), (arg.operator.owner, operator_sub)), ());

    name_expiries := RBTree.delete(name_expiries, L.compareNameExpiry, (old_name_expiry, from_main.name));
    name_expiries := RBTree.insert(name_expiries, L.compareNameExpiry, (new_name_expiry, from_main.name), ());

    let (block_id, phash) = ArchiveL.getPhash(blocks);
    if (arg.created_at != null) approve_dedupes := RBTree.insert(approve_dedupes, L.dedupeApprove, (caller, arg), block_id);
    newBlock(block_id, L.valueApprove(caller, arg, from_p, Subaccount.opt(from_sub), Nat64.toNat(env.name.duration.toll), now, phash));

    // ignore await* sendBlock();
    [#Ok block_id];
  };

  public shared ({ caller }) func iiname_revoke(args : [T.RevokeArg]) : async [T.RevokeRes] {
    let now = syncTrim();
    if (args.size() == 0) return [];
    let arg = args[0];
    let proxy_a = { owner = caller; subaccount = arg.proxy_subaccount };
    if (not ICRC1L.validateAccount(proxy_a)) return [Error.text("Caller account is invalid")];
    if (not ICRC1L.validateAccount(arg.operator)) return [Error.text("Manager account is invalid")];

    switch (checkMemo(arg.memo)) {
      case (#Err err) return [#Err err];
      case _ ();
    };
    switch (arg.time_toll) {
      case (?defined) if (defined != env.name.duration.toll) return [#Err(#BadTimeToll { expected_time_toll = env.name.duration.toll })];
      case _ ();
    };
    var proxy_ptr = L.getPrincipal(proxies, proxy_a.owner, RBTree.empty());
    let proxy_sub = Subaccount.get(proxy_a.subaccount);
    let (from_p, from_sub, old_proxy_expiry) = switch (RBTree.get(proxy_ptr, Blob.compare, proxy_sub)) {
      case (?found) found;
      case _ return [#Err(#UnknownProxy)];
    };
    var from_u = L.getPrincipal(users, from_p, RBTree.empty());
    var from_main = L.getBlob(from_u, from_sub, L.initMain());
    if (from_main.name == "" or from_main.expires_at < now) return [#Err(#UnnamedSender)];
    if (from_main.locked_until > now) return [#Err(#SenderLocked { until = from_main.locked_until })];
    let remaining = from_main.expires_at - now;
    if (remaining < env.name.duration.toll) return [#Err(#InsufficientTime { remaining })];

    var from_operator = L.getPrincipal(from_main.operators, arg.operator.owner, RBTree.empty());
    let operator_sub = Subaccount.get(arg.operator.subaccount);
    let old_operator_expiry = switch (RBTree.get(from_operator, Blob.compare, operator_sub)) {
      case (?found) found;
      case _ return [#Err(#UnknownOperator)];
    };
    from_operator := RBTree.delete(from_operator, Blob.compare, operator_sub);
    let operators = L.savePrincipal(from_main.operators, arg.operator.owner, from_operator, true);
    from_main := { from_main with operators };

    let old_name_expiry = from_main.expires_at;
    let new_name_expiry = from_main.expires_at - env.name.duration.toll;
    from_main := { from_main with expires_at = new_name_expiry };
    from_u := L.saveBlob(from_u, from_sub, from_main, L.isMain(from_main));
    users := L.savePrincipal(users, from_p, from_u, RBTree.size(from_u) > 0);
    operator_expiries := RBTree.delete(operator_expiries, L.compareManagerExpiry, (old_operator_expiry, (from_p, from_sub), (arg.operator.owner, operator_sub)));

    name_expiries := RBTree.delete(name_expiries, L.compareNameExpiry, (old_name_expiry, from_main.name));
    name_expiries := RBTree.insert(name_expiries, L.compareNameExpiry, (new_name_expiry, from_main.name), ());

    let (block_id, phash) = ArchiveL.getPhash(blocks);
    newBlock(block_id, L.valueRevoke(caller, arg, from_p, Subaccount.opt(from_sub), Nat64.toNat(env.name.duration.toll), now, phash));

    // ignore await* sendBlock();
    [#Ok block_id];
  };

  public shared ({ caller }) func iiname_transfer_from(args : [T.TransferFromArg]) : async [T.TransferFromRes] {
    let now = syncTrim();
    if (args.size() == 0) return [];
    let arg = args[0];
    let operator_a = { owner = caller; subaccount = arg.operator_subaccount };
    if (not ICRC1L.validateAccount(operator_a)) return [Error.text("Caller account is invalid")];
    if (not ICRC1L.validateAccount(arg.proxy)) return [Error.text("Proxy account is invalid")];
    if (not ICRC1L.validateAccount(arg.to)) return [Error.text("Recipient account is invalid")];

    let operator_sub = Subaccount.get(operator_a.subaccount);
    let proxy_sub = Subaccount.get(arg.proxy.subaccount);
    if (arg.proxy.owner == operator_a.owner and proxy_sub == operator_sub) return [Error.text("Caller cannot spend")];
    let to_sub = Subaccount.get(arg.to.subaccount);
    if (arg.proxy.owner == arg.to.owner and proxy_sub == to_sub) return [Error.text("Proxy cannot receive")];

    switch (checkMemo(arg.memo)) {
      case (#Err err) return [#Err err];
      case _ ();
    };
    switch (arg.time_toll) {
      case (?defined) if (defined != env.name.duration.toll) return [#Err(#BadTimeToll { expected_time_toll = env.name.duration.toll })];
      case _ ();
    };
    var proxy_ptr = L.getPrincipal(proxies, arg.proxy.owner, RBTree.empty());
    let (from_p, from_sub, old_proxy_expiry) = switch (RBTree.get(proxy_ptr, Blob.compare, proxy_sub)) {
      case (?found) found;
      case _ return [#Err(#UnknownProxy)];
    };
    if (from_p == operator_a.owner and from_sub == operator_sub) return [Error.text("Sender cannot spend")];
    if (from_p == arg.to.owner and from_sub == to_sub) return [Error.text("Self-transfer is not allowed")];

    var from_u = L.getPrincipal(users, from_p, RBTree.empty());
    var from_main = L.getBlob(from_u, from_sub, L.initMain());
    if (from_main.name == "" or from_main.expires_at < now) return [#Err(#UnnamedSender)];
    if (from_main.locked_until > now) return [#Err(#SenderLocked { until = from_main.locked_until })];
    let remaining = from_main.expires_at - now;
    if (remaining < env.name.duration.toll) return [#Err(#InsufficientTime { remaining })];

    var from_operator = L.getPrincipal(from_main.operators, operator_a.owner, RBTree.empty());
    let approval_expiry = L.getBlob(from_operator, operator_sub, 0 : Nat64);
    if (approval_expiry < now) return [#Err(#UnknownOperator)];

    var to_u = L.getPrincipal(users, arg.to.owner, RBTree.empty());
    var to_main = L.getBlob(to_u, to_sub, L.initMain());
    if (to_main.name != "" and (to_main.expires_at > now or to_main.locked_until > now)) return [#Err(#NamedRecipient to_main)];

    let new_name_expiry = from_main.expires_at - env.name.duration.toll;
    to_main := { to_main with name = from_main.name };
    to_main := { to_main with expires_at = new_name_expiry };
    to_u := L.saveBlob(to_u, to_sub, to_main, true);
    users := L.savePrincipal(users, arg.to.owner, to_u, true);

    names := RBTree.insert(names, Text.compare, to_main.name, (arg.to.owner, to_sub));

    name_expiries := RBTree.delete(name_expiries, L.compareNameExpiry, (from_main.expires_at, from_main.name));
    name_expiries := RBTree.insert(name_expiries, L.compareNameExpiry, (to_main.expires_at, to_main.name), ());

    from_u := L.getPrincipal(users, from_p, RBTree.empty());
    from_main := L.getBlob(from_u, from_sub, from_main);
    from_main := { from_main with name = ""; expires_at = 0 };
    from_operator := L.saveBlob(from_operator, operator_sub, 0 : Nat64, false);
    let operators = L.savePrincipal(from_main.operators, operator_a.owner, from_operator, RBTree.size(from_operator) > 0);
    from_main := { from_main with operators };
    from_u := L.saveBlob(from_u, from_sub, from_main, L.isMain(from_main));
    users := L.savePrincipal(users, from_p, from_u, RBTree.size(from_u) > 0);

    operator_expiries := RBTree.delete(operator_expiries, L.compareManagerExpiry, (approval_expiry, (from_p, from_sub), (operator_a.owner, operator_sub)));

    let (block_id, phash) = ArchiveL.getPhash(blocks);
    newBlock(block_id, L.valueTransferFrom(caller, arg, from_p, Subaccount.opt(from_sub), Nat64.toNat(env.name.duration.toll), now, phash));

    // ignore await* sendBlock();
    [#Ok block_id];
  };

  public shared query func iiname_main_subaccounts(arg : T.SubaccountsOfArg) : async T.SubaccountsOfRes {
    let max_take = Nat.min(Option.get(arg.take, env.max_take_value), env.max_take_value);
    let buf = Buffer.Buffer<Blob>(max_take);
    let main_u = L.getPrincipal(users, arg.main_owner, RBTree.empty());
    for ((k, v) in RBTree.range(main_u, Blob.compare, arg.previous, max_take)) buf.add(if (k.size() == 0) Blob.fromArray(Subaccount.DEFAULT) else k);
    {
      total = RBTree.size(main_u);
      results = Buffer.toArray(buf);
      callbacks = [];
    };
  };

  public shared query func iiname_names(args : [ICRC1T.Account]) : async T.NamesOfRes {
    let max_take = Nat.min(args.size(), env.max_query_batch_size);
    let now = Time64.nanos();
    let buff = Buffer.Buffer<T.Name>(max_take);
    label finding for (arg in args.vals()) {
      if (buff.size() >= max_take) break finding;
      let main_u = L.getPrincipal(users, arg.owner, RBTree.empty());
      let main_sub = Subaccount.get(arg.subaccount);
      let main = L.getBlob(main_u, main_sub, L.initMain());
      buff.add(main);
    };
    {
      total = RBTree.size(users);
      results = Buffer.toArray(buff);
      callbacks = [];
    };
  };

  public shared query func iiname_operators(arg : T.OperatorsOfArg) : async T.OperatorsOfRes {
    let max_take = Nat.min(Option.get(arg.take, env.max_take_value), env.max_take_value);
    let main_u = L.getPrincipal(users, arg.main.owner, RBTree.empty());
    let main_sub = Subaccount.get(arg.main.subaccount);
    let main = L.getBlob(main_u, main_sub, L.initMain());
    {
      total = RBTree.size(main.operators);
      results = RBTree.pageKey(main.operators, Principal.compare, arg.previous, max_take);
      callbacks = [];
    };
  };

  public shared query func iiname_operator_subaccounts(arg : T.OperatorSubsOfArg) : async T.OperatorSubsOfRes {
    let max_take = Nat.min(Option.get(arg.take, env.max_take_value), env.max_take_value);
    let buf = Buffer.Buffer<Blob>(max_take);
    let main_u = L.getPrincipal(users, arg.main.owner, RBTree.empty());
    let main_sub = Subaccount.get(arg.main.subaccount);
    let main = L.getBlob(main_u, main_sub, L.initMain());
    let operator = L.getPrincipal(main.operators, arg.operator_owner, RBTree.empty());
    for ((k, v) in RBTree.range(operator, Blob.compare, arg.previous, max_take)) buf.add(if (k.size() == 0) Blob.fromArray(Subaccount.DEFAULT) else k);
    {
      total = RBTree.size(operator);
      results = Buffer.toArray(buf);
      callbacks = [];
    };
  };

  public shared query func iiname_approvals(args : [T.ApprovalOfArg]) : async T.ApprovalsOfRes {
    let max_take = Nat.min(args.size(), env.max_query_batch_size);
    let now = Time64.nanos();
    let buff = Buffer.Buffer<Nat64>(max_take);
    label finding for (arg in args.vals()) {
      if (buff.size() >= max_take) break finding;
      let main_u = L.getPrincipal(users, arg.main.owner, RBTree.empty());
      let main_sub = Subaccount.get(arg.main.subaccount);
      let main = L.getBlob(main_u, main_sub, L.initMain());
      let operator = L.getPrincipal(main.operators, arg.operator.owner, RBTree.empty());
      let operator_sub = Subaccount.get(arg.operator.subaccount);
      let expires_at = L.getBlob(operator, operator_sub, 0: Nat64);
      buff.add(expires_at);
    };
    {
      total = RBTree.size(users);
      results = Buffer.toArray(buff);
      callbacks = [];
    };
  };

  public shared query func iiname_proxy_subaccounts(arg : T.ProxySubsOfArg) : async T.ProxySubsOfRes {
    let max_take = Nat.min(Option.get(arg.take, env.max_take_value), env.max_take_value);
    let buf = Buffer.Buffer<Blob>(max_take);
    let proxy_ptr = L.getPrincipal(proxies, arg.proxy_owner, RBTree.empty());
    for ((k, v) in RBTree.range(proxy_ptr, Blob.compare, arg.previous, max_take)) buf.add(if (k.size() == 0) Blob.fromArray(Subaccount.DEFAULT) else k);
    {
      total = RBTree.size(proxy_ptr);
      results = Buffer.toArray(buf);
      callbacks = [];
    };
  };

  public shared query func iiname_mains(args : [ICRC1T.Account]) : async T.MainsOfRes {
    let max_take = Nat.min(args.size(), env.max_query_batch_size);
    let now = Time64.nanos();
    let buff = Buffer.Buffer<?ICRC1T.Account>(max_take);
    label finding for (arg in args.vals()) {
      if (buff.size() >= max_take) break finding;
      let proxy_ptr = L.getPrincipal(proxies, arg.owner, RBTree.empty());
      let proxy_sub = Subaccount.get(arg.subaccount);
      let main = switch (RBTree.get(proxy_ptr, Blob.compare, proxy_sub)) {
        case (?(owner, sub, expiry)) (?{ owner; subaccount = Subaccount.opt(sub)});
        case _ null;
      };
      buff.add(main);
    };
    {
      total = RBTree.size(proxies);
      results = Buffer.toArray(buff);
      callbacks = [];
    };
  };

  public shared query func iiname_accounts(args : [Text]) : async T.AccountsOfRes {
    let max_take = Nat.min(args.size(), env.max_query_batch_size);
    let now = Time64.nanos();
    let buff = Buffer.Buffer<?ICRC1T.Account>(max_take);
    label finding for (arg in args.vals()) {
      if (buff.size() >= max_take) break finding;
      let acct = switch (RBTree.get(names, Text.compare, arg)) {
        case (?(owner, sub))(?{ owner; subaccount = Subaccount.opt(sub)});
        case _ null;
      };
      buff.add(acct);
    };
    {
      total = RBTree.size(names);
      results = Buffer.toArray(buff);
      callbacks = [];
    };
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
