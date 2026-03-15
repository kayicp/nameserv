// demo.js
import { html } from 'lit-html';
import { icp_logo, tcycles_logo, ckbtc_logo, cketh_logo, ckusdt_logo, ckusdc_logo } from '../../../util/js/logo';
import Token from '../model/Token';
import { encodeIcrcAccount } from '@dfinity/ledger-icrc';
import { AccountIdentifier, SubAccount } from '@dfinity/ledger-icp';

const network = process.env.DFX_NETWORK;

export default class Profile {
	static PATH = '/@';

	_loaded_username = null;

	constructor(namer) {
		this.namer = namer;
		this.wallet = namer.wallet;
		this.notif = namer.notif;
		this.icp_token = namer.icp_token;
		this.tcycles_token = namer.tcycles_token;
		this.ckbtc_token = null;
		this.cketh_token = null;
		this.ckusdt_token = null;
		this.ckusdc_token = null;
		if (network === 'ic') {
			this.ckbtc_token = new Token('mxzaz-hqaaa-aaaar-qaada-cai', namer.wallet, namer.id, 'ckBTC');
			this.cketh_token = new Token('ss2fx-dyaaa-aaaar-qacoq-cai', namer.wallet, namer.id, 'ckETH');
			this.ckusdt_token = new Token('cngnf-vqaaa-aaaar-qag4q-cai', namer.wallet, namer.id, 'ckUSDT');
			this.ckusdc_token = new Token('xevnm-gaaaa-aaaar-qafnq-cai', namer.wallet, namer.id, 'ckUSDC');
		}
	}

	_copy(text, label) {
		navigator.clipboard.writeText(text).then(
			() => this.notif.successToast('Copied', `${label} copied to clipboard`),
			() => this.notif.errorToast('Copy failed', 'Could not access clipboard')
		);
	}

	_tokens() {
		const list = [
			{ token: this.icp_token, logo: icp_logo },
			{ token: this.tcycles_token, logo: tcycles_logo },
		];
		if (network === 'ic') {
			list.push(
				{ token: this.ckbtc_token, logo: ckbtc_logo },
				{ token: this.cketh_token, logo: cketh_logo },
				{ token: this.ckusdt_token, logo: ckusdt_logo },
				{ token: this.ckusdc_token, logo: ckusdc_logo },
			);
		}
		return list;
	}

	_avatarUrl(username) {
		return `https://api.dicebear.com/9.x/thumbs/svg?seed=${encodeURIComponent(username)}`;
	}

	_qrUrl(text) {
		return `https://quickchart.io/qr?text=${encodeURIComponent(text)}&size=200&margin=1`;
	}

	_load(username) {
		if (this._loaded_username === username) return;
		this._loaded_username = username;
		this.namer.name_str = username;
		this.namer.name_a = null;
		this.namer.name_str_sub = '';
		this._loadProfile();
	}

	async _loadProfile() {
		await this.namer.validateName(null);
		if (this.namer.name_a) this._loadBalances();
	}

	_loadBalances() {
		const account = this.namer.name_a;
		if (!account) return;
		for (const { token } of this._tokens()) {
			if (token) token.getBalance(account);
		}
	}

	async _refreshAll() {
		this.namer.name_a = null;
		this.namer.name_str_sub = '';
		for (const { token } of this._tokens()) {
			if (token) token.profile_balance = null;
		}
		this.wallet.render();
		await this.namer.validateName(null);
		if (this.namer.name_a) this._loadBalances();
	}

	// ═════════════════════════════════════════════════════
	// Render entry
	// ═════════════════════════════════════════════════════
	render() {
		const username = decodeURIComponent(
			window.location.pathname.slice(Profile.PATH.length)
		).replace(/\/+$/, '');

		if (!username) {
			return html`
				<div class="flex flex-col items-center justify-center py-20 text-center">
					<div class="text-slate-500 text-3xl mb-3">📝</div>
					<div class="text-slate-400 text-sm">
						Add a name after <span class="font-mono text-slate-300">@</span> to view a profile.
					</div>
					<div class="text-[10px] text-slate-600 mt-2 font-mono">
						${window.location.origin}/@kayicp
					</div>
				</div>
			`;
		}

		if (this.namer.length_tiers.length === 0) {
			return this._renderSkeleton(username, 'Loading naming service…');
		}

		this._load(username);

		if (this.namer.check_busy || (this.namer.name_a == null && this.namer.name_str_sub === '')) {
			return this._renderSkeleton(username, 'Looking up name…');
		}

		if (this.namer.name_a != null) {
			return this._renderProfile(username);
		}

		return this._renderNotFound(username);
	}

