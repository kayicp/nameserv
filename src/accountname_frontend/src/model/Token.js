import { idlFactory } from 'declarations/icp_token';
import { genActor } from '../../../util/js/actor';
import { Principal } from '@dfinity/principal';
import { shortPrincipal } from '../../../util/js/principal';
import { html } from 'lit-html';
import { nano2date } from '../../../util/js/bigint';

export default class Token {
	anon = null;
  wallet = null;

	name = null;
  symbol = null;
  decimals = null;
  power = null;
  fee = null;

	balance = 0n;
  allowance = 0n;
  expires_at = null;

	get_busy = false;
	busy = false;

	constructor(p_txt, wallet, symbol = null) {
		this.id = p_txt;
		this.id_p = Principal.fromText(this.id);
		this.wallet = wallet;
		this.notif = wallet.notif;
		this.symbol = symbol;
		this.get();
		// this.change('ryjl3-tyaaa-aaaaa-aaaba-cai'); // default to icp
	}

	// change(p_txt) {
	// 	this.id = p_txt;
	// 	this.id_p = Principal.fromText(this.id);
	// 	this.anon = null;
	// 	this.name = null;
	// 	this.symbol = null;
	// 	this.decimals = null;
	// 	this.power = null;
	// 	this.fee = null;
	// 	this.balance = 0n;
	// 	this.allowance = 0n;
	// 	this.expires_at = null;
	// 	this.get();
	// }

	render() {
		this.wallet.render();
	};

	async get() {
		this.get_busy = true;
		try {
			if (this.anon == null) this.anon = await genActor(idlFactory, this.id);
			if (this.power == null) {
				const [name, symbol, decimals, fee] = await Promise.all([
					this.anon.icrc1_name(),
					this.anon.icrc1_symbol(),
					this.anon.icrc1_decimals(),
					this.anon.icrc1_fee(),
				]);
				this.name = name;
				this.symbol = symbol;
				this.fee = fee;
				this.decimals = Number(decimals);
				this.power = BigInt(10 ** this.decimals);
			}
			this.render();
		} catch (cause) {
			this.get_busy = false;
			return this.notif.errorToast(`Token ${shortPrincipal(this.id_p)} Meta Failed`, cause);
		};
	}

	clean(n){
		const intPart = n / (this.power ?? 1n);
		const decPart = (n % (this.power ?? 1n)).toString().padStart(this.decimals ?? 1, '0');
		return `${intPart}.${decPart}`;
  }

	cleaner(n) {
    const intPart = n / (this.power ?? 1n);
    let decPart = (n % (this.power ?? 1n)).toString().padStart(this.decimals ?? 1, '0');
    
    // Remove trailing zeros from decimal part
    decPart = decPart.replace(/0+$/, '');
    
    // If the decimal part becomes empty, return just the integer part
    return decPart ? `${intPart}.${decPart}` : `${intPart}`;
	}

  raw(n_str) {
		let [intPart, decPart = ""] = n_str.split(".");
	
		// ensure we have only digits
		intPart = intPart || "0";
		decPart = decPart.replace(/\D/g, "");
	
		// truncate or pad to 8 decimal places
		decPart = decPart.padEnd(this.decimals, "0").slice(0, this.decimals);
	
		return BigInt(intPart + decPart);
	}

  // price(quote, base) {
  //   const res = this.raw(Number(quote) / Number(base));
  //   return this.cleaner(res);
  // }

	async approveAuto(amt_r, expiry) {
		await this.get();
		if (this.allowance >= amt_r && (this.expires_at == null || nano2date(this.expires_at) > new Date())) {
			this.notif.successToast(`Approve ${this.symbol} is sufficient`, `Approval skipped. You saved ${this.cleaner(this.fee)} ${this.symbol} in approval fee!`);
			return true;
		} else if (this.balance < this.fee) {
			this.notif.errorPopup(`Approve ${this.symbol} Error`, `You don't have enough balance to pay for the fee (${this.cleaner(this.fee)} ${this.symbol})`);
			return false;
		} else this.notif.infoToast(`${this.symbol} Allowance is insufficient`, `Approving...`);

		return await this._approve(amt_r, expiry);
	}

