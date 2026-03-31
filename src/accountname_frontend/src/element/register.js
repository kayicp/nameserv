import { html } from 'lit-html';
import { shortPrincipal } from '../../../util/js/principal';
import { nano2date } from '../../../util/js/bigint';
import { duration, timeLeft } from '../../../util/js/duration';
import { Principal } from '@dfinity/principal';
import CMC from '../model/CMC';

const network = process.env.DFX_NETWORK;
const iilink_origin =
  network === 'ic'
		? 'https://loxja-3yaaa-aaaan-qz3ha-cai.icp0.io' // Mainnet
    : 'http://loxja-3yaaa-aaaan-qz3ha-cai.localhost:8080'; // Local

// register.js
export default class Register {
	static PATH = '/register';

	selected_duration_idx = 0;
	selected_main_txt = null;

	constructor(namer, linker) {
		this.namer = namer;
		this.icp_token = namer.icp_token;
		this.tcycles_token = namer.tcycles_token;
		this.wallet = namer.wallet;
		this.notif = namer.notif;
		this.linker = linker;
		this.cmc = new CMC(this.wallet);

		this.button = html`
			<button
				class="inline-flex items-center px-2 py-1 text-xs rounded-md font-medium bg-green-800 hover:bg-green-700 text-slate-100 ring-1 ring-slate-700 transition-colors"
				@click=${(e) => {
					e.preventDefault();
					if (window.location.pathname.startsWith(Register.PATH)) return;
					history.pushState({}, '', Register.PATH);
					window.dispatchEvent(new PopStateEvent('popstate'));
				}}>Register</button>
		`;

		window.addEventListener('message', (e) => {
			if (e.data?.type === 'iilink-done') {
				this._refresh();
				this.wallet.render();
			}
		});
	}

	/* ------------------------------------------------------------------ */
	/*  Helpers                                                           */
	/* ------------------------------------------------------------------ */

	_resetForm() {
		this.namer.name_str_sub = '';
		this.namer.name_a = null;
		this.selected_main_txt = null;
	}

	_refresh() {
		this.namer.get();
		this.linker.get();
	}

  _openIILink(pay_token, effective_price) {
  		const proxy = this.wallet.principal?.toText();
  		if (!proxy) return;
  		const params = new URLSearchParams({
  			token: pay_token.id,
  			spender: this.namer.id,
  			proxy: this.wallet.principal.toText(),
  			amount: pay_token.cleaner(effective_price + pay_token.fee),
  			expiry_unit: 'hours',
  			expiry_amount: 1,
  		});
  		const w = window.open(
  			`${iilink_origin}/setup?${params}`,
  			'iilink',
  			'popup,width=480,height=660',
  		);
  		if (!w) this.notif.errorPopup('Popup blocked — please allow popups for this site.');
  }

	/* ------------------------------------------------------------------ */
	/*  Name input                                                        */
	/* ------------------------------------------------------------------ */

	_renderNameInput(max_len, len, sub, isError, isOk, busy) {
		return html`
			<div class="flex items-center justify-between text-xs text-slate-400 mb-1.5">
				<span>Name</span>
				<span class="text-[10px] text-slate-500 tabular-nums">${len} / ${max_len}</span>
			</div>
			<div class="flex gap-2 items-center">
				<input type="text"
					placeholder="e.g. kayicp"
					.value=${this.namer.name_str}
					@input=${(e) => {
						this.namer.name_str = e.target.value;
						this._resetForm();
						this.wallet.render();
					}}
					?disabled=${busy}
					class="flex-1 bg-slate-900/40 px-2 py-1.5 rounded-md text-xs ring-1 ring-slate-700
						font-mono text-slate-100 placeholder:text-slate-600
						disabled:opacity-50 disabled:cursor-not-allowed" />
				<button type="button"
					@click=${async () => this.namer.validateName()}
					?disabled=${busy || len === 0}
					class="shrink-0 px-3 py-1.5 rounded-md text-xs bg-green-700 hover:bg-green-600
						text-slate-100 ring-1 ring-slate-700 transition-colors
						disabled:opacity-50 disabled:cursor-not-allowed">
					${busy ? 'Checking…' : 'Check'}
				</button>
			</div>
			${sub.length > 0 ? html`
				<div class="mt-2 px-2 py-1.5 rounded-md text-[11px]
					${busy ? 'bg-slate-900/20 text-slate-400 animate-pulse'
						: isError ? 'bg-red-500/[0.06] text-red-400 ring-1 ring-red-500/10'
						: isOk ? 'bg-green-500/[0.06] text-green-400 ring-1 ring-green-500/10'
						: 'bg-slate-900/20 text-slate-400'}">
					${sub.replace(/^(Ok:|Error:)\s*/, '')}
				</div>
			` : html`
				<div class="text-[10px] text-slate-500 mt-1.5">
					Lowercase letters, digits, and underscores. Must start with a letter.
				</div>
			`}
		`;
	}

