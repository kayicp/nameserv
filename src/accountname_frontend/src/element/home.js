// home.js
import { html } from 'lit-html';
import { genActor } from '../../../util/js/actor';
import { idlFactory } from 'declarations/accountname_backend';
import { nano2date } from '../../../util/js/bigint';

export default class Home {
	static PATH = '/';

	constructor(namer) {
		this.namer = namer;
		this.wallet = namer.wallet;
		this._hero_name = '';
		this._hero_checking = false;
		this._hero_result = '';
	}

	_nav(path) {
		return (e) => {
			e.preventDefault();
			history.pushState({}, '', path);
			window.dispatchEvent(new PopStateEvent('popstate'));
		};
	}

	async _heroCheck() {
		const name = this._hero_name.trim().toLowerCase();
		if (!name) return;
		this._hero_checking = true;
		this._hero_result = '';
		this.wallet.render();

		try {
			if (this.namer.anon == null)
				this.namer.anon = await genActor(idlFactory, this.namer.id);
			const accounts_res = await this.namer.anon.icrc_ans_accounts([name]);
			const acct_opt = accounts_res.results[0];
			const main_a = acct_opt[0];

			if (main_a == null) {
				this._hero_result = 'available';
			} else {
				const names_res = await this.namer.anon.icrc_ans_names([main_a]);
				const main = names_res.results[0];
				const expiry = nano2date(main.expires_at);
				if (main.name.length == 0 || main.name !== name || expiry < new Date()) {
					this._hero_result = 'available';
				} else {
					this._hero_result = 'taken';
				}
			}
		} catch {
			this._hero_result = 'error';
		}
		this._hero_checking = false;
		this.wallet.render();
	}