	async _approve(amt_r, expiry) {
		try {
			this.busy = true;
			this.render();
			const user = await genActor(idlFactory, this.id, this.wallet.agent);
			const res = await user.icrc2_approve({
				from_subaccount: [],
				amount: amt_r,
				spender: {
					owner: this.spender_p,
					subaccount: [],
				},
				expires_at: [expiry],
				fee: [this.fee],
				memo: [],
				created_at_time: [],
				expected_allowance: [],
			});
			this.busy = false;
			if ('Err' in res) {
				const title = `Approve ${this.symbol} Error`;
				let msg = JSON.stringify(res.Err);
				if ('GenericError' in res.Err) {
					msg = res.Err.GenericError.message;
				} else if ('InsufficientFunds' in res.Err) {
					msg = `You only have ${this.cleaner(res.Err.InsufficientFunds.balance)} ${this.symbol}. You need at least ${this.cleaner(this.fee)} ${this.symbol} (fee)`;
				}
				this.notif.errorPopup(title, msg);
				return false;
			} else {
				this.get();
				this.notif.successToast(`Approve ${this.symbol} OK`, `Block: ${res.Ok}`);
				return true;
			}
		} catch (cause) {
			this.busy = false;
			this.notif.errorPopup(`Approve ${this.symbol} Failed`, cause);
			return false;
		}
	}

	async approve(amt, expiry) {
		amt.trim();
		let amt_r = null
		try {
			amt_r = this.raw(amt);
			if (amt_r < 0n) return this.notif.errorPopup(`Approve Amount Error`, 'Amount must be positive')
		} catch (cause) {
			return this.notif.errorPopup(`Approve Amount Error`, cause)
		}

		this.notif.confirmPopup('Confirm approve allowance', html`
			<div class="space-y-2 text-xs text-slate-300">
				<div>
					<div class="text-slate-400">Amount to approve</div>
					<div class="font-mono text-slate-100">
						${this.cleaner(amt_r)} ${this.symbol}
					</div>
				</div><br>
	
				<div>
					<div class="text-slate-400">Approve fee</div>
					<div class="font-mono">
						${this.cleaner(this.fee)} ${this.symbol}
					</div>
				</div>
			</div>
		`, [
				{
					label: `Confirm allowance`,
					onClick: async () => this._approve(amt_r, expiry) }]);
  }

  async transfer(amt, to) {
		amt.trim();
		to.trim();
		let amt_r = null;
		try {
			amt_r = this.raw(amt) - this.fee;
			if (amt_r < 1n) return this.notif.errorPopup(`Transfer Amount Error`, `Amount must be larger than transfer fee (${this.cleaner(this.fee)} ${this.symbol})`)
		} catch (cause) {
			return this.notif.errorPopup(`Transfer Amount Error`, cause)
		}
		
		let to_p = null
		try {
			to_p = Principal.fromText(to);
		} catch (cause) {
			return this.notif.errorPopup(`Transfer Receiver Error`, cause)
		}

		this.notif.confirmPopup(
			`Confirm send from wallet`,
			html`
				<div class="space-y-2 text-xs text-slate-300">
					<div>
						<div class="text-slate-400">Amount to send</div>
						<div class="font-mono text-slate-100">
							${this.cleaner(amt_r)} ${this.symbol}
						</div>
					</div><br>
		
					<div>
						<div class="text-slate-400">Recipient address</div>
						<div class="font-mono break-all">
							${to}
						</div>
					</div><br>
		
					<div>
						<div class="text-slate-400">Transfer fee</div>
						<div class="font-mono">
							${this.cleaner(this.fee)} ${this.symbol}
						</div>
					</div><br>
		
					<div class="pt-1 border-t border-slate-700/60 mt-2">
						<div class="text-slate-400">Total</div>
						<div class="font-mono text-slate-100">
							${this.cleaner(amt_r + this.fee)} ${this.symbol}
						</div>
					</div>
				</div>
			`,
			[
				{
					label: `Confirm send`,
					onClick: async () => {
			try {
				this.busy = true;
				this.render();
				const user = await genActor(idlFactory, this.id, this.wallet.agent);
				const res = await user.icrc1_transfer({
					amount: amt_r,
					to: { owner: to_p, subaccount: [] },
					fee: [this.fee],
					memo: [],
					from_subaccount : [],
					created_at_time : [],
				})
				this.busy = false;
				if ('Err' in res) {
					const title = `Transfer ${this.symbol} Error`;
					let msg = JSON.stringify(res.Err);
					if ('GenericError' in res.Err) {
						msg = res.Err.GenericError.message;
					} else if ('InsufficientFunds' in res.Err) {
						msg = `You only have ${this.cleaner(res.Err.InsufficientFunds.balance)} ${this.symbol}. You need at least ${this.cleaner(amt_r + this.fee)} ${this.symbol} (amount + fee)`
					}
					this.notif.errorPopup(title, msg);
				} else {
					this.get();
					this.notif.successToast(`Transfer ${this.symbol} OK`, `Block: ${res.Ok}`);
				}
			} catch (cause) {
				this.busy = false;
				this.notif.errorPopup(`Transfer ${this.symbol} Failed`, cause);
			}
		} }])
  }
} 