	/* ------------------------------------------------------------------ */
	/*  Duration picker                                                   */
	/* ------------------------------------------------------------------ */

	_renderDuration(total_days) {
		return html`
			<div class="mt-5 pt-5 border-t border-slate-700/50">
				<div class="flex items-center justify-between text-xs text-slate-400 mb-2">
					<span>Duration</span>
					<span class="text-[10px] text-slate-500 tabular-nums">${total_days} days total</span>
				</div>
				<div class="flex flex-col gap-1.5">
					${this.namer.duration_packages.map((dp, i) => {
						const selected = this.selected_duration_idx === i;
						return html`
							<label class="flex items-center gap-2.5 cursor-pointer rounded-md px-3 py-2 ring-1 transition-colors
								${selected
									? 'ring-green-600/60 bg-green-900/15'
									: 'ring-slate-700/80 bg-slate-900/30 hover:bg-slate-800/50'}">
								<input type="radio" name="duration"
									.checked=${selected}
									@change=${() => {
										this.selected_duration_idx = i;
										this.wallet.render();
									}}
									class="accent-green-500" />
								<span class="flex-1 text-xs text-slate-100">
									${dp.years_base} year${Number(dp.years_base) > 1 ? 's' : ''}
								</span>
								${Number(dp.months_bonus) > 0 ? html`
									<span class="text-[10px] text-green-400 font-medium">
										+${dp.months_bonus} month${Number(dp.months_bonus) > 1 ? 's' : ''} free
									</span>
								` : ''}
							</label>
						`;
					})}
				</div>
			</div>
		`;
	}

	/* ------------------------------------------------------------------ */
	/*  Payment toggle                                                    */
	/* ------------------------------------------------------------------ */

	_renderPaymentToggle() {
		return html`
			<div class="mt-5 flex items-center gap-2 flex-wrap">
				<span class="text-xs text-slate-400 shrink-0">Pay with</span>
				<div class="flex rounded-lg bg-slate-800/50 p-0.5 ring-1 ring-slate-700/50">
					<button type="button"
						class="px-2.5 py-1 text-[11px] rounded-md transition-colors
							${!this.namer.pay_with_icp
								? 'bg-slate-700 text-slate-100 shadow-sm'
								: 'text-slate-400 hover:text-slate-300'}"
						@click=${() => {
							this.namer.pay_with_icp = false;
							this.wallet.render();
						}}>
						${this.tcycles_token.symbol}
					</button>
					<button type="button"
						class="px-2.5 py-1 text-[11px] rounded-md transition-colors
							${this.namer.pay_with_icp
								? 'bg-slate-700 text-slate-100 shadow-sm'
								: 'text-slate-400 hover:text-slate-300'}"
						@click=${() => {
							this.namer.pay_with_icp = true;
							this.wallet.render();
						}}>
						${this.icp_token.symbol}
					</button>
				</div>
				${this.namer.pay_with_icp ? html`
					<button type="button"
						@click=${() => this.cmc.get()}
						?disabled=${this.cmc.get_busy}
						class="px-2 py-1 rounded-md text-[10px] ring-1 ring-slate-700
							bg-slate-900/30 hover:bg-slate-700/60 text-slate-300 transition-colors
							disabled:opacity-50 disabled:cursor-not-allowed">
						${this.cmc.get_busy ? 'Refreshing…' : '↻ Rate'}
					</button>
				` : ''}
			</div>
		`;
	}

