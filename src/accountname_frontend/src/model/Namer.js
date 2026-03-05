
import { genActor } from '../../../util/js/actor';
import { html } from 'lit-html';
import { shortPrincipal } from '../../../util/js/principal';
import { idlFactory } from 'declarations/accountname_backend';
import { Principal } from '@dfinity/principal';
import { AccountIdentifier } from '@dfinity/ledger-icp';
import { nano2date } from '../../../util/js/bigint';

// Namer.js
export default class Namer {
	service_provider = null;
	get_busy = false;
	check_busy = false;
	busy = false;
	mains = new Map();

	length_tiers = [];
	duration_packages = [];

	name_str = '';
	name_str_sub = '';
	selected_renew_main_p = null;
	selected_register_main_p = null;
	name_a = null;
	pay_with_icp = false;
	selected_year_idx = 0;

	constructor(p_txt, wallet, icp_token, tcycles_token) {
		this.id = p_txt;
		this.id_p = Principal.fromText(p_txt);
		this.wallet = wallet;
		this.notif = wallet.notif;
		this.icp_token = icp_token;
		this.tcycles_token = tcycles_token;
		this.anon = null;
		this.get();
	}

	render() {
		this.wallet.render();
	}

	async get() {
		this.get_busy = true;
		try {
			if (this.anon == null) this.anon = await genActor(idlFactory, this.id);
			if (this.service_provider == null) {
				const [service_provider, length_tiers, duration_packages] = await Promise.all([
					this.anon.icrc_ans_service_provider(),
					this.anon.icrc_ans_length_tiers(),
					this.anon.icrc_ans_duration_packages(),
				]);
				this.service_provider = service_provider;
				this.length_tiers = length_tiers;
				this.duration_packages = duration_packages;
				this.render();
			}
		} catch (cause) {
			this.get_busy = false;
			this.render();
			return this.notif.errorToast(`Namer ${shortPrincipal(this.id_p)} Meta Failed`, cause);
		}
		const proxy_a = { owner: this.wallet.principal, subaccount: [] };
		if (proxy_a.owner == null) { this.get_busy = false; return; }

		const mains = new Map();
		let prev_main = [];
		let name_args = [];
		try {
			while (true) {
				const mains_res = await this.anon.icrc_ans_mains({ proxy: proxy_a, previous: prev_main, take: [] });
				if (mains_res.results.length == 0) break;
				for (const main_p of mains_res.results) {
					prev_main = [main_p];
					const main_p_txt = main_p.toText();
					mains.set(main_p_txt, { p: main_p, name: '', expires_at: 0n });
					name_args.push({ owner: main_p, subaccount: [] });
				}
			}
		} catch (cause) {
			this.notif.errorToast('Failed to load principals', cause);
		}
		try {
			while (name_args.length > 0) {
				const args = name_args.slice(0, 100);
				name_args.splice(0, 100);
				const names_res = await this.anon.icrc_ans_names(args);
				if (names_res.results.length == 0) break;
				for (let i = 0; i < names_res.results.length; i++) {
					const arg = args[i];
					const res = names_res.results[i];
					const main = mains.get(arg.owner.toText());
					main.name = res.name;
					main.expires_at = res.expires_at;
				}
			}
		} catch (cause) {
			this.notif.errorToast('Failed to load names', cause);
		}
		this.get_busy = false;
		this.mains.clear();
		this.mains = mains;
		this.render();
	}

