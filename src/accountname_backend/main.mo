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
      duration_package = [
        { yr = 1; mos_bonus = 2 },
        { yr = 3; mos_bonus = 12 },
        { yr = 5; mos_bonus = 24 },
      ];
      duration_reduction = Time64.HOURS(12);
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

  var names = RBTree.empty<Text, (Principal, Blob)>();
  var name_expiries = RBTree.empty<(Nat64, Text), ()>();

  var register_dedupes = RBTree.empty<(Principal, T.RegisterArg), Nat>();
  var approve_dedupes = RBTree.empty<(Principal, T.ApproveArg), Nat>();

  public shared ({ caller }) func accn_register(arg : T.RegisterArg) : async T.RegisterRes {
    let now = syncTrim();
    if (not env.available) return Error.text("Unavailable");
    let proxy_a = { owner = caller; subaccount = arg.subaccount };
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
      case _ return Error.text("Caller is not proxied to a main");
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
    if (accl_credits == 0) return Error.text("This canister has insufficient credits to spend caller's link");
    if (icp_bal < amount_and_fee) return #Err(#InsufficientTokenBalance { balance = icp_bal });
    if (icp_aprv.allowance < amount_and_fee) return #Err(#InsufficientTokenAllowance icp_aprv);
    switch (icp_aprv.expires_at) {
      case (?found) if (found < now) return #Err(#InsufficientTokenAllowance { allowance = 0 });
      case _ ();
    };
    var proxy_u = getUser(proxy_a.owner);
    let proxy_sub = Subaccount.get(proxy_a.subaccount);
    let (old_main_a, old_proxy_expiry) = switch (L.getRole(proxy_u, proxy_sub)) {
      case (#Main m_u) if (L.isMain(m_u)) return Error.text("Caller must be a proxy, not a main") else (new_main_a, 0 : Nat64);
      case (#Proxy old) old;
    };
    var main_u = getUser(new_main_a.owner);
    let main_sub = Subaccount.get(new_main_a.subaccount);
    var main = switch (L.getRole(main_u, main_sub)) {
      case (#Main found) found;
      case _ return Error.text("Caller's linked main is a proxy here, instead of a main too");
    };
    let block_id = 0;
    #Ok block_id;
  };

  public shared ({ caller }) func accn_transfer(args : [T.TransferArg]) : async [T.TransferRes] {
    let block_id = 0;
    [#Ok block_id];
  };

  public shared ({ caller }) func accn_approve(args : [T.ApproveArg]) : async [T.ApproveRes] {
    let block_id = 0;
    [#Ok block_id];
  };

  public shared ({ caller }) func accn_transfer_from(args : [T.TransferFromArg]) : async [T.TransferFromRes] {
    let block_id = 0;
    [#Ok block_id];
  };

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