	/* ------------------------------------------------------------------ */
	/*  Fee breakdown                                                     */
	/* ------------------------------------------------------------------ */

	_renderFeeBreakdown(isExtending, fmtFee, tcycles_raw, pay_token, effective_price) {
		return html`
			<div class="mt-4 rounded-lg ring-1 ring-slate-700/80 bg-slate-900/20 overflow-hidden divide-y divide-slate-700/40">
				<div class="px-3 py-2.5 flex items-center justify-between">
					<span class="text-xs text-slate-400">${isExtending ? 'Extension' : 'Registration'} fee</span>
					<span class="text-xs font-mono text-slate-100">${fmtFee(tcycles_raw)}</span>
				</div>
				<div class="px-3 py-2.5 flex items-center justify-between">
					<span class="text-xs text-slate-400">Transfer fee</span>
					<span class="text-xs font-mono text-slate-100">${pay_token.cleaner(pay_token.fee)} ${pay_token.symbol}</span>
				</div>
				<div class="px-3 py-2.5 flex items-center justify-between bg-slate-800/30">
					<span class="text-xs text-slate-200 font-medium">Total</span>
					<span class="text-xs font-mono text-slate-100 font-medium">${pay_token.cleaner(effective_price + pay_token.fee)} ${pay_token.symbol}</span>
				</div>
			</div>
		`;
	}

	/* ------------------------------------------------------------------ */
	/*  Login prompt                                                      */
	/* ------------------------------------------------------------------ */

	_renderLoginPrompt(isExtending) {
		return html`
			<div class="mt-5 pt-5 border-t border-slate-700/50 text-center">
				<div class="text-slate-500 text-xl mb-2">🔒</div>
				<p class="text-xs text-slate-400">
					Connect your Internet Identity to ${isExtending ? 'extend' : 'register'} this name.
				</p>
			</div>
		`;
	}

	/* ------------------------------------------------------------------ */
	/*  Register section (new name)                                       */
	/* ------------------------------------------------------------------ */

