import { idlFactory } from 'declarations/accountlinker_backend';
import { Principal } from '@dfinity/principal';
import { shortPrincipal } from '../../../util/js/principal';
import Token from './Token';
import { genActor } from '../../../util/js/actor';
import { html } from 'lit-html';
import { duration2nano } from '../../../util/js/duration';
import { date2nano } from '../../../util/js/bigint';

export default class Linker {
	service_provider = null;
	proxies = new Map();
	get_busy = false;

	busy = false;
	app_p_str = '';
	user_p_str = '';
	amount_str = '';
	icrc1_p_str = 'ryjl3-tyaaa-aaaaa-aaaba-cai';
	new_icrc1_p_str = '';
	to_p_str = '';
	expiry_amount_str = '1';
	expiry_unit_str = 'seconds';

	constructor(p_txt, wallet, icrc1s) {
		this.id = p_txt;
		this.id_p = Principal.fromText(p_txt);
		this.wallet = wallet;
		this.notif = wallet.notif;
		this.icrc1s = icrc1s;
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
				const [service_provider, credit_packages] = await Promise.all([
					this.anon.iilink_service_provider(),
					this.anon.iilink_credit_packages(),
				]);
				this.service_provider = service_provider;
				this.credit_packages = credit_packages;
				this.render();
			}
		} catch (cause) {
			this.get_busy = false;
			return this.notif.errorToast(`Linker ${shortPrincipal(this.id_p)} Meta Failed`, cause);
		}
		const main_a = { owner: this.wallet.principal, subaccount: [] };
		if (main_a.owner == null) return;
		try {
			const credits = await this.anon.iilink_credits([main_a]);
			this.credits = credits.results[0];
			this.render();
		} catch (cause) {
			this.get_busy = false;
			return this.notif.errorToast(`Credit Failed`, cause);
		}

		const proxies = new Map();
		let prev_proxy = [];
		let approval_args = [];
		try {
			while (true) {
				const proxies_res = await this.anon.iilink_icrc1_proxies({ main : main_a, previous: prev_proxy, take: [] });
				
				if (proxies_res.results.length == 0) break;
				for (const proxy_p of proxies_res.results) {
					prev_proxy = [proxy_p];
					const proxy_p_txt = proxy_p.toText();
					proxies.set(proxy_p_txt, {
						p: proxy_p,
						spenders: new Map(),
					});
					let prev_spender = [];
					try {
						const proxy_a = { owner: proxy_p, subaccount: [] };
						while (true) {
							const spenders_res = await this.anon.iilink_icrc1_spenders({ proxy: proxy_a, previous: prev_spender, take: [] });

							if (spenders_res.results.length == 0) break;
							for (const spender_p of spenders_res.results) {
								prev_spender = [spender_p];
								const spender_p_txt = spender_p.toText();
								proxies.get(proxy_p_txt)
									.spenders.set(spender_p_txt, {
										p: spender_p,
										tokens: new Map(),
									});
								let prev_token = [];
								try {
									const spender_a = { owner: spender_p, subaccount: [] };
									while (true) {
										const tokens_res = await this.anon.iilink_icrc1_tokens({ proxy: proxy_a, spender: spender_a, previous: prev_token, take: [] });
										if (tokens_res.results.length == 0) break;
										for (const token_p of tokens_res.results) {
											prev_token = [token_p];
											const token_p_txt = token_p.toText();
											if (!this.icrc1s.has(token_p_txt)) this.icrc1s.set(token_p_txt, new Token(token_p_txt, this.wallet, this.id));

											proxies.get(proxy_p_txt)
												.spenders.get(spender_p_txt)
												.tokens.set(token_p_txt, {
													allowance: 0n,
													expires_at: 0n,
													nonce: []
												})
											approval_args.push({ proxy: proxy_a, spender: spender_a, token: token_p, main: main_a });
										}
									}
								} catch (cause) {
									this.notif.errorToast(`Get icrc1 spenders failed ${{ prev_spender }} of proxy: ${shortPrincipal(proxy_p)}, spender: ${shortPrincipal(spender_p)}`, cause);
								}
							}
						}
					} catch (cause) {
						this.notif.errorToast(`Get icrc1 spenders failed ${{ prev_spender }} of proxy: ${shortPrincipal(proxy_p)}`, cause);
					}
				}
			}
		} catch (cause) {
			this.notif.errorToast(`Get icrc1 proxies failed ${{ prev_proxy }}`, cause);
		}
		try {
			while (approval_args.length > 0) {
				const args = approval_args.slice(0, 100);
				approval_args.splice(0, 100);
				const approval_res = await this.anon.iilink_icrc1_allowances(args);
				if (approval_res.results == 0) break;
				for (let i = 0; i < approval_res.results.length; i++) {
					const arg = args[i];
					const res = approval_res.results[i];
					const proxy = proxies.get(arg.proxy.owner.toText());
					const spender = proxy.spenders.get(arg.spender.owner.toText());
					const token = spender.tokens.get(arg.token.toText());
					token.allowance = res.allowance;
					token.expires_at = res.expires_at;
					token.nonce = res.nonce;
				}
			}
		} catch (cause) {
			this.notif.errorToast(`Get icrc1 links failed`, cause);
		}
		this.get_busy = false;
		this.proxies.clear();
		this.proxies = proxies;
		this.render();
	};

	async _approve(title, proxy_p, spender_p, token, amt_r, expiry_r) {
		this.busy = true;
		this.render();
		try {
			const user = await genActor(idlFactory, this.id, this.wallet.agent);
			const [res] = await user.iilink_icrc1_approve([{
				main_subaccount: [],
				proxy: { owner: proxy_p, subaccount: [] },
				spender: { owner: spender_p, subaccount: [] },
				token: token.id_p,
				amount: amt_r,
				expires_at: expiry_r,
				created_at: [],
				expected_allowance: [],
				memo: [],
			}])
			this.busy = false;
			if ('Err' in res) {
				let msg = JSON.stringify(res.Err);
				if ('GenericError' in res.Err) {
					msg = res.Err.GenericError.message;
				};
				this.notif.errorPopup(`${title} Error`, msg);						
			} else {
				window.close();
				this.get();
				token.get();
				this.notif.successToast(`${title} OK`, `Block: ${res.Ok}`);
			}
		} catch (cause) {
			this.busy = false;
			this.notif.errorToast(`${title} Failed`, cause);
		}
	}

	async approve() {
		this.amount_str.trim();
		this.user_p_str.trim();
		this.app_p_str.trim();
		const token = this.icrc1s.get(this.icrc1_p_str);

		let amt_r = null;
		try {
			amt_r = token.raw(this.amount_str);
			if (amt_r < 1n) return this.notif.errorPopup(`${token.symbol} Linker Amount Error`, 'Amount must be larger than 0 (zero)')
			this.amount_str = token.cleaner(amt_r);
		} catch (cause) {
			return this.notif.errorPopup(`New Link: Amount Error`, cause)
		}
		let proxy_p = null
		try {
			proxy_p = Principal.fromText(this.user_p_str);
		} catch (cause) {
			return this.notif.errorPopup(`New Link: App's User Principal Error`, cause)
		}
		let spender_p = null
		try {
			spender_p = Principal.fromText(this.app_p_str);
		} catch (cause) {
			return this.notif.errorPopup(`New Link: App's Principal Error`, cause)
		}
		this.notif.confirmPopup(
			`Confirm new app link to your iilink`,
			html`
				<div class="space-y-2 text-xs text-slate-300">
					<div>
						<div class="text-slate-400">App backend (canister ID)</div>
						<div class="font-mono break-all">
							${this.app_p_str}
						</div>
					</div><br>
					
					<div>
						<div class="text-slate-400">User principal ID</div>
						<div class="font-mono break-all">
							${this.user_p_str}
						</div>
					</div><br>
		
					<div>
						<div class="text-slate-400">Spending limit from your iilink</div>
						<div class="font-mono text-slate-100">
							${token.cleaner(amt_r)} ${token.symbol}
						</div>
					</div><br>
		
					<div>
						<div class="text-slate-400">
							Expires
							<span class="text-slate-500">(approx.)</span>
						</div>
						<div class="font-mono">
							${this.expiry_amount_str} ${this.expiry_unit_str} from now
						</div>
					</div><br>
		
					<div class="pt-1 border-t border-slate-700/60 mt-2">
						<div class="text-slate-400">Link cost</div>
						<div class="font-mono text-slate-100">
							1 credit
						</div>
					</div>
				</div>
			`,
			[
				{
					label: `Confirm app link`,
					onClick: () => this._approve('Create Link', proxy_p, spender_p, token, amt_r, date2nano() + duration2nano(this.expiry_amount_str, this.expiry_unit_str))
		}]);
	}

	async revoke(proxy, spender, token_p_str){
		const token = this.icrc1s.get(token_p_str);
		let proxy_p = null
		try {
			proxy_p = Principal.fromText(proxy);
		} catch (cause) {
			return this.notif.errorPopup(`Unlink: App's User Principal Error`, cause)
		}
		let spender_p = null
		try {
			spender_p = Principal.fromText(spender);
		} catch (cause) {
			return this.notif.errorPopup(`Unlink: App's Principal Error`, cause)
		}
		this.notif.confirmPopup(
			`Confirm unlink the app?`,
			html`
				<div class="space-y-2 text-xs text-slate-300">
					<div>
						<div class="text-slate-400">App backend (canister ID)</div>
						<div class="font-mono break-all">
							${spender}
						</div>
					</div><br>

					<div>
						<div class="text-slate-400">User principal ID</div>
						<div class="font-mono break-all">
							${proxy}
						</div>
					</div><br>
		
					<div class="pt-1 border-t border-slate-700/60 mt-2">
						<div class="text-slate-400">
							Effect
						</div>
						<div class="text-slate-300">
							This app will no longer be able to spend ${token.symbol} from your iilink
							for this user principal.
						</div>
					</div><br>
		
					<div>
						<div class="text-slate-400">Unlink cost</div>
						<div class="font-mono text-slate-100">
							1 credit
						</div>
					</div>
				</div>
			`,
			[
				{
					label: 'Confirm unlink',
					onClick: () => this._approve('Unlink', proxy_p, spender_p, token, 0n, 0n)
		}])
	}

	async topup(credit_amount, pay_amount, token) {
		this.notif.confirmPopup(
			`Confirm purchase ${credit_amount} credits?`,
			html`
				<div class="space-y-2 text-xs text-slate-300">
					<div>
						<div class="text-slate-400">Amount</div>
						<div class="font-mono break-all">
							${token.cleaner(pay_amount)} ${token.symbol}
						</div>
					</div><br>
		
					<div>
						<div class="text-slate-400">
							Possible approve fee
							<span class="text-slate-500">(only if a new approval is needed)</span>
						</div>
						<div class="font-mono">
							${token.cleaner(token.fee)} ${token.symbol}
						</div>
					</div><br>

					<div>
						<div class="text-slate-400">Transfer fee</div>
						<div class="font-mono">
							${token.cleaner(token.fee)} ${token.symbol}
						</div>
					</div>

					<div class="pt-1 border-t border-slate-700/60 mt-2">
						<div class="text-slate-400">Maximum total</div>
						<div class="font-mono text-slate-100">
							${token.cleaner(pay_amount + token.fee + token.fee)} ${token.symbol}
						</div>
					</div>
					<br>
					<div>
						<div class="text-slate-400 italic">Credits never expire</div>
					</div>
				</div>
			`,
			[
				{
					label: `Confirm & pay`,
					onClick: async () => {
						try {
							this.busy = true;
							this.render();
							const user = await genActor(idlFactory, this.id, this.wallet.agent);
							if (await token.approveAuto(pay_amount + token.fee, date2nano() + duration2nano('1', 'minutes')) == false) return;
							const res = await user.iilink_add_credits({
								main_subaccount: [],
								amount: pay_amount,
								token: token.id_p,
								memo: [],
								created_at: [], 
							});
							this.busy = false;
							if ('Err' in res) {
								const title = `Transfer ${token.symbol} Error`;
								let msg = JSON.stringify(res.Err);
								if ('GenericError' in res.Err) {
									msg = res.Err.GenericError.message;
								}
								this.notif.errorPopup(title, msg);
							} else {
								this.get();
								token.get();
								this.notif.successToast(`Topup credits OK`, `Block: ${res.Ok}`);
							}
						} catch (cause) {
							this.busy = false;
							this.notif.errorPopup(`Topup credits Failed`, cause);
						}
					}
		}]);
	}
}