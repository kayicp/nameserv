
import { genActor } from '../../../util/js/actor';
import { html } from 'lit-html';
import { shortPrincipal } from '../../../util/js/principal';
import { idlFactory } from 'declarations/accountname_backend';
import { Principal } from '@dfinity/principal';
import { AccountIdentifier } from '@dfinity/ledger-icp';
import { nano2date } from '../../../util/js/bigint';

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
	selected_year_idx = 0;
	selected_renew_main_p = null;
	selected_register_main_p = null;
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
			return this.notif.errorToast(`Namer ${shortPrincipal(this.id_p)} Meta Failed`, cause);
		}
		const proxy_a = { owner: this.wallet.principal, subaccount: [] };
		if (proxy_a.owner == null) return this.get_busy = false;

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
					mains.set(main_p_txt, {
						p: main_p,
						name: '',
						expires_at: 0n,
					});
					name_args.push({ owner: main_p, subaccount: [] });
				}
			}
		} catch (cause) {
			this.notif.errorToast(`Get mains failed ${{ prev_main }}`, cause);
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
			this.notif.errorToast(`Get names failed`, cause);
		}
		this.get_busy = false;
		this.mains.clear();
		this.mains = mains;
		this.render();
	};

	async validateName(getLink) {
		this.selected_renew_main_p = null;
		this.name_str_sub = '';
    this.name_str = this.name_str.trim();
    if (this.name_str.length == 0) {
			this.name_str_sub = 'Error: Name cannot be empty';
			return this.render();
		}
    if (this.length_tiers.length == 0) {
			this.name_str_sub = 'Error: No max length';
			return this.render();
		};
    const max_len = this.length_tiers[this.length_tiers.length - 1].max;
    if (this.name_str.length > max_len) {
			this.name_str_sub = `Error: Too long. Max length: ${max_len}`;
			return this.render();
		} 

    const chars = 'abcdefghijklmnopqrstuvwxyz';
    const nums = '0123456789';
    let lastUnderscore = false;

    for (let i = 0; i < this.name_str.length; i++) {
			const c = this.name_str[i];
			if (chars.includes(c)) {
				lastUnderscore = false;
				continue;
			}
			if (i === 0) {
				this.name_str_sub = 'Error: First character must be small alphabets (a-z)';
				return this.render();
			}
			if (nums.includes(c)) {
				lastUnderscore = false;
				continue;
			}
			if (c === '_') {
				if (lastUnderscore) {
					this.name_str_sub = 'Error: Consecutive underscores are not allowed';
					return this.render();
				}
				lastUnderscore = true;
				continue;
			}
			this.name_str_sub = 'Error: Only small alphabets (a-z), numbers (0-9), and underscores (_) are allowed';
			return this.render();
    }
    if (lastUnderscore) {
			this.name_str_sub = 'Error: Name cannot end with an underscore';
			return this.render();
    }
		this.check_busy = true;
		this.name_str_sub = 'Fetching the name owner...';
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
					} else {
						if (main.name == this.name_str) {
							const half_day = 12 * 60 * 60 * 1000; 
							const diff = name_expiry.getTime() - now.getTime();
							this.name_str_sub = `${this.mains.has(main_a.owner.toText())? 'Ok: You' : 'Someone else'} (${shortPrincipal(main_a.owner)}) ${main_a.subaccount.length == 0? '' : `(by a subaccount)`} own this name until ${diff < half_day? name_expiry.toLocaleTimeString() : name_expiry.toLocaleDateString()}`;
						} else {
							this.name_str_sub = 'Ok: Name is available';
						}
					};
				} catch (cause) {
					const message = cause instanceof Error ? cause.message : String(cause);
					this.name_str_sub = `Error: Integrity check failed - ${message}`;			
				}
			}
			if (this.name_str_sub.startsWith('Ok: You') && main_a.subaccount.length == 0) {
				this.selected_renew_main_p = main_a.owner;
				getLink(main_a.owner, this.pay_with_icp);
			};
		} catch (cause) {
			const message = cause instanceof Error ? cause.message : String(cause);
			this.name_str_sub = `Error: Fetching name owner failed - ${message}`;
		}
		this.check_busy = false;
		this.render();
	}

	async register(amount, token, main_p, total_days) {
    this.notif.confirmPopup(
        'Confirm register name',
        html`
            <div class="space-y-2 text-sm">
                <div class="flex justify-between gap-4">
                    <span class="text-slate-400">Name</span>
                    <span class="font-mono text-slate-100 break-all text-right">${this.name_str}</span>
                </div>
                <div class="flex justify-between gap-4">
                    <span class="text-slate-400">Main</span>
                    <span class="font-mono text-slate-100 text-xs">${shortPrincipal(main_p)}</span>
                </div>
                <div class="flex justify-between gap-4">
                    <span class="text-slate-400">Duration</span>
                    <span class="text-slate-100">${total_days} days</span>
                </div>
                <div class="flex justify-between gap-4 pt-2 border-t border-slate-700/50">
                    <span class="text-slate-400">Cost</span>
                    <span class="font-mono text-slate-100">${token.cleaner(amount)} ${token.symbol}</span>
                </div>
            </div>
        `,
        [{
					label: 'Confirm register',
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
						if ('Err' in res) {
							let msg = JSON.stringify(res.Err);
							if ('GenericError' in res.Err) {
								msg = res.Err.GenericError.message;
							};
							this.notif.errorPopup(`Register Error`, msg);
						} else {
							this.name_str_sub = '';
							this.get();
							this.notif.successToast('Register OK', res.Ok);
						}
					} catch (cause) {
						this.busy = false;
						this.notif.errorToast(`Register Failed`, cause);
					}
				}
			}])
	}
};