	_renderRegisterSection(fmtAmt, effective_price, pay_token, pkg, total_days, cmc_ready) {
		const mains = [...this.linker.mains.entries()];
		const loading = this.linker.getters_busy();
		const busy = this.namer.busy;

		// Keep selection in sync with available mains
		if (this.selected_main_txt != null && !this.linker.mains.has(this.selected_main_txt)) {
			this.selected_main_txt = null;
		}
		if (this.selected_main_txt == null && mains.length > 0) {
			this.selected_main_txt = mains[0][0];
		}

		const selected_entry = this.selected_main_txt
			? this.linker.mains.get(this.selected_main_txt)
			: null;
		const canSubmit = selected_entry != null && effective_price > 0n && cmc_ready && !busy;

		return html`
			<div class="mt-5 pt-5 border-t border-slate-700/50">
				<div class="text-xs text-slate-400 mb-2">Link to principal</div>

				${loading ? html`
					<div class="flex items-center gap-2 text-xs text-slate-500 py-4">
						<span class="inline-block w-3 h-3 border-2 border-slate-500 border-t-transparent rounded-full animate-spin"></span>
						Loading linked principals…
					</div>
				` : mains.length === 0 ? html`
  				<div class="rounded-md ring-1 ring-amber-500/10 bg-amber-500/[0.06] px-3 py-4 text-center">
  					<div class="text-amber-400 text-sm mb-1.5">⚠️</div>
  					<p class="text-[11px] text-amber-300">No linked principals found.</p>
  					<p class="text-[10px] text-slate-500 mt-1">
  						Open iilink to link your identity and set a spending allowance.
  					</p>
  					<button type="button"
  						@click=${() => this._openIILink(pay_token, effective_price)}
  						class="mt-3 inline-flex items-center gap-1.5 px-4 py-2 rounded-md text-xs font-medium
  							bg-green-700 hover:bg-green-600 text-white ring-1 ring-green-600 transition-colors">
  						Open iilink ↗
  					</button>
  				</div>
				` : html`
					<div class="flex flex-col gap-1.5">
						${mains.map(([txt, entry]) => {
							const selected = this.selected_main_txt === txt;
							const linkExpiry = nano2date(entry.expiry);
							const namerEntry = this.namer.mains.get(txt);
							const existingName = namerEntry && namerEntry.name.length > 0
								? namerEntry.name
								: null;

							return html`
								<label class="flex items-center gap-2.5 cursor-pointer rounded-md px-3 py-2 ring-1 transition-colors
									${selected
										? 'ring-green-600/60 bg-green-900/15'
										: 'ring-slate-700/80 bg-slate-900/30 hover:bg-slate-800/50'}">
									<input type="radio" name="register_main"
										.checked=${selected}
										@change=${() => {
											this.selected_main_txt = txt;
											this.wallet.render();
										}}
										class="accent-green-500" />
									<div class="flex-1 min-w-0">
										<div class="text-xs font-mono text-slate-100 truncate">
											${shortPrincipal(entry.p)}
										</div>
										${existingName ? html`
											<div class="text-[10px] text-slate-500 truncate">
												currently <span class="text-slate-400">${existingName}</span>
											</div>
										` : ''}
									</div>
									<span class="shrink-0 text-[10px] text-slate-500">
										link ${linkExpiry.toLocaleDateString()}
									</span>
								</label>
							`;
						})}
					</div>
					<div class="flex items-center justify-end mt-2">
						<button type="button" @click=${() => this._openIILink(pay_token, effective_price)}
							class="text-[10px] text-green-400/70 hover:text-green-300 transition-colors">
							Add / manage on iilink ↗
						</button>
					</div>
					<button type="button"
						@click=${() => {
							if (selected_entry) {
								this.namer.register(effective_price, selected_entry.p, Number(pkg.years_base), Number(pkg.months_bonus));
							}
						}}
						?disabled=${!canSubmit}
						class="w-full mt-4 px-4 py-2.5 rounded-lg text-sm font-medium transition-colors
							bg-green-700 hover:bg-green-600 text-white ring-1 ring-green-600
							disabled:opacity-50 disabled:cursor-not-allowed">
						${busy ? html`
							<span class="inline-flex items-center justify-center gap-2">
								<span class="inline-block w-3.5 h-3.5 border-2 border-white/40 border-t-white rounded-full animate-spin"></span>
								Registering…
							</span>
						` : !cmc_ready ? html`
							<span class="inline-flex items-center justify-center gap-2">
								<span class="inline-block w-3.5 h-3.5 border-2 border-white/40 border-t-white rounded-full animate-spin"></span>
								Loading rate…
							</span>
						` : `Register — ${fmtAmt(effective_price + pay_token.fee)}`}
					</button>
				`}
			</div>
		`;
	}

	/* ------------------------------------------------------------------ */
	/*  Extend section (existing name you own)                            */
	/* ------------------------------------------------------------------ */