	async validateName(getLink) {
		this.selected_renew_main_p = null;
		this.name_a = null;
		this.name_str_sub = '';
		this.name_str = this.name_str.trim();

		if (this.name_str.length == 0) {
			this.name_str_sub = 'Error: Name cannot be empty';
			return this.render();
		}
		if (this.length_tiers.length == 0) {
			this.name_str_sub = 'Error: No max length configured';
			return this.render();
		}
		const max_len = this.length_tiers[this.length_tiers.length - 1].max;
		if (this.name_str.length > max_len) {
			this.name_str_sub = `Error: Too long — max ${max_len} characters`;
			return this.render();
		}

		const chars = 'abcdefghijklmnopqrstuvwxyz';
		const nums = '0123456789';
		let lastUnderscore = false;

		for (let i = 0; i < this.name_str.length; i++) {
			const c = this.name_str[i];
			if (chars.includes(c)) { lastUnderscore = false; continue; }
			if (i === 0) {
				this.name_str_sub = 'Error: Must start with a lowercase letter (a–z)';
				return this.render();
			}
			if (nums.includes(c)) { lastUnderscore = false; continue; }
			if (c === '_') {
				if (lastUnderscore) {
					this.name_str_sub = 'Error: No consecutive underscores allowed';
					return this.render();
				}
				lastUnderscore = true;
				continue;
			}
			this.name_str_sub = 'Error: Only lowercase letters, digits, and underscores allowed';
			return this.render();
		}
		if (lastUnderscore) {
			this.name_str_sub = 'Error: Cannot end with an underscore';
			return this.render();
		}

		this.check_busy = true;
		this.name_str_sub = 'Checking availability…';
		this.render();

		try {
			const accounts_res = await this.anon.icrc_ans_accounts([this.name_str]);
			const acct_opt = accounts_res.results[0];
			const main_a = acct_opt[0];
			if (main_a == null) {
				this.name_str_sub = 'Ok: Name is available';
			} else {
				try {
					const names_res = await this.anon.icrc_ans_names([main_a]);
					const main = names_res.results[0];
					const name_expiry = nano2date(main.expires_at);
					const now = new Date();
					if (main.name.length == 0 || name_expiry < now) {
						this.name_str_sub = 'Ok: Name is available';
					} else if (main.name == this.name_str) {
						this.name_a = main_a;
						const half_day = 12 * 60 * 60 * 1000;
						const diff = name_expiry.getTime() - now.getTime();
						const isYours = this.mains.has(main_a.owner.toText());
						const expiryStr = diff < half_day ? name_expiry.toLocaleTimeString() : name_expiry.toLocaleDateString();
						const subaccountNote = main_a.subaccount.length > 0 ? ' (via subaccount)' : '';
						this.name_str_sub = `${isYours ? 'Ok: You' : 'Someone else'} (${shortPrincipal(main_a.owner)})${subaccountNote} own this name until ${expiryStr}`;
					} else {
						this.name_str_sub = 'Ok: Name is available';
					}
				} catch (cause) {
					const message = cause instanceof Error ? cause.message : String(cause);
					this.name_str_sub = `Error: Integrity check failed — ${message}`;
				}
			}
			if (this.name_str_sub.startsWith('Ok: You') && main_a.subaccount.length == 0) {
				this.selected_renew_main_p = main_a.owner;
				if (getLink) getLink(main_a.owner, this.pay_with_icp);
			}
			this.name_a = main_a;
		} catch (cause) {
			const message = cause instanceof Error ? cause.message : String(cause);
			this.name_str_sub = `Error: Lookup failed — ${message}`;
		}
		this.check_busy = false;
		this.render();
	}

	async register(amount, token, main_p, total_days) {
		this.notif.confirmPopup(
			'Confirm name registration',
			html`
				<div class="space-y-3 text-xs text-slate-300">
					<div>
						<div class="text-slate-400">Name</div>
						<div class="font-mono text-slate-100">${this.name_str}</div>
					</div>
					<div>
						<div class="text-slate-400">Linked principal</div>
						<div class="font-mono text-slate-100">${shortPrincipal(main_p)}</div>
					</div>
					<div>
						<div class="text-slate-400">Duration</div>
						<div class="text-slate-100">${total_days} days</div>
					</div>
					<div class="pt-2 border-t border-slate-700/60">
						<div class="text-slate-400">Cost</div>
						<div class="font-mono text-slate-100">${token.cleaner(amount)} ${token.symbol}</div>
					</div>
				</div>
			`,
			[{
				label: 'Confirm',
				onClick: async () => {
					this.busy = true;
					this.render();
					try {
						const user = await genActor(idlFactory, this.id, this.wallet.agent);
						const res = await user.icrc_ans_proxy_register({
							proxy_subaccount: [],
							name: this.name_str,
							amount,
							token: token.id_p,
							main: [{ owner: main_p, subaccount: [] }],
							memo: [],
							created_at: [],
						});
						this.busy = false;
						this.render();
						if ('Err' in res) {
							let msg = JSON.stringify(res.Err);
							if ('GenericError' in res.Err) msg = res.Err.GenericError.message;
							this.notif.errorPopup('Registration Error', msg);
						} else {
							this.name_str_sub = '';
							this.get();
							this.notif.successToast('Registration OK', res.Ok);
						}
					} catch (cause) {
						this.busy = false;
						this.render();
						this.notif.errorToast('Registration Failed', cause);
					}
				}
			}]
		);
	}
}