	// ═════════════════════════════════════════════════════
	// Loading skeleton
	// ═════════════════════════════════════════════════════
	_renderSkeleton(username, message) {
		return html`
			<div class="max-w-sm mx-auto text-center py-20">
				<img src="${this._avatarUrl(username)}" alt=""
					class="w-24 h-24 rounded-full mx-auto ring-2 ring-slate-700/80 bg-slate-800 animate-pulse" />
				<div class="mt-5 text-xl font-mono font-semibold text-slate-300">${username}</div>
				<div class="mt-4 flex items-center justify-center gap-2 text-xs text-slate-500">
					<span class="inline-block w-3 h-3 border-2 border-slate-500 border-t-transparent rounded-full animate-spin"></span>
					${message}
				</div>
			</div>
		`;
	}

	// ═════════════════════════════════════════════════════
	// Name not found / available
	// ═════════════════════════════════════════════════════
	_renderNotFound(username) {
		const sub = this.namer.name_str_sub;
		const isError = sub.startsWith('Error:');

		return html`
			<div class="max-w-sm mx-auto text-center py-20">
				<img src="${this._avatarUrl(username)}" alt=""
					class="w-24 h-24 rounded-full mx-auto ring-2 ring-slate-700/80 bg-slate-800 opacity-40" />
				<div class="mt-5 text-xl font-mono text-slate-400">${username}</div>

				${isError ? html`
					<div class="mt-4 inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-red-500/[0.08] ring-1 ring-red-500/20 text-red-400 text-xs">
						${sub.replace(/^Error:\s*/, '')}
					</div>
				` : html`
					<div class="mt-4 inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-amber-500/[0.08] ring-1 ring-amber-500/20 text-amber-400 text-xs font-medium">
						<span class="w-1.5 h-1.5 rounded-full bg-amber-400/60"></span>
						Available
					</div>

					<p class="mt-5 text-sm text-slate-400">
						This name hasn't been claimed yet.
					</p>
					<p class="text-xs text-slate-500 mt-1">
						Register it now and point it to your principal.
					</p>

					<button
						@click=${(e) => {
							e.preventDefault();
							this.namer.name_str = username;
							this.namer.name_a = null;
							this.namer.name_str_sub = '';
							history.pushState({}, '', '/register');
							window.dispatchEvent(new PopStateEvent('popstate'));
						}}
						class="mt-6 px-6 py-2.5 text-sm font-semibold rounded-lg bg-green-700 hover:bg-green-600 text-white ring-1 ring-green-600/50 shadow-lg shadow-green-700/10 transition-colors">
						Register "${username}"
					</button>
				`}
			</div>
		`;
	}

