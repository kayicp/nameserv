clear
# mops test

rm -rf .dfx

echo "$(dfx identity use plug)"
# export DEFAULT_ACCOUNT_ID=$(dfx ledger account-id)
# echo "DEFAULT_ACCOUNT_ID: " $DEFAULT_ACCOUNT_ID
export PLUG_PRINCIPAL=$(dfx identity get-principal)

echo "$(dfx identity use default)"
export DEFAULT_ACCOUNT_ID=$(dfx ledger account-id)
echo "DEFAULT_ACCOUNT_ID: " $DEFAULT_ACCOUNT_ID
export DEFAULT_PRINCIPAL=$(dfx identity get-principal)


export INTERNET_ID="rdmx6-jaaaa-aaaaa-aaadq-cai"
export ICP_ID="ryjl3-tyaaa-aaaaa-aaaba-cai"
# export CKBTC_ID="mxzaz-hqaaa-aaaar-qaada-cai"
# export CKETH_ID="ss2fx-dyaaa-aaaar-qacoq-cai"
export TCYCLES_ID="um5iw-rqaaa-aaaaq-qaaba-cai"
export LINKER_ID="lhuc4-nqaaa-aaaan-qz3gq-cai"
export NAMER_ID="zyfw5-4qaaa-aaaac-qc7za-cai"
export FRONTEND="z7eqj-riaaa-aaaac-qc7zq-cai"
export CMC_ID="rkp4c-7iaaa-aaaaa-aaaca-cai"

# cmc = opt \"$CMC_ID\"
dfx deploy accountname_backend --no-wallet --specified-id $NAMER_ID --argument "(
  variant {
    Init = record {
      cmc = null;
      duration = record { 
        tx_window = 86_400_000_000_000;
				permitted_drift = 120_000_000_000; 
      };
      service_provider = principal \"$PLUG_PRINCIPAL\";
      name = record {
        duration = record {
          packages = vec {
            record { years_base = 1; months_bonus = 2 };
            record { years_base = 3; months_bonus = 12 };
            record { years_base = 5; months_bonus = 36 };
          };
          lock = 20_000_000_000;
          toll = 7_200_000_000_000;
          max_expiry = 2_592_000_000_000_000;
        };
        price_tiers = vec {
          record {
            length = record { min = 1; max = 1 };
            tcycles_fee_multiplier = 10_000_000;
          };
          record {
            length = record { min = 2; max = 2 };
            tcycles_fee_multiplier = 5_000_000;
          };
          record {
            length = record { min = 3; max = 3 };
            tcycles_fee_multiplier = 2_500_000;
          };
          record {
            length = record { min = 4; max = 4 };
            tcycles_fee_multiplier = 1_000_000;
          };
          record {
            length = record { min = 5; max = 5 };
            tcycles_fee_multiplier = 500_000;
          };
          record {
            length = record { min = 6; max = 6 };
            tcycles_fee_multiplier = 250_000;
          };
          record {
            length = record { min = 7; max = 7 };
            tcycles_fee_multiplier = 100_000;
          };
          record {
            length = record { min = 8; max = 8 };
            tcycles_fee_multiplier = 50_000;
          };
          record {
            length = record { min = 9; max = 9 };
            tcycles_fee_multiplier = 20_000;
          };
          record {
            length = record { min = 10; max = 19 };
            tcycles_fee_multiplier = 10_000;
          };
          record {
            length = record { min = 20; max = 32 };
            tcycles_fee_multiplier = 5_000;
          };
        };
      };
      memo_size = record { min = 1; max = 32 };
      max_take_value = 100;
      max_query_batch_size = 100;
      max_update_batch_size = 1;
      archive = record {
        standby = null;
        root = null;
        max_update_batch_size = 10;
        min_tcycles = 4;
      };
    }
  },
)"

dfx deploy accountname_frontend --no-wallet --specified-id $FRONTEND