	_renderExtendSection(fmtAmt, effective_price, pay_token, pkg, total_days) {
		const main_a = this.namer.name_a;
		const main_p = main_a?.owner;
		const busy = this.namer.busy;
		const cmc_ready = !this.namer.pay_with_icp || !this.cmc.get_busy;

		if (!main_p) return html`
			<div class="mt-5 pt-5 border-t border-slate-700/50 text-center">
				<div class="text-slate-500 text-xl mb-2">⚠️</div>
				<p class="text-xs text-slate-500">Unable to determine the owning principal.</p>
			</div>
		`;

		const main_txt = main_p.toText();
		const namerEntry = this.namer.mains.get(main_txt);
		const currentExpiry = namerEntry ? nano2date(namerEntry.expires_at) : null;
		const newExpiry = currentExpiry
			? new Date(currentExpiry.getTime() + Number(total_days) * 24 * 60 * 60 * 1000)
			: null;
		const canSubmit = effective_price > 0n && cmc_ready && !busy;

		return html`
			<div class="mt-5 pt-5 border-t border-slate-700/50">
				<div class="flex items-center justify-between text-xs mb-3">
					<span class="text-slate-400">Extending for</span>
					<span class="font-mono text-slate-100">${shortPrincipal(main_p)}</span>
				</div>
				<div class="flex items-center justify-end -mt-1 mb-2">
					<button type="button" @click=${() => this._openIILink(pay_token, effective_price)}
						class="text-[10px] text-green-400/70 hover:text-green-300 transition-colors">
						Manage on iilink ↗
					</button>
				</div>

				${currentExpiry ? html`
					<div class="rounded-lg ring-1 ring-slate-700/50 bg-slate-900/30 overflow-hidden divide-y divide-slate-700/40 mb-4">
						<div class="px-3 py-2 flex items-center justify-between">
							<span class="text-[11px] text-slate-500">Current expiry</span>
							<span class="text-[11px] text-slate-300">${currentExpiry.toLocaleDateString()}</span>
						</div>
						<div class="px-3 py-2 flex items-center justify-between">
							<span class="text-[11px] text-slate-500">Adding</span>
							<span class="text-[11px] text-green-400">+${total_days} days</span>
						</div>
						${newExpiry ? html`
							<div class="px-3 py-2 flex items-center justify-between bg-slate-800/30">
								<span class="text-[11px] text-slate-400 font-medium">New expiry</span>
								<span class="text-[11px] text-slate-100 font-medium">${newExpiry.toLocaleDateString()}</span>
							</div>
						` : ''}
					</div>
				` : ''}

				<button type="button"
					@click=${() => {
						this.namer.register(effective_price, main_p, Number(pkg.years_base), Number(pkg.months_bonus));
					}}
					?disabled=${!canSubmit}
					class="w-full px-4 py-2.5 rounded-lg text-sm font-medium transition-colors
						bg-amber-600 hover:bg-amber-500 text-white ring-1 ring-amber-500
						disabled:opacity-50 disabled:cursor-not-allowed">
					${busy ? html`
						<span class="inline-flex items-center justify-center gap-2">
							<span class="inline-block w-3.5 h-3.5 border-2 border-white/40 border-t-white rounded-full animate-spin"></span>
							Extending…
						</span>
					` : !cmc_ready ? html`
						<span class="inline-flex items-center justify-center gap-2">
							<span class="inline-block w-3.5 h-3.5 border-2 border-white/40 border-t-white rounded-full animate-spin"></span>
							Loading rate…
						</span>
					` : `Extend — ${fmtAmt(effective_price + pay_token.fee)}`}
				</button>
			</div>
		`;
	}

	/* ------------------------------------------------------------------ */
	/*  Your names list                                                   */
	/* ------------------------------------------------------------------ */