	render() {
		const tiers = [
			{ len: '1 char', example: 'k', price: '1,000' },
			{ len: '2 chars', example: 'ic', price: '500' },
			{ len: '3 chars', example: 'kay', price: '250' },
			{ len: '4 chars', example: 'cool', price: '100' },
			{ len: '5 chars', example: 'angel', price: '50' },
			{ len: '6 chars', example: 'motoko', price: '25' },
			{ len: '7 chars', example: 'dominic', price: '10' },
			{ len: '8 chars', example: 'trillion', price: '5' },
			{ len: '9 chars', example: 'decentral', price: '2' },
			{ len: '10–19', example: 'internetcomputer', price: '1' },
			{ len: '20–32', example: 'my_backend_canister_01', price: '0.5' },
		];

		const durations = [
			{ years: 1, bonus: 2, total: '14 months', label: '' },
			{ years: 3, bonus: 12, total: '4 years', label: '' },
			{ years: 5, bonus: 36, total: '8 years', label: 'Best value', pct: '60%' },
		];

		const features = [
			{ icon: '👤', title: 'Shareable profile', desc: 'Every name gets a public profile page at /@name — with avatar, address, QR code, and token balances.' },
			{ icon: '📋', title: 'Human-readable addresses', desc: 'Send tokens to a name instead of a 63-character principal. No more copy-paste anxiety.' },
			{ icon: '🪙', title: 'Multi-token balances', desc: 'Profile pages show balances for ICP, ckBTC, ckETH, ckUSDT, ckUSDC — all in one view.' },
			{ icon: '📱', title: 'QR codes built in', desc: 'Every profile has scannable QR codes for both ICRC account and account ID.' },
			{ icon: '⏱️', title: `Rent, don't buy`, desc: `Names are rented for 1–5 years with generous bonus months. No squatting, fair pricing.` },
			{ icon: '⛓️', title: '100% on-chain', desc: 'Pure canister smart contracts on the Internet Computer. No off-chain servers, no DNS dependency.' },
		];

		const heroName = this._hero_name.trim().toLowerCase();
		const resultIsAvailable = this._hero_result === 'available';
		const resultIsTaken = this._hero_result === 'taken';
		const resultIsError = this._hero_result === 'error';

		return html`
			<div class="relative max-w-4xl mx-auto px-4">

				<!-- Ambient glow -->
				<div class="absolute -top-40 left-1/2 -translate-x-1/2 w-[700px] h-[500px] bg-gradient-to-b from-green-500/[0.06] via-teal-500/[0.03] to-transparent rounded-full blur-3xl pointer-events-none" aria-hidden="true"></div>

				<!-- ════════════════════════ HERO ════════════════════════ -->
				<section class="relative text-center pt-20 pb-24">
					<div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-green-500/10 ring-1 ring-green-500/20 text-green-400 text-xs font-medium mb-8">
						<span class="w-1.5 h-1.5 rounded-full bg-green-400 animate-pulse"></span>
						On-chain naming · Internet Computer
					</div>

					<h1 class="text-4xl sm:text-5xl lg:text-6xl font-extrabold tracking-tight leading-[1.1]">
						<span class="text-slate-100">Your name.</span>
						<br>
						<span class="bg-gradient-to-r from-green-400 via-teal-400 to-green-300 bg-clip-text text-transparent">On-chain.</span>
					</h1>

					<p class="mt-6 text-base sm:text-lg text-slate-400 max-w-2xl mx-auto leading-relaxed">
						Replace unreadable principal IDs with a human-friendly name.
						Get a shareable profile, QR${'\u00A0'}codes, and multi-token
						balances — all${'\u00A0'}on the Internet${'\u00A0'}Computer.
					</p>

					<!-- Hero name search -->
					<div class="mt-10 max-w-md mx-auto">
						<form @submit=${(e) => { e.preventDefault(); this._heroCheck(); }}
							class="flex gap-2 items-center">
							<div class="flex-1 relative">
								<span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 text-sm font-mono">@</span>
								<input type="text"
									placeholder="yourname"
									.value=${this._hero_name}
									@input=${(e) => {
										this._hero_name = e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, '');
										this._hero_result = '';
										this.wallet.render();
									}}
									class="w-full bg-slate-800/60 pl-7 pr-3 py-3 rounded-lg text-sm ring-1 ring-slate-700
										font-mono text-slate-100 placeholder:text-slate-600
										focus:outline-none focus:ring-2 focus:ring-green-500/40" />
							</div>
							<button type="submit"
								?disabled=${this._hero_checking || !heroName}
								class="px-5 py-3 text-sm font-semibold rounded-lg transition-colors
									${this._hero_checking || !heroName
										? 'bg-slate-700 text-slate-500 cursor-not-allowed'
										: 'bg-green-600 hover:bg-green-500 text-white shadow-lg shadow-green-600/20'}">
								${this._hero_checking ? 'Checking…' : 'Search'}
							</button>
						</form>

						<!-- Result -->
						<div class="mt-3 min-h-[3rem]">
							${this._hero_checking ? html`
								<div class="flex items-center justify-center gap-2 text-xs text-slate-500">
									<span class="inline-block w-3 h-3 border-2 border-slate-500 border-t-transparent rounded-full animate-spin"></span>
									Looking up ${heroName}…
								</div>
							` : resultIsAvailable ? html`
								<div class="flex flex-col items-center gap-3">
									<div class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-green-500/[0.08] ring-1 ring-green-500/20 text-green-400 text-xs font-medium">
										<span class="w-1.5 h-1.5 rounded-full bg-green-400"></span>
										@${heroName} is available!
									</div>
									<button
										@click=${(e) => {
											this.namer.name_str = heroName;
											this.namer.name_a = null;
											this.namer.name_str_sub = '';
											this._nav('/register')(e);
										}}
										class="px-5 py-2 text-xs font-semibold rounded-lg bg-green-700 hover:bg-green-600 text-white ring-1 ring-green-600/50 transition-colors">
										Register @${heroName} →
									</button>
								</div>
							` : resultIsTaken ? html`
								<div class="flex flex-col items-center gap-3">
									<div class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-amber-500/[0.08] ring-1 ring-amber-500/20 text-amber-400 text-xs font-medium">
										<span class="w-1.5 h-1.5 rounded-full bg-amber-400/60"></span>
										@${heroName} is taken
									</div>
									<button
										@click=${this._nav(`/@${heroName}`)}
										class="px-5 py-2 text-xs font-medium rounded-lg bg-slate-700 hover:bg-slate-600 text-slate-200 ring-1 ring-slate-600 transition-colors">
										View profile →
									</button>
								</div>
							` : resultIsError ? html`
								<div class="text-xs text-red-400/80">
									Something went wrong. Try again.
								</div>
							` : heroName ? html`
								<div class="text-xs text-slate-600">
									Press Search to check availability
								</div>
							` : ''}
						</div>
					</div>
				</section>

				<!-- ════════════════════════ PROFILE PREVIEW ════════════════════════ -->
				<section class="py-20 border-t border-slate-800/60">
					<div class="text-center mb-14">
						<h2 class="text-2xl sm:text-3xl font-bold text-slate-100">Your on-chain identity card</h2>
						<p class="mt-2 text-sm text-slate-400">Every name gets a public profile — instantly shareable.</p>
					</div>

					<div class="max-w-xs mx-auto">
						<div class="bg-slate-800/60 rounded-2xl ring-1 ring-slate-700/80 p-6 shadow-xl shadow-slate-900/30">
							<div class="text-center">
								<img src="https://api.dicebear.com/9.x/thumbs/svg?seed=alice_42"
									alt="avatar" class="w-20 h-20 rounded-full mx-auto ring-2 ring-slate-700/80 bg-slate-800" />
								<div class="mt-4 text-lg font-mono font-bold text-slate-100">alice_42</div>
								<div class="mt-2 inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-green-500/[0.08] ring-1 ring-green-500/20 text-green-400 text-[10px] font-medium">
									<span class="w-1.5 h-1.5 rounded-full bg-green-400"></span>
									Registered
								</div>
							</div>
							<div class="mt-5 space-y-2">
								${[
									{ sym: 'ICP', val: '12.5' },
									{ sym: 'ckBTC', val: '0.0031' },
									{ sym: 'ckETH', val: '0.42' },
									{ sym: 'ckUSDT', val: '150.00' },
								].map(t => html`
									<div class="flex items-center justify-between px-3 py-2 rounded-lg bg-slate-900/40">
										<span class="text-xs text-slate-400">${t.sym}</span>
										<span class="text-xs font-mono text-slate-200 tabular-nums">${t.val}</span>
									</div>
								`)}
							</div>
							<div class="mt-4 pt-3 border-t border-slate-700/40 text-center">
								<div class="text-[10px] text-slate-600 font-mono">
									${window.location.origin}/@alice_42
								</div>
							</div>
						</div>
					</div>
				</section>

				<!-- ════════════════════════ HOW IT WORKS ════════════════════════ -->
				<section class="py-20 border-t border-slate-800/60">
					<div class="text-center mb-14">
						<h2 class="text-2xl sm:text-3xl font-bold text-slate-100">How it works</h2>
						<p class="mt-2 text-sm text-slate-400">Three steps. Your name, your principal, your profile.</p>
					</div>

					<div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
						<div class="bg-slate-800/40 p-6 rounded-xl ring-1 ring-slate-700/80 hover:ring-slate-600/80 hover:bg-slate-800/60 transition-all">
							<div class="w-10 h-10 rounded-full bg-green-500/10 ring-1 ring-green-500/30 flex items-center justify-center text-green-400 font-bold text-sm mb-4">1</div>
							<h3 class="text-sm font-semibold text-slate-100 mb-2">Pick a name</h3>
							<p class="text-xs text-slate-400 leading-relaxed">
								Search for the name you want. Shorter names are rarer and cost more — like domain names.
							</p>
						</div>

						<div class="bg-slate-800/40 p-6 rounded-xl ring-1 ring-slate-700/80 hover:ring-slate-600/80 hover:bg-slate-800/60 transition-all">
							<div class="w-10 h-10 rounded-full bg-green-500/10 ring-1 ring-green-500/30 flex items-center justify-center text-green-400 font-bold text-sm mb-4">2</div>
							<h3 class="text-sm font-semibold text-slate-100 mb-2">Choose your duration</h3>
							<p class="text-xs text-slate-400 leading-relaxed">
								Rent for 1, 3, or 5 years. Longer commitments get up to 60% bonus time. Pay with ICP or TCYCLES.
							</p>
						</div>

						<div class="bg-slate-800/40 p-6 rounded-xl ring-1 ring-slate-700/80 hover:ring-slate-600/80 hover:bg-slate-800/60 transition-all">
							<div class="w-10 h-10 rounded-full bg-green-500/10 ring-1 ring-green-500/30 flex items-center justify-center text-green-400 font-bold text-sm mb-4">3</div>
							<h3 class="text-sm font-semibold text-slate-100 mb-2">Share your profile</h3>
							<p class="text-xs text-slate-400 leading-relaxed">
								Your name is live immediately. Share your /@name link, and anyone can see your address and balances.
							</p>
						</div>
					</div>
				</section>

				<!-- ════════════════════════ FEATURES ════════════════════════ -->
				<section class="py-20 border-t border-slate-800/60">
					<div class="text-center mb-14">
						<h2 class="text-2xl sm:text-3xl font-bold text-slate-100">More than a name</h2>
						<p class="mt-2 text-sm text-slate-400">Everything you get when you register.</p>
					</div>

					<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
						${features.map(f => html`
							<div class="bg-slate-800/40 p-5 rounded-xl ring-1 ring-slate-700/80 hover:ring-slate-600/80 hover:bg-slate-800/60 transition-all">
								<div class="w-10 h-10 rounded-lg bg-slate-800 ring-1 ring-slate-700 flex items-center justify-center text-lg mb-4">${f.icon}</div>
								<h3 class="text-sm font-semibold text-slate-100 mb-1.5">${f.title}</h3>
								<p class="text-xs text-slate-400 leading-relaxed">${f.desc}</p>
							</div>
						`)}
					</div>
				</section>

				<!-- ════════════════════════ PRICING ════════════════════════ -->
				<section class="py-20 border-t border-slate-800/60">
					<div class="text-center mb-14">
						<h2 class="text-2xl sm:text-3xl font-bold text-slate-100">Shorter is rarer</h2>
						<p class="mt-2 text-sm text-slate-400">Name length determines the yearly price. All prices in TCYCLES per year.</p>
					</div>

					<div class="max-w-lg mx-auto bg-slate-800/40 rounded-xl ring-1 ring-slate-700/80 overflow-hidden">
						<div class="grid grid-cols-3 gap-0 px-4 py-2.5 border-b border-slate-700/60 text-[10px] text-slate-500 uppercase tracking-wider font-medium">
							<span>Length</span>
							<span>Example</span>
							<span class="text-right">TCYCLES / yr</span>
						</div>
						<div class="divide-y divide-slate-700/30">
							${tiers.map((t, i) => html`
								<div class="grid grid-cols-3 gap-0 px-4 py-2.5 items-center
									${i < 3 ? 'bg-amber-500/[0.03]' : ''}">
									<span class="text-xs text-slate-300">${t.len}</span>
									<span class="text-xs font-mono text-slate-400">${t.example}</span>
									<span class="text-xs font-mono text-slate-100 text-right tabular-nums">${t.price}</span>
								</div>
							`)}
						</div>
					</div>

					<p class="text-center text-[10px] text-slate-500 mt-3">Also payable with ICP at current exchange rate</p>
				</section>

				<!-- ════════════════════════ DURATION PACKAGES ════════════════════════ -->
				<section class="py-20 border-t border-slate-800/60">
					<div class="text-center mb-14">
						<h2 class="text-2xl sm:text-3xl font-bold text-slate-100">Commit longer, get more</h2>
						<p class="mt-2 text-sm text-slate-400">Every plan comes with bonus months at no extra cost.</p>
					</div>

					<div class="grid grid-cols-1 sm:grid-cols-3 gap-5 max-w-3xl mx-auto">
						${durations.map((d, i) => {
							const isBest = i === durations.length - 1;
							return html`
								<div class="relative bg-slate-800/40 p-6 rounded-xl ring-1 ${isBest ? 'ring-green-500/40 shadow-lg shadow-green-500/5' : 'ring-slate-700/80'} hover:ring-slate-600/80 hover:bg-slate-800/60 transition-all">
									${isBest ? html`
										<span class="absolute -top-2.5 left-4 px-2 py-0.5 text-[10px] uppercase tracking-wider font-semibold bg-green-600 text-white rounded-full">Best value</span>
									` : ''}
									<div class="text-2xl font-bold text-slate-100">
										${d.years} year${d.years > 1 ? 's' : ''}
									</div>
									<div class="mt-3 text-xs text-slate-400 space-y-1.5">
										<div class="flex justify-between">
											<span>Base</span>
											<span class="text-slate-300">${d.years} yr${d.years > 1 ? 's' : ''}</span>
										</div>
										<div class="flex justify-between">
											<span>Bonus</span>
											<span class="text-green-400">+${d.bonus} month${d.bonus > 1 ? 's' : ''} free</span>
										</div>
									</div>
									<div class="mt-4 pt-4 border-t border-slate-700/60">
										<div class="text-lg font-semibold text-slate-100">${d.total}</div>
										<div class="text-[10px] text-slate-500">total access</div>
									</div>
									${d.pct ? html`
										<div class="mt-3 inline-flex items-center px-2 py-0.5 rounded-full bg-green-500/[0.08] ring-1 ring-green-500/20 text-green-400 text-[10px] font-medium">
											${d.pct} bonus time
										</div>
									` : ''}
								</div>
							`;
						})}
					</div>
				</section>

				<!-- ════════════════════════ BEFORE/AFTER ════════════════════════ -->
				<section class="py-20 border-t border-slate-800/60">
					<div class="text-center mb-14">
						<h2 class="text-2xl sm:text-3xl font-bold text-slate-100">Addresses are hard. Names are easy.</h2>
					</div>

					<div class="grid grid-cols-1 sm:grid-cols-2 gap-6 max-w-3xl mx-auto">
						<div class="bg-red-500/[0.04] p-6 rounded-xl ring-1 ring-red-500/10">
							<div class="text-xs font-semibold text-red-400/80 uppercase tracking-wider mb-4">Without a name</div>
							<ul class="space-y-3 text-xs text-slate-400">
								<li class="flex items-start gap-2">
									<span class="text-red-500/60 mt-px shrink-0">✕</span>
									<span>"Send to <span class="font-mono text-[10px] text-slate-500">24rks-34v64-...-anvvo-dqe</span>" — hope you copied it right</span>
								</li>
								<li class="flex items-start gap-2">
									<span class="text-red-500/60 mt-px shrink-0">✕</span>
									<span>No way to verify who owns an address</span>
								</li>
								<li class="flex items-start gap-2">
									<span class="text-red-500/60 mt-px shrink-0">✕</span>
									<span>No public profile or shareable link</span>
								</li>
								<li class="flex items-start gap-2">
									<span class="text-red-500/60 mt-px shrink-0">✕</span>
									<span>Sharing addresses via chat is error-prone</span>
								</li>
							</ul>
						</div>

						<div class="bg-green-500/[0.04] p-6 rounded-xl ring-1 ring-green-500/10">
							<div class="text-xs font-semibold text-green-400/80 uppercase tracking-wider mb-4">With a name</div>
							<ul class="space-y-3 text-xs text-slate-400">
								<li class="flex items-start gap-2">
									<span class="text-green-500 mt-px shrink-0">✓</span>
									<span>"Send to <span class="font-mono text-green-400">@alice_42</span>" — unmistakable</span>
								</li>
								<li class="flex items-start gap-2">
									<span class="text-green-500 mt-px shrink-0">✓</span>
									<span>Visit the profile to verify the principal</span>
								</li>
								<li class="flex items-start gap-2">
									<span class="text-green-500 mt-px shrink-0">✓</span>
									<span>Shareable profile with avatar, QR, and balances</span>
								</li>
								<li class="flex items-start gap-2">
									<span class="text-green-500 mt-px shrink-0">✓</span>
									<span>One link: <span class="font-mono text-slate-300">/@alice_42</span></span>
								</li>
							</ul>
						</div>
					</div>
				</section>

				<!-- ════════════════════════ USE CASES ════════════════════════ -->
				<section class="py-20 border-t border-slate-800/60">
					<div class="text-center mb-14">
						<h2 class="text-2xl sm:text-3xl font-bold text-slate-100">Made for everyone</h2>
					</div>

					<div class="grid grid-cols-1 sm:grid-cols-3 gap-5 max-w-3xl mx-auto">
						<div class="bg-slate-800/40 p-5 rounded-xl ring-1 ring-slate-700/80 hover:bg-slate-800/60 transition-all text-center">
							<div class="text-3xl mb-3">🧑‍💻</div>
							<h3 class="text-sm font-semibold text-slate-100 mb-1.5">Developers</h3>
							<p class="text-xs text-slate-400 leading-relaxed">
								Resolve names on-chain from your canister. Integrate name-based payments into your dApp.
							</p>
						</div>
						<div class="bg-slate-800/40 p-5 rounded-xl ring-1 ring-slate-700/80 hover:bg-slate-800/60 transition-all text-center">
							<div class="text-3xl mb-3">💰</div>
							<h3 class="text-sm font-semibold text-slate-100 mb-1.5">Traders & holders</h3>
							<p class="text-xs text-slate-400 leading-relaxed">
								Share your /@name for receiving tokens. Verify addresses before sending. No more typos.
							</p>
						</div>
						<div class="bg-slate-800/40 p-5 rounded-xl ring-1 ring-slate-700/80 hover:bg-slate-800/60 transition-all text-center">
							<div class="text-3xl mb-3">🏢</div>
							<h3 class="text-sm font-semibold text-slate-100 mb-1.5">Projects & DAOs</h3>
							<p class="text-xs text-slate-400 leading-relaxed">
								Register your brand name. Give your treasury a recognizable, verifiable address.
							</p>
						</div>
					</div>
				</section>

				<!-- ════════════════════════ FINAL CTA ════════════════════════ -->
				<section class="py-24 text-center border-t border-slate-800/60">
					<h2 class="text-2xl sm:text-3xl font-bold text-slate-100">Claim your name</h2>
					<p class="mt-3 text-sm text-slate-400 max-w-md mx-auto">
						Names are first-come, first-served. The good ones go fast.
					</p>
					<div class="mt-10 flex items-center justify-center gap-4 flex-wrap">
						<button
							@click=${this._nav('/register')}
							class="px-8 py-3 text-sm font-semibold rounded-lg bg-green-600 hover:bg-green-500 text-white shadow-lg shadow-green-600/20 transition-colors">
							Register a name
						</button>
						<button
							@click=${this._nav('/@alice_42')}
							class="px-8 py-3 text-sm font-semibold rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 ring-1 ring-slate-700 transition-colors">
							See a demo profile
						</button>
					</div>
				</section>

				<div class="pb-12"></div>
			</div>
		`;
	}
}