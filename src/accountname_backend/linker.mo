module {
  public let ID = "lhuc4-nqaaa-aaaan-qz3gq-cai";
  public type Account = { owner : Principal; subaccount : ?Blob };
  public type Allowance1Arg = {
    token : Principal;
    main : Account;
    spender : Account;
  };
  public type AllowancesOfRes = {
    total : Nat;
    results : [TokenApproval];
    callbacks : [Callback_10];
  };
  public type Approve1Arg = {
    token : Principal;
    main_subaccount : ?Blob;
    memo : ?Blob;
    created_at : ?Nat64;
    amount : Nat;
    expected_allowance : ?Nat;
    expires_at : Nat64;
    spender : Account;
  };
  public type Approve1Err = {
    #GenericError : Type;
    #Duplicate : { of : Nat };
    #InsufficientLinkCredits;
    #ExpiresTooLate : { maximum_expiry : Nat64 };
    #CreatedInFuture : { time : Nat64 };
    #LinkAllowanceChanged : { allowance : Nat };
    #TooOld;
    #Expired : { time : Nat64 };
  };
  public type Approve1Res = { #Ok : { block_index : Nat }; #Err : Approve1Err };
  public type Callback = {
    args : SubaccountsOfArg;
    query_func : shared query SubaccountsOfArg -> async SubaccountsOfRes;
  };
  public type Callback_1 = {
    args : ProxySubsOfArg;
    query_func : shared query ProxySubsOfArg -> async ProxySubsOfRes;
  };
  public type Callback_10 = {
    args : [Allowance1Arg];
    query_func : shared query [Allowance1Arg] -> async AllowancesOfRes;
  };
  public type Callback_11 = {
    args : [Account];
    query_func : shared query [Account] -> async CreditsOfRes;
  };
  public type Callback_2 = {
    args : ProxyExpiriesArg;
    query_func : shared query ProxyExpiriesArg -> async ProxyExpiriesRes;
  };
  public type Callback_3 = {
    args : ProxiesOfArg;
    query_func : shared query ProxiesOfArg -> async ProxiesOfRes;
  };
  public type Callback_4 = {
    args : MainsOfArg;
    query_func : shared query MainsOfArg -> async MainsOfRes;
  };
  public type Callback_5 = {
    args : SubmainsOfArg;
    query_func : shared query SubmainsOfArg -> async SubmainsOfRes;
  };
  public type Callback_6 = {
    args : TokensOfArg;
    query_func : shared query TokensOfArg -> async TokensOfRes;
  };
  public type Callback_7 = {
    args : Filter1Arg;
    query_func : shared query Filter1Arg -> async Filter1Res;
  };
  public type Callback_8 = {
    args : SpendersOfArg;
    query_func : shared query SpendersOfArg -> async SpendersOfRes;
  };
  public type Callback_9 = {
    args : SpenderSubsOfArg;
    query_func : shared query SpenderSubsOfArg -> async SpenderSubsOfRes;
  };
  public type Canister = actor {
    delist_icrc1_token : shared Principal -> async Type__1;
    enlist_icrc1_token : shared Principal -> async Type__1;
    iilink_add_credits : shared TopupArg -> async TopupRes;
    iilink_credit_packages : shared query () -> async [CreditPackage];
    iilink_credits : shared query [Account] -> async CreditsOfRes;
    iilink_delegate : shared [DelegateArg] -> async [DelegateRes];
    iilink_icrc1_allowances : shared query [
      Allowance1Arg
    ] -> async AllowancesOfRes;
    iilink_icrc1_approve : shared [Approve1Arg] -> async [Approve1Res];
    iilink_icrc1_spender_subaccounts : shared query SpenderSubsOfArg -> async SpenderSubsOfRes;
    iilink_icrc1_spenders : shared query SpendersOfArg -> async SpendersOfRes;
    iilink_icrc1_sufficient_allowances : shared query Filter1Arg -> async Filter1Res;
    iilink_icrc1_tokens : shared query TokensOfArg -> async TokensOfRes;
    iilink_icrc1_transfer_from : shared TransferFrom1Arg -> async TransferFrom1Res;
    iilink_main_subaccounts : shared query SubmainsOfArg -> async SubmainsOfRes;
    iilink_mains : shared query MainsOfArg -> async MainsOfRes;
    iilink_proxies : shared query ProxiesOfArg -> async ProxiesOfRes;
    iilink_proxy_expiries : shared query [
      ProxyExpiriesArg
    ] -> async ProxyExpiriesRes;
    iilink_proxy_subaccounts : shared query ProxySubsOfArg -> async ProxySubsOfRes;
    iilink_service_provider : shared query () -> async Account;
    iilink_subaccounts : shared query SubaccountsOfArg -> async SubaccountsOfRes;
    iilink_undelegate : shared [UndelegateArg] -> async [UndelegateRes];
  };
  public type CreditPackage = {
    base : Nat;
    tcycles_fee_multiplier : Nat;
    bonus : Nat;
  };
  public type CreditsOfRes = {
    total : Nat;
    results : [Nat];
    callbacks : [Callback_11];
  };
  public type DelegateArg = {
    main_subaccount : ?Blob;
    memo : ?Blob;
    created_at : ?Nat64;
    proxy : Account;
    expires_at : Nat64;
  };
  public type DelegateErr = {
    #GenericError : Type;
    #Duplicate : { of : Nat };
    #InsufficientLinkCredits;
    #ExpiresTooLate : { maximum_expiry : Nat64 };
    #CreatedInFuture : { time : Nat64 };
    #TooOld;
    #Expired : { time : Nat64 };
  };
  public type DelegateRes = { #Ok : { block_index : Nat }; #Err : DelegateErr };
  public type Filter1Arg = {
    token : Principal;
    previous : ?Account;
    take : ?Nat;
    allowance : Nat;
    proxy : Account;
    spender : Account;
  };
  public type Filter1Res = {
    total : Nat;
    results : [FilteredAllowance];
    callbacks : [Callback_7];
  };
  public type FilteredAllowance = {
    main : Account;
    allowance : Nat;
    expires_at : Nat64;
  };
  public type MainsOfArg = {
    previous : ?Principal;
    take : ?Nat;
    proxy : Account;
  };
  public type MainsOfRes = {
    total : Nat;
    results : [Principal];
    callbacks : [Callback_4];
  };
  public type ProxiesOfArg = {
    previous : ?Principal;
    main : Account;
    take : ?Nat;
  };
  public type ProxiesOfRes = {
    total : Nat;
    results : [Principal];
    callbacks : [Callback_3];
  };
  public type ProxyExpiriesArg = { main : Account; proxy : Account };
  public type ProxyExpiriesRes = {
    total : Nat;
    results : [Nat64];
    callbacks : [Callback_2];
  };
  public type ProxySubsOfArg = {
    previous : ?Blob;
    proxy_owner : Principal;
    main : Account;
    take : ?Nat;
  };
  public type ProxySubsOfRes = {
    total : Nat;
    results : [Blob];
    callbacks : [Callback_1];
  };
  public type SpenderSubsOfArg = {
    previous : ?Blob;
    spender_owner : Principal;
    main : Account;
    take : ?Nat;
  };
  public type SpenderSubsOfRes = {
    total : Nat;
    results : [Blob];
    callbacks : [Callback_9];
  };
  public type SpendersOfArg = {
    previous : ?Principal;
    main : Account;
    take : ?Nat;
  };
  public type SpendersOfRes = {
    total : Nat;
    results : [Principal];
    callbacks : [Callback_8];
  };
  public type SubaccountsOfArg = {
    previous : ?Blob;
    take : ?Nat;
    main_owner : Principal;
  };
  public type SubaccountsOfRes = {
    total : Nat;
    results : [Blob];
    callbacks : [Callback];
  };
  public type SubmainsOfArg = {
    previous : ?Blob;
    take : ?Nat;
    main_owner : Principal;
    proxy : Account;
  };
  public type SubmainsOfRes = {
    total : Nat;
    results : [Blob];
    callbacks : [Callback_5];
  };
  public type TokenApproval = { allowance : Nat; expires_at : Nat64 };
  public type TokensOfArg = {
    previous : ?Principal;
    main : Account;
    take : ?Nat;
    spender : Account;
  };
  public type TokensOfRes = {
    total : Nat;
    results : [Principal];
    callbacks : [Callback_6];
  };
  public type TopupArg = {
    token : Principal;
    main : Account;
    memo : ?Blob;
    created_at : Nat64;
    payer_subaccount : ?Blob;
    amount : Nat;
  };
  public type TopupErr = {
    #GenericError : Type;
    #Duplicate : { of : Nat };
    #Locked : { until : Nat64 };
    #CreatedInFuture : { time : Nat64 };
    #InsufficientTokenAllowance : { allowance : Nat };
    #UnknownPrice : { xdr_permyriad_per_icp : Nat };
    #TooOld;
    #InsufficientTokenBalance : { balance : Nat };
  };
  public type TopupRes = { #Ok : { block_index : Nat }; #Err : TopupErr };
  public type TransferFrom1Arg = {
    to : Account;
    token : Principal;
    spender_subaccount : ?Blob;
    main : ?Account;
    memo : ?Blob;
    created_at : Nat64;
    proxy : Account;
    amount : Nat;
  };
  public type TransferFrom1Err = {
    #GenericError : Type;
    #Duplicate : { of : Nat };
    #NoEligibleMain : {
      maximum_allowance : { main : ?Account; available : Nat };
      maximum_balance : { main : ?Account; available : Nat };
    };
    #NoSufficientLinkAllowance : {
      maximum : { main : ?Account; available : Nat };
    };
    #InsufficientLinkCredits;
    #InsufficientLinkAllowance : { allowance : Nat };
    #Locked : { until : Nat64 };
    #CreatedInFuture : { time : Nat64 };
    #InsufficientTokenAllowance : { allowance : Nat };
    #UnknownProxy;
    #TooOld;
    #InsufficientTokenBalance : { balance : Nat };
  };
  public type TransferFrom1Res = {
    #Ok : { block_index : Nat; main : Account };
    #Err : TransferFrom1Err;
  };
  public type Type = { message : Text; error_code : Nat };
  public type Type__1 = { #Ok; #Err : Text };
  public type UndelegateArg = {
    main_subaccount : ?Blob;
    memo : ?Blob;
    proxy : Account;
  };
  public type UndelegateErr = {
    #GenericError : Type;
    #InsufficientLinkCredits;
    #UnknownProxy;
  };
  public type UndelegateRes = {
    #Ok : { block_index : Nat };
    #Err : UndelegateErr;
  };
};