	_renderYourNames(busy) {
		const now = new Date();
		const loading = this.namer.getters_busy();
		const namedEntries = [...this.namer.mains.entries()]
			.filter(([, e]) => e.name.length > 0)
			.sort(([, a], [, b]) =>
				a.expires_at < b.expires_at ? -1 : a.expires_at > b.expires_at ? 1 : 0
			);

		return html`
			<div class="flex items-center justify-between mb-4">
				<h3 class="text-lg font-semibold text-slate-100">Your names</h3>
				<button type="button"
					@click=${() => this._refresh()}
					?disabled=${loading || this.linker.getters_busy()}
					class="shrink-0 px-2.5 py-1 text-xs rounded-md bg-slate-700 hover:bg-slate-600
						ring-1 ring-slate-600 transition-colors
						disabled:opacity-50 disabled:cursor-not-allowed">
					${loading ? 'Refreshing…' : 'Refresh'}
				</button>
			</div>

			<div class="bg-slate-800/40 rounded-lg ring-1 ring-slate-700/80 overflow-hidden">
				${loading ? html`
					<div class="flex items-center justify-center gap-2 text-xs text-slate-500 py-8">
						<span class="inline-block w-3 h-3 border-2 border-slate-500 border-t-transparent rounded-full animate-spin"></span>
						Loading your names…
					</div>

				` : namedEntries.length === 0 ? html`
					<div class="py-10 text-center">
						<div class="text-slate-500 text-xl mb-2">📝</div>
						<p class="text-xs text-slate-500">No names registered yet.</p>
						<p class="text-[10px] text-slate-600 mt-1">
							Register your first name above to get started.
						</p>
					</div>

				` : html`
					<div class="divide-y divide-slate-700/40">
						${namedEntries.map(([, entry]) => {
							const expiry = nano2date(entry.expires_at);
							const diffMs = expiry.getTime() - now.getTime();
							const expired = diffMs <= 0;
							const daysLeft = Math.ceil(diffMs / (1000 * 60 * 60 * 24));
							const expiringSoon = !expired && daysLeft <= 30;

							const fmtDur = (d) => {
								if (d > 365) return `${Math.floor(d / 365)}y ${Math.floor((d % 365) / 30)}m`;
								if (d > 30)  return `${Math.floor(d / 30)}m ${d % 30}d`;
								return `${d}d`;
							};

							return html`
								<div class="flex items-center gap-3 px-4 py-3
									${expired ? 'bg-red-500/[0.04]' : expiringSoon ? 'bg-amber-500/[0.04]' : ''}">
									<div class="flex-1 min-w-0">
										<div class="text-sm font-mono text-slate-100 truncate">${entry.name}</div>
										<div class="text-[10px] font-mono text-slate-500 truncate mt-0.5">
											${shortPrincipal(entry.p)}
										</div>
									</div>

									<div class="shrink-0 text-right">
										${expired ? html`
											<div class="text-[10px] text-red-400 font-medium">Expired</div>
											<div class="text-[10px] text-slate-600">${expiry.toLocaleDateString()}</div>
										` : expiringSoon ? html`
											<div class="text-[10px] text-amber-400 font-medium">${daysLeft}d left</div>
											<div class="text-[10px] text-slate-600">${expiry.toLocaleDateString()}</div>
										` : html`
											<div class="text-[10px] text-slate-400">${expiry.toLocaleDateString()}</div>
											<div class="text-[10px] text-slate-600">${fmtDur(daysLeft)}</div>
										`}
									</div>

									<button type="button"
										@click=${async () => {
											this.namer.name_str = entry.name;
											this._resetForm();
											this.wallet.render();
											window.scrollTo({ top: 0, behavior: 'smooth' });
											await this.namer.validateName();
											if (this.namer.name_str_sub.startsWith('Ok:')
												&& !this.namer.name_str_sub.startsWith('Ok: You'))
												this._refresh();
										}}
										?disabled=${busy}
										class="shrink-0 px-2.5 py-1 rounded-md text-[10px] font-medium ring-1 transition-colors
											disabled:opacity-50 disabled:cursor-not-allowed
											${expired
												? 'ring-red-700/50 bg-red-900/30 hover:bg-red-800/40 text-red-300'
												: expiringSoon
													? 'ring-amber-700/50 bg-amber-900/30 hover:bg-amber-800/40 text-amber-300'
													: 'ring-slate-700 bg-slate-900/30 hover:bg-slate-700/60 text-slate-300'}">
										${expired ? 'Reclaim' : 'Extend'}
									</button>
								</div>
							`;
						})}
					</div>
				`}
			</div>
		`;
	}

	/* ------------------------------------------------------------------ */
	/*  Main render                                                       */
	/* ------------------------------------------------------------------ */