	// ═════════════════════════════════════════════════════
	// Profile page
	// ═════════════════════════════════════════════════════
	_renderProfile(username) {
		const name_a = this.namer.name_a;

		const icrcAccount = encodeIcrcAccount({
			owner: name_a.owner,
			subaccount: name_a.subaccount.length > 0 ? name_a.subaccount[0] : undefined,
		});

		let accountIdHex = '';
		try {
			const subAccount = name_a.subaccount.length > 0
				? SubAccount.fromBytes(new Uint8Array(name_a.subaccount[0]))
				: undefined;
			accountIdHex = AccountIdentifier.fromPrincipal({
				principal: name_a.owner,
				subAccount,
			}).toHex();
		} catch {
			accountIdHex = '';
		}

		return html`
			<div class="max-w-md mx-auto py-8 text-sm text-slate-200">

				<!-- Avatar + name -->
				<div class="text-center">
					<img src="${this._avatarUrl(username)}" alt="${username}"
						class="w-28 h-28 rounded-full mx-auto ring-2 ring-slate-700/80 bg-slate-800 shadow-lg shadow-slate-900/50" />
					<div class="mt-5 text-2xl font-mono font-bold text-slate-100">${username}</div>
					<div class="mt-3 inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-green-500/[0.08] ring-1 ring-green-500/20 text-green-400 text-xs font-medium">
						<span class="w-1.5 h-1.5 rounded-full bg-green-400"></span>
						Registered
					</div>
				</div>

				<!-- Addresses -->
				<div class="mt-8 space-y-4">
					${this._renderAddress(
						'ICRC Account',
						icrcAccount,
						'For sending any ICRC-1 token (ICP, ckBTC, ckETH, etc.)'
					)}
					${accountIdHex ? this._renderAddress(
						'Account ID',
						accountIdHex,
						'For ICP transfers from exchanges'
					) : ''}
				</div>

				<!-- Balances -->
				<div class="mt-8">
					${this._renderBalances()}
				</div>

				<!-- Actions -->
				<div class="mt-8 flex items-center justify-center gap-3">
					<button
						@click=${() => this._refreshAll()}
						?disabled=${this.namer.check_busy}
						class="px-4 py-1.5 text-xs rounded-md bg-slate-700 hover:bg-slate-600 text-slate-200 ring-1 ring-slate-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed">
						${this.namer.check_busy ? 'Refreshing…' : '↻ Refresh all'}
					</button>
					<button
						@click=${() => this._copy(`${window.location.origin}/@${username}`, 'Profile link')}
						class="px-4 py-1.5 text-xs rounded-md bg-slate-700 hover:bg-slate-600 text-slate-200 ring-1 ring-slate-600 transition-colors">
						Share profile
					</button>
				</div>
			</div>
		`;
	}

	// ═════════════════════════════════════════════════════
	// Address card with QR
	// ═════════════════════════════════════════════════════
	_renderAddress(label, value, description) {
		return html`
			<div class="bg-slate-800/40 p-4 rounded-lg ring-1 ring-slate-700/80">
				<div class="flex items-center justify-between mb-1.5">
					<div class="text-xs font-medium text-slate-400">${label}</div>
					<button
						class="text-[10px] text-sky-400/80 hover:text-sky-300 transition-colors"
						@click=${() => this._copy(value, label)}>
						copy
					</button>
				</div>
				<div class="font-mono text-[11px] text-slate-200 break-all leading-relaxed select-all">
					${value}
				</div>
				<div class="text-[10px] text-slate-500 mt-2">${description}</div>
				<div class="mt-3 flex justify-center">
					<div class="bg-white rounded-lg p-1.5 inline-block shadow-sm">
						<img src="${this._qrUrl(value)}"
							alt="QR for ${label}"
							class="w-24 h-24 rounded-sm"
							loading="lazy" />
					</div>
				</div>
			</div>
		`;
	}

	// ═════════════════════════════════════════════════════
	// Balances list
	// ═════════════════════════════════════════════════════
	_renderBalances() {
		const tokens = this._tokens();

		return html`
			<div class="bg-slate-800/40 rounded-lg ring-1 ring-slate-700/80 overflow-hidden">
				<div class="px-4 py-3 border-b border-slate-700/60">
					<div class="text-xs font-medium text-slate-400">Balances</div>
				</div>
				<div class="divide-y divide-slate-700/30">
					${tokens.map(({ token, logo }) => {
						if (!token) return '';
						const loading = token.profile_balance_busy || token.profile_balance == null;
						const ready = token.symbol != null;

						return html`
							<div class="flex items-center gap-3 px-4 py-3">
								<img src="${logo}" alt="" class="w-7 h-7 rounded-full shrink-0 bg-slate-800" />
								<div class="flex-1 min-w-0">
									<div class="text-xs font-medium text-slate-200">
										${ready ? token.symbol : html`<span class="text-slate-500 animate-pulse">…</span>`}
									</div>
									${ready ? html`
										<div class="text-[10px] text-slate-500 truncate">${token.name}</div>
									` : ''}
								</div>
								<div class="text-right shrink-0">
									${!ready || loading ? html`
										<div class="w-16 h-4 rounded bg-slate-700/50 animate-pulse"></div>
									` : html`
										<div class="text-xs font-mono text-slate-100 tabular-nums">
											${token.cleaner(token.profile_balance)}
										</div>
										${token.profile_balance === 0n ? '' : html`
											<div class="text-[10px] font-mono text-slate-500 tabular-nums">
												${token.clean(token.profile_balance)}
											</div>
										`}
									`}
								</div>
							</div>
						`;
					})}
				</div>
			</div>
		`;
	}
}