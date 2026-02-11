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
    };
    service_provider = install.caller;
    cmc = ?CMC.ID;
    max_update_batch_size = 1;
    max_query_batch_size = 1;
    max_take_value = 1;
    name = {
      price_tiers = [
        { length = { min = 1; max = 1 }; tcycles_fee_multiplier = 50_000_000 }, // 5000
        { length = { min = 2; max = 2 }; tcycles_fee_multiplier = 10_000_000 }, // 1000
        { length = { min = 3; max = 3 }; tcycles_fee_multiplier = 5_000_000 }, // 500
        { length = { min = 4; max = 4 }; tcycles_fee_multiplier = 2_500_000 }, // 250
        { length = { min = 5; max = 5 }; tcycles_fee_multiplier = 1_000_000 }, // 100
        { length = { min = 6; max = 6 }; tcycles_fee_multiplier = 500_000 }, // 50
        { length = { min = 7; max = 7 }; tcycles_fee_multiplier = 250_000 }, // 25
        { length = { min = 8; max = 8 }; tcycles_fee_multiplier = 100_000 }, // 10
        { length = { min = 9; max = 9 }; tcycles_fee_multiplier = 50_000 }, // 5
        { length = { min = 10; max = 19 }; tcycles_fee_multiplier = 20_000 }, // 2
        { length = { min = 20; max = 32 }; tcycles_fee_multiplier = 10_000 }, // 1 TCYCLES
      ];
      duration = {
        reduction = Time64.HOURS(12);
        renewable = Time64.DAYS(2);
        packages = [
          { year = 1; months_bonus = 2 },
          { year = 3; months_bonus = 12 },
          { year = 5; months_bonus = 24 },
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
  //   case _ (); // todo: uncomment this
  // };

  var blocks = RBTree.empty<Nat, ArchiveT.Block>();
  var users = RBTree.empty<Principal, T.User>();
  var proxies = RBTree.empty<Principal, T.Proxy>();
  var proxy_expiries = RBTree.empty<(Nat64, Principal, Blob), ()>();
  var spender_expiries = RBTree.empty<(Nat64, from : (Principal, Blob), spender : (Principal, Blob)), ()>();

  var names = RBTree.empty<Text, (Principal, Blob)>();
  var name_expiries = RBTree.empty<(Nat64, Text), ()>();

  var register_dedupes = RBTree.empty<(Principal, T.RegisterArg), Nat>();
  var approve_dedupes = RBTree.empty<(Principal, T.ApproveArg), Nat>();

  // public shared query func accn_main_subaccounts_of(owner : Principal, prev : ?Blob, take : ?Nat) : async [Blob] {
  //   let max_take = Nat.min(Option.get(take, env.max_take_value), env.max_take_value);
  //   let buf = Buffer.Buffer<Blob>(max_take);
  //   RBTree.void(getUser(owner), Blob.compare, prev, max_take, func(k, v) = buf.add(if (k.size() == 0) Blob.fromArray(Subaccount.DEFAULT) else k));
  //   Buffer.toArray(buf);
  // };

  // public shared query func accn_spenders_of(main_a : ICRC1T.Account, prev : ?Principal, take : ?Nat) : async [Principal] {
  //   let max_take = Nat.min(Option.get(take, env.max_take_value), env.max_take_value);
  //   let main = L.forceMain(L.getRole(getUser(main_a.owner), Subaccount.get(main_a.subaccount)));
  //   RBTree.pageKey(main.spenders, Principal.compare, prev, max_take);
  // };

  // public shared query func accn_spender_subaccounts_of(main_a : ICRC1T.Account, spender_p : Principal, prev : ?Blob, take : ?Nat) : async [Blob] {
  //   let max_take = Nat.min(Option.get(take, env.max_take_value), env.max_take_value);
  //   let main = L.forceMain(L.getRole(getUser(main_a.owner), Subaccount.get(main_a.subaccount)));
  //   let buf = Buffer.Buffer<Blob>(max_take);
  //   RBTree.void(L.getOwner(main.spenders, spender_p), Blob.compare, prev, max_take, func(k, v) = buf.add(if (k.size() == 0) Blob.fromArray(Subaccount.DEFAULT) else k));
  //   Buffer.toArray(buf);
  // };

  // public shared query func accn_names_of(accounts : [ICRC1T.Account]) : async [T.Name] {
  //   let max_take = Nat.min(accounts.size(), env.max_query_batch_size);
  //   let buff = Buffer.Buffer<T.Name>(max_take);
  //   label finding for (acc in accounts.vals()) {
  //     let role = L.getRole(getUser(acc.owner), Subaccount.get(acc.subaccount));
  //     buff.add(L.forceMain(role));
  //   };
  //   Buffer.toArray(buff);
  // };

  // public shared query func accn_allowances_of(args : [ICRC1T.AllowanceArg]) : async [?(expires_at : ?Nat64)] {
  //   let max_take = Nat.min(args.size(), env.max_query_batch_size);
  //   let buff = Buffer.Buffer<?(expires_at : ?Nat64)>(max_take);
  //   label finding for (arg in args.vals()) {
  //     let main = L.forceMain(L.getRole(getUser(arg.account.owner), Subaccount.get(arg.account.subaccount)));
  //     let spender = L.getOwner(main.spenders, arg.spender.owner);
  //     buff.add(RBTree.get(spender, Blob.compare, Subaccount.get(arg.spender.subaccount)));
  //   };
  //   Buffer.toArray(buff);
  // };

  // public shared query func accn_accounts_of(args : [Text]) : async [?ICRC1T.Account] {
  //   let max_take = Nat.min(args.size(), env.max_query_batch_size);
  //   let buff = Buffer.Buffer<?ICRC1T.Account>(max_take);
  //   label finding for (arg in args.vals()) {
  //     let acc = switch (RBTree.get(names, Text.compare, arg)) {
  //       case (?(p, sub)) ?{ owner = p; subaccount = Subaccount.opt(sub) };
  //       case _ null;
  //     };
  //     buff.add(acc);
  //   };
  //   Buffer.toArray(buff);
  // };

  public shared query func accn_service_provider() : async ICRC1T.Account = async ({
    owner = env.service_provider;
    subaccount = null;
  });

  public shared query func x_name_length_tiers() : async [{
    length : { min : Nat; max : Nat };
    tcycles_fee_multiplier : Nat;
  }] = async env.name.price_tiers;

  public shared query func x_name_duration_packages() : async [{
    year : Nat;
    months_bonus : Nat;
  }] = async env.name.duration.packages;

  public shared ({ caller }) func accn_register(arg : T.RegisterArg) : async T.RegisterRes {
    let now = syncTrim();
    if (not env.available) return Error.text("Unavailable");
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

    var fee_base = 0;
    label sizing for (tier in env.name.price_tiers.vals()) if (name_len >= tier.length.min and name_len <= tier.length.max) {
      fee_base := tier.tcycles_fee_multiplier * tcycles_fee;
      break sizing;
    };
    if (fee_base == 0) return #Err(#UnknownLengthTier);
    var selected_package = { year = 0; months_bonus = 0; total = 0 };
    let xdr_permyriad_per_icp = Nat64.toNat(icp_xdr.data.xdr_permyriad_per_icp);
    label timing for (package in env.name.duration.packages.vals()) {
      let total_tcycles = package.year * fee_base;
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
    let (main_a, main_sub) = switch (arg.payer) {
      case (?main_a) {
        let links_call = linker.accl_icrc1_allowances([{
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
        let links = await linker.accl_icrc1_sufficient_allowances({
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
    if (main.expires_at == 1) return #Err(#Locked);
    let start_expiry = if (arg.name == main.name) Nat64.max(now, main.expires_at) else {
      if (main.expires_at > now) return #Err(#NamedAccount main);
      // todo: validate
      switch (RBTree.get(names, Text.compare, arg.name)) {
        case (?(name_p, name_sub)) if (name_p != main_a.owner or name_sub != main_sub) return #Err(#NameReserved { by = { owner = name_p; subaccount = Subaccount.opt(name_sub) } });
        case _ ();
      };
      now; // name belongs to caller, or no one
    };
    switch (checkIdempotency(caller, #Register arg, arg.created_at, now)) {
      case (#Err err) return #Err err;
      case _ ();
    };
    let (old_name, old_name_expiry) = (main.name, main.expires_at);
    main := { main with name = arg.name };
    main := { main with expires_at = 1 }; // lock
    func save<T>(ret : T) : T {
      main_u := L.saveBlob(main_u, main_sub, main, L.isMain(main));
      users := L.savePrincipal(users, main_a.owner, main_u, RBTree.size(main_u) > 0);
      ret;
    };
    save(); // lock main

    names := RBTree.insert(names, Text.compare, arg.name, (main_a.owner, main_sub)); // lock name

    func unlock<T>(ret : T) : T {
      if (arg.name != old_name) names := RBTree.delete(names, Text.compare, arg.name);

      main_u := L.getPrincipal(users, main_a.owner, RBTree.empty());
      main := L.getBlob(main_u, main_sub, main);
      main := { main with name = old_name };
      main := { main with expires_at = old_name_expiry };
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
    let pay_res = try await linker.accl_icrc1_transfer_from(pay_arg) catch (e) return save(unlock(#Err(Error.convert(e))));
    let pay_id = switch (unlock(pay_res)) {
      case (#Ok ok) ok.block_index;
      case (#Err err) return save(#Err(#TransferFailed err));
    };
    let new_name_expiry = start_expiry + Time64.DAYS(Nat64.fromNat(selected_package.year * 365)) + Time64.DAYS(Nat64.fromNat(selected_package.months_bonus * 30));
    main := { main with name = arg.name };
    main := { main with expires_at = new_name_expiry };
    save(); // confirm main

    names := RBTree.insert(names, Text.compare, arg.name, (main_a.owner, main_sub)); // confirm name
    names := RBTree.delete(names, Text.compare, old_name);

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
    // newBlock(block_id, L.valueDeposit(caller, sub, arg, depo_id, now, phash)); // todo: all value*() must store proxy and main?

    // ignore await* sendBlock();
    #Ok block_id;
  };

  // public shared ({ caller }) func accn_transfer(args : [T.TransferArg]) : async [T.TransferRes] {
  //   let now = syncTrim();
  //   if (args.size() == 0) return [];
  //   if (not env.available) return [Error.text("Unavailable")];
  //   let arg = args[0];
  //   let proxy_a = { owner = caller; subaccount = arg.proxy_subaccount };
  //   if (not ICRC1L.validateAccount(proxy_a)) return [Error.text("Caller account is invalid")];
  //   if (not ICRC1L.validateAccount(arg.to)) return [Error.text("Recipient account is invalid")];

  //   switch (checkMemo(arg.memo)) {
  //     case (#Err err) return [#Err err];
  //     case _ ();
  //   };
  //   var proxy_u = getUser(proxy_a.owner);
  //   let proxy_sub = Subaccount.get(proxy_a.subaccount);
  //   let (from_a, old_proxy_expiry) = switch (L.getRole(proxy_u, proxy_sub)) {
  //     case (#Proxy found) found;
  //     case (#Main _) return [#Err(#UnknownProxy)];
  //   };
  //   var from_u = getUser(from_a.owner);
  //   let from_sub = Subaccount.get(from_a.subaccount);
  //   var from_main = switch (L.getRole(from_u, from_sub)) {
  //     case (#Main found) found;
  //     case (#Proxy(of, _)) return [#Err(#SenderIsProxy { of })];
  //   };
  //   if (Text.size(from_main.name) == 0 or from_main.expires_at < now) return [#Err(#UnnamedSender)];
  //   let (self_p, self_sub) = (Principal.fromActor(Self), Subaccount.get(null));

  //   let remaining = from_main.expires_at - now;
  //   if (remaining < env.name.duration.reduction) return [#Err(#InsufficientDuration { remaining })];

  //   var from_locker = L.getOwner(from_main.spenders, self_p);
  //   if (RBTree.size(from_locker) > 0) return [#Err(#LockedSender)];
  //   switch (arg.expiry_reduction) {
  //     case (?defined) if (defined != env.name.duration.reduction) return [#Err(#BadExpiryReduction { expected_expiry_reduction = env.name.duration.reduction })];
  //     case _ ();
  //   };
  //   var to_u = getUser(arg.to.owner);
  //   let to_sub = Subaccount.get(arg.to.subaccount);
  //   if (from_a.owner == arg.to.owner and from_sub == to_sub) return [Error.text("Self-transfer is not allowed")];
  //   if (proxy_a.owner == arg.to.owner and proxy_sub == to_sub) return [Error.text("Proxy cannot receive")];

  //   var to_main = switch (L.getRole(to_u, to_sub)) {
  //     case (#Main found) found;
  //     case (#Proxy(of, _)) return [#Err(#RecipientIsProxy { of })];
  //   };
  //   if (Text.size(to_main.name) > 0 and to_main.expires_at > now) return [#Err(#NamedRecipient to_main)];
  //   var to_locker = L.getOwner(to_main.spenders, self_p);
  //   if (RBTree.size(to_locker) > 0) return [#Err(#LockedRecipient)];

  //   to_main := { to_main with name = from_main.name };
  //   to_main := {
  //     to_main with expires_at = from_main.expires_at - env.name.duration.reduction
  //   };
  //   to_u := L.saveRole(to_u, to_sub, #Main to_main);
  //   saveUser(arg.to.owner, to_u, ());

  //   names := RBTree.insert(names, Text.compare, to_main.name, (arg.to.owner, to_sub));
  //   name_expiries := RBTree.delete(name_expiries, L.compareNameExpiry, (from_main.expires_at, from_main.name));
  //   name_expiries := RBTree.insert(name_expiries, L.compareNameExpiry, (to_main.expires_at, to_main.name), ());

  //   from_u := getUser(from_a.owner);
  //   from_main := L.forceMain(L.getRole(from_u, from_sub));
  //   from_main := { from_main with name = "" };
  //   from_main := { from_main with expires_at = 0 };
  //   from_u := L.saveRole(from_u, from_sub, #Main from_main);
  //   saveUser(from_a.owner, from_u, ());

  //   let (block_id, phash) = ArchiveL.getPhash(blocks);
  //   // newBlock(block_id, L.valueDeposit(caller, sub, arg, depo_id, now, phash)); // todo: all value*() must store proxy and main?

  //   // ignore await* sendBlock();
  //   [#Ok block_id];
  // };

  // public shared ({ caller }) func accn_approve(args : [T.ApproveArg]) : async [T.ApproveRes] {
  //   let now = syncTrim();
  //   if (args.size() == 0) return [];
  //   if (not env.available) return [Error.text("Unavailable")];
  //   let arg = args[0];
  //   let proxy_a = { owner = caller; subaccount = arg.proxy_subaccount };
  //   if (not ICRC1L.validateAccount(proxy_a)) return [Error.text("Caller account is invalid")];
  //   if (not ICRC1L.validateAccount(arg.spender)) return [Error.text("Manager account is invalid")];
  //   let (self_p, self_sub) = (Principal.fromActor(Self), Subaccount.get(null));
  //   if (arg.spender.owner == self_p) return [Error.text("Cannot approve this canister")];

  //   switch (checkMemo(arg.memo)) {
  //     case (#Err err) return [#Err err];
  //     case _ ();
  //   };
  //   var proxy_u = getUser(proxy_a.owner);
  //   let proxy_sub = Subaccount.get(proxy_a.subaccount);
  //   let (from_a, old_proxy_expiry) = switch (L.getRole(proxy_u, proxy_sub)) {
  //     case (#Proxy found) found;
  //     case (#Main _) return [#Err(#UnknownProxy)];
  //   };
  //   var from_u = getUser(from_a.owner);
  //   let from_sub = Subaccount.get(from_a.subaccount);
  //   let spender_sub = Subaccount.get(arg.spender.subaccount);
  //   if (from_a.owner == arg.spender.owner and from_sub == spender_sub) return [Error.text("Self-approve is not allowed")];
  //   if (proxy_a.owner == arg.spender.owner and proxy_sub == spender_sub) return [Error.text("Proxy cannot be a spender")];

  //   var from_main = switch (L.getRole(from_u, from_sub)) {
  //     case (#Main found) found;
  //     case (#Proxy(of, _)) return [#Err(#SenderIsProxy { of })];
  //   };
  //   if (Text.size(from_main.name) == 0 or from_main.expires_at < now) return [#Err(#Unnamed)];

  //   let remaining = from_main.expires_at - now;
  //   if (remaining < env.name.duration.reduction) return [#Err(#InsufficientDuration { remaining })];

  //   let from_locker = L.getOwner(from_main.spenders, self_p);
  //   if (RBTree.size(from_locker) > 0) return [#Err(#Locked)];
  //   switch (arg.expiry_reduction) {
  //     case (?defined) if (defined != env.name.duration.reduction) return [#Err(#BadExpiryReduction { expected_expiry_reduction = env.name.duration.reduction })];
  //     case _ ();
  //   };
  //   switch (arg.expires_at) {
  //     case (?defined) if (defined < now) return [#Err(#Expired { time = now })];
  //     case _ ();
  //   };
  //   switch (checkIdempotency(caller, #Approve arg, arg.created_at, now)) {
  //     case (#Err err) return [#Err err];
  //     case _ ();
  //   };
  //   var from_spender = L.getOwner(from_main.spenders, arg.spender.owner);
  //   let old_spender_expiry = Option.get(RBTree.get(from_spender, Blob.compare, spender_sub), null);
  //   from_spender := RBTree.insert(from_spender, Blob.compare, spender_sub, arg.expires_at);
  //   let spenders = L.saveOwner(from_main.spenders, arg.spender.owner, from_spender);
  //   from_main := { from_main with spenders };

  //   let old_name_expiry = from_main.expires_at;
  //   let new_name_expiry = from_main.expires_at - env.name.duration.reduction;
  //   from_main := { from_main with expires_at = new_name_expiry };
  //   from_u := L.saveRole(from_u, from_sub, #Main from_main);
  //   saveUser(from_a.owner, from_u, ());

  //   switch old_spender_expiry {
  //     case (?found) spender_expiries := RBTree.delete(spender_expiries, L.compareManagerExpiry, (found, (from_a.owner, from_sub), (arg.spender.owner, spender_sub)));
  //     case _ ();
  //   };
  //   switch (arg.expires_at) {
  //     case (?found) spender_expiries := RBTree.insert(spender_expiries, L.compareManagerExpiry, (found, (from_a.owner, from_sub), (arg.spender.owner, spender_sub)), ());
  //     case _ ();
  //   };
  //   name_expiries := RBTree.delete(name_expiries, L.compareNameExpiry, (old_name_expiry, from_main.name));
  //   name_expiries := RBTree.insert(name_expiries, L.compareNameExpiry, (new_name_expiry, from_main.name), ());

  //   let (block_id, phash) = ArchiveL.getPhash(blocks);
  //   if (arg.created_at != null) approve_dedupes := RBTree.insert(approve_dedupes, L.dedupeApprove, (caller, arg), block_id);
  //   // newBlock(block_id, L.valueDeposit(caller, sub, arg, depo_id, now, phash)); // todo: all value*() must store proxy and main?

  //   // ignore await* sendBlock();
  //   [#Ok block_id];
  // };

  // public shared ({ caller }) func accn_revoke(args : [T.RevokeArg]) : async [T.RevokeRes] {
  //   let now = syncTrim();
  //   if (args.size() == 0) return [];
  //   if (not env.available) return [Error.text("Unavailable")];
  //   let arg = args[0];
  //   let proxy_a = { owner = caller; subaccount = arg.proxy_subaccount };
  //   if (not ICRC1L.validateAccount(proxy_a)) return [Error.text("Caller account is invalid")];
  //   if (not ICRC1L.validateAccount(arg.spender)) return [Error.text("Manager account is invalid")];
  //   let (self_p, self_sub) = (Principal.fromActor(Self), Subaccount.get(null));
  //   if (arg.spender.owner == self_p) return [Error.text("Cannot revoke this canister")];

  //   switch (checkMemo(arg.memo)) {
  //     case (#Err err) return [#Err err];
  //     case _ ();
  //   };
  //   var proxy_u = getUser(proxy_a.owner);
  //   let proxy_sub = Subaccount.get(proxy_a.subaccount);
  //   let (from_a, old_proxy_expiry) = switch (L.getRole(proxy_u, proxy_sub)) {
  //     case (#Proxy found) found;
  //     case (#Main _) return [#Err(#UnknownProxy)];
  //   };
  //   var from_u = getUser(from_a.owner);
  //   let from_sub = Subaccount.get(from_a.subaccount);
  //   var from_main = switch (L.getRole(from_u, from_sub)) {
  //     case (#Main found) found;
  //     case (#Proxy(of, _)) return [#Err(#SenderIsProxy { of })];
  //   };
  //   if (Text.size(from_main.name) == 0 or from_main.expires_at < now) return [#Err(#Unnamed)];

  //   let remaining = from_main.expires_at - now;
  //   if (remaining < env.name.duration.reduction) return [#Err(#InsufficientDuration { remaining })];

  //   let from_locker = L.getOwner(from_main.spenders, self_p);
  //   if (RBTree.size(from_locker) > 0) return [#Err(#Locked)];
  //   switch (arg.expiry_reduction) {
  //     case (?defined) if (defined != env.name.duration.reduction) return [#Err(#BadExpiryReduction { expected_expiry_reduction = env.name.duration.reduction })];
  //     case _ ();
  //   };
  //   var from_spender = L.getOwner(from_main.spenders, arg.spender.owner);
  //   let spender_sub = Subaccount.get(arg.spender.subaccount);
  //   let old_spender_expiry = switch (RBTree.get(from_spender, Blob.compare, spender_sub)) {
  //     case (?found) found;
  //     case _ return [#Err(#UnknownSpender)];
  //   };
  //   from_spender := RBTree.delete(from_spender, Blob.compare, spender_sub);
  //   let spenders = L.saveOwner(from_main.spenders, arg.spender.owner, from_spender);
  //   from_main := { from_main with spenders };

  //   let old_name_expiry = from_main.expires_at;
  //   let new_name_expiry = from_main.expires_at - env.name.duration.reduction;
  //   from_main := { from_main with expires_at = new_name_expiry };
  //   from_u := L.saveRole(from_u, from_sub, #Main from_main);
  //   saveUser(from_a.owner, from_u, ());

  //   switch old_spender_expiry {
  //     case (?found) spender_expiries := RBTree.delete(spender_expiries, L.compareManagerExpiry, (found, (from_a.owner, from_sub), (arg.spender.owner, spender_sub)));
  //     case _ ();
  //   };
  //   name_expiries := RBTree.delete(name_expiries, L.compareNameExpiry, (old_name_expiry, from_main.name));
  //   name_expiries := RBTree.insert(name_expiries, L.compareNameExpiry, (new_name_expiry, from_main.name), ());

  //   let (block_id, phash) = ArchiveL.getPhash(blocks);
  //   // newBlock(block_id, L.valueDeposit(caller, sub, arg, depo_id, now, phash)); // todo: all value*() must store proxy and main?

  //   // ignore await* sendBlock();
  //   [#Ok block_id];
  // };

  // public shared ({ caller }) func accn_transfer_from(args : [T.TransferFromArg]) : async [T.TransferFromRes] {
  //   let now = syncTrim();
  //   if (args.size() == 0) return [];
  //   if (not env.available) return [Error.text("Unavailable")];
  //   let arg = args[0];
  //   let spender_a = { owner = caller; subaccount = arg.spender_subaccount };
  //   if (not ICRC1L.validateAccount(spender_a)) return [Error.text("Caller account is invalid")];
  //   if (not ICRC1L.validateAccount(arg.proxy)) return [Error.text("Proxy account is invalid")];
  //   if (not ICRC1L.validateAccount(arg.to)) return [Error.text("Recipient account is invalid")];

  //   let spender_sub = Subaccount.get(spender_a.subaccount);
  //   let proxy_sub = Subaccount.get(arg.proxy.subaccount);
  //   if (arg.proxy.owner == spender_a.owner and proxy_sub == spender_sub) return [Error.text("Caller cannot spend")];
  //   let to_sub = Subaccount.get(arg.to.subaccount);
  //   if (arg.proxy.owner == arg.to.owner and proxy_sub == to_sub) return [Error.text("Proxy cannot receive")];

  //   switch (checkMemo(arg.memo)) {
  //     case (#Err err) return [#Err err];
  //     case _ ();
  //   };
  //   var proxy_u = getUser(arg.proxy.owner);
  //   let (from_a, old_proxy_expiry) = switch (L.getRole(proxy_u, proxy_sub)) {
  //     case (#Proxy found) found;
  //     case (#Main _) return [#Err(#UnknownProxy)];
  //   };
  //   let from_sub = Subaccount.get(from_a.subaccount);
  //   if (from_a.owner == spender_a.owner and from_sub == spender_sub) return [Error.text("Caller cannot send")];
  //   if (from_a.owner == arg.to.owner and from_sub == to_sub) return [Error.text("Self-transfer is not allowed")];

  //   var from_u = getUser(from_a.owner);
  //   var from_main = switch (L.getRole(from_u, from_sub)) {
  //     case (#Main found) found;
  //     case (#Proxy(of, _)) return [#Err(#SenderIsProxy { of })];
  //   };
  //   if (Text.size(from_main.name) == 0 or from_main.expires_at < now) return [#Err(#UnnamedSender)];
  //   let (self_p, self_sub) = (Principal.fromActor(Self), Subaccount.get(null));

  //   let remaining = from_main.expires_at - now;
  //   if (remaining < env.name.duration.reduction) return [#Err(#InsufficientDuration { remaining })];

  //   let from_locker = L.getOwner(from_main.spenders, self_p);
  //   if (RBTree.size(from_locker) > 0) return [#Err(#LockedSender)];
  //   switch (arg.expiry_reduction) {
  //     case (?defined) if (defined != env.name.duration.reduction) return [#Err(#BadExpiryReduction { expected_expiry_reduction = env.name.duration.reduction })];
  //     case _ ();
  //   };
  //   var from_spender = L.getOwner(from_main.spenders, spender_a.owner);
  //   let approval_expiry = switch (RBTree.get(from_spender, Blob.compare, spender_sub)) {
  //     case (?found) found;
  //     case _ return [#Err(#UnknownSpender)];
  //   };
  //   switch approval_expiry {
  //     case (?found) if (found < now) return [#Err(#UnknownSpender)];
  //     case _ ();
  //   };
  //   var to_u = getUser(arg.to.owner);
  //   var to_main = switch (L.getRole(to_u, to_sub)) {
  //     case (#Main found) found;
  //     case (#Proxy(of, _)) return [#Err(#RecipientIsProxy { of })];
  //   };
  //   if (Text.size(to_main.name) > 0 and to_main.expires_at > now) return [#Err(#NamedRecipient to_main)];
  //   var to_locker = L.getOwner(to_main.spenders, self_p);
  //   if (RBTree.size(to_locker) > 0) return [#Err(#LockedRecipient)];

  //   to_main := { to_main with name = from_main.name };
  //   to_main := {
  //     to_main with expires_at = from_main.expires_at - env.name.duration.reduction
  //   };
  //   to_u := L.saveRole(to_u, to_sub, #Main to_main);
  //   saveUser(arg.to.owner, to_u, ());

  //   names := RBTree.insert(names, Text.compare, to_main.name, (arg.to.owner, to_sub));
  //   name_expiries := RBTree.delete(name_expiries, L.compareNameExpiry, (from_main.expires_at, from_main.name));
  //   name_expiries := RBTree.insert(name_expiries, L.compareNameExpiry, (to_main.expires_at, to_main.name), ());

  //   from_u := getUser(from_a.owner);
  //   from_main := L.forceMain(L.getRole(from_u, from_sub));
  //   from_main := { from_main with name = "" };
  //   from_main := { from_main with expires_at = 0 };
  //   from_spender := RBTree.delete(from_spender, Blob.compare, spender_sub);
  //   let spenders = L.saveOwner(from_main.spenders, spender_a.owner, from_spender);
  //   from_main := { from_main with spenders };
  //   from_u := L.saveRole(from_u, from_sub, #Main from_main);
  //   saveUser(from_a.owner, from_u, ());

  //   switch approval_expiry {
  //     case (?found) spender_expiries := RBTree.delete(spender_expiries, L.compareManagerExpiry, (found, (from_a.owner, from_sub), (spender_a.owner, spender_sub)));
  //     case _ ();
  //   };
  //   let (block_id, phash) = ArchiveL.getPhash(blocks);
  //   // newBlock(block_id, L.valueDeposit(caller, sub, arg, depo_id, now, phash)); // todo: all value*() must store proxy and main?

  //   // ignore await* sendBlock();
  //   [#Ok block_id];
  // };

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