	render() {
		if (this.namer.length_tiers.length === 0) return html`
			<div class="flex items-center gap-2 text-xs text-slate-400 py-6">
				<span class="inline-block w-3 h-3 border-2 border-slate-500 border-t-transparent rounded-full animate-spin"></span>
				Loading naming service…
			</div>
		`;

		/* ---------- deep-link via URL params ---------- */
		const urlParams = new URLSearchParams(window.location.search);
		const paramName = urlParams.get('name');
		if (paramName != null) {
			this.namer.name_str = paramName;
			this.selected_duration_idx = Number(urlParams.get('duration_index')) || 0;
			const paramToken = urlParams.get('token') || this.tcycles_token.id;
			this.namer.pay_with_icp = paramToken == this.icp_token.id;
			try {
				this.selected_main_txt = Principal.fromText(urlParams.get('main')).toText();
			} catch (_) {
				this.selected_main_txt = null;
			}
			(async () => {
				await this.namer.get();
				await this.namer.validateName();
				if (this.namer.name_str_sub.startsWith('Ok:')
					&& !this.namer.name_str_sub.startsWith('Ok: You'))
					this._refresh();
			})();
			return window.history.replaceState({}, '', Register.PATH);
		}

		/* ---------- derived state ---------- */
		const max_len = this.namer.length_tiers[this.namer.length_tiers.length - 1].max;
		const len     = this.namer.name_str.length;
		const sub     = this.namer.name_str_sub;
		const isError = sub.startsWith('Error:');
		const isOk    = sub.startsWith('Ok:');
		const isExtending = sub.startsWith('Ok: You');
		const busy     = this.namer.check_busy;
		const loggedIn = this.wallet.principal != null;

		/* ---------- pricing ---------- */
		const tier = isOk
			? this.namer.length_tiers.find(t => len >= t.min && len <= t.max)
			: null;
		const pkg = tier
			? (this.namer.duration_packages[this.selected_duration_idx] ?? this.namer.duration_packages[0])
			: null;
		const tcycles_raw = tier && pkg
			? BigInt(tier.tcycles_fee_multiplier) * this.tcycles_token.fee * BigInt(pkg.years_base)
			: 0n;
		const total_days = pkg
			? BigInt(pkg.years_base) * 365n + BigInt(pkg.months_bonus) * 30n
			: 0n;
		const pay_token = this.namer.pay_with_icp ? this.icp_token : this.tcycles_token;
		const cmc_ready = !this.namer.pay_with_icp || !this.cmc.get_busy;
		const effective_price = this.namer.pay_with_icp
			? (cmc_ready ? this.cmc.icp(tcycles_raw) : 0n)
			: tcycles_raw;

		const fmtFee = (raw) => {
			if (this.namer.pay_with_icp)
				return `${this.cmc.get_busy ? '…' : this.icp_token.cleaner(this.cmc.icp(raw))} ${this.icp_token.symbol}`;
			return `${this.tcycles_token.cleaner(raw)} ${this.tcycles_token.symbol}`;
		};
		const fmtAmt = (a) => `${pay_token.cleaner(a)} ${pay_token.symbol}`;

		/* ---------- template ---------- */
		return html`
			<div class="max-w-md mx-auto text-sm text-slate-200">

				<!-- Header -->
				<h3 class="text-lg font-semibold text-slate-100">
					${isExtending ? 'Extend' : 'Register'} a name
				</h3>
				<p class="text-xs text-slate-400 mt-1.5 mb-4">
					${isExtending
						? 'Extend the expiry of a name you already own.'
						: 'Check availability, pick a duration, and claim your on-chain name.'}
				</p>

				<!-- Main form card -->
				<div class="bg-slate-800/40 p-4 rounded-lg ring-1 ring-slate-700/80">
					${this._renderNameInput(max_len, len, sub, isError, isOk, busy)}
					${isOk && tier
						? html`
							${this._renderDuration(total_days)}
							${this._renderPaymentToggle()}
							${this._renderFeeBreakdown(isExtending, fmtFee, tcycles_raw, pay_token, effective_price)}
							${!loggedIn
								? this._renderLoginPrompt(isExtending)
								: isExtending
									? this._renderExtendSection(fmtAmt, effective_price, pay_token, pkg, total_days)
									: this._renderRegisterSection(fmtAmt, effective_price, pay_token, pkg, total_days, cmc_ready)
							}
						`
						: ''
					}
				</div>

				<!-- Your names -->
				${loggedIn ? html`<div class="mt-8">${this._renderYourNames(busy)}</div>` : ''}
			</div>
		`;
	}
}
