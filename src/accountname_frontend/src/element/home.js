import { html } from 'lit-html';

export default class Home {
  static PATH = '/';
  constructor(namer) {
    this.namer = namer;
  }

  render() {
    const loaded = this.namer.length_tiers.length > 0;
    const tiers = loaded ? this.namer.length_tiers : [];
    const packages = loaded ? this.namer.duration_packages : [];
    const tc = this.namer.tcycles_token;

    const tierLabel = (t) =>
      t.min === t.max ? `${t.min}` : `${t.min}–${t.max}`;

    const price1yr = (t) =>
      `${tc.cleaner(BigInt(t.tcycles_fee_multiplier) * tc.fee)} ${tc.symbol}`;

    return html`
<div class="max-w-2xl mx-auto space-y-20 py-12 px-4">

  <!-- ── Hero ──────────────────────────────────────────── -->
  <div class="text-center space-y-8">
    <div class="space-y-3">
      <h1 class="text-4xl sm:text-5xl font-bold tracking-tight leading-tight">
        <span class="bg-gradient-to-r from-green-400 to-emerald-300
                     bg-clip-text text-transparent">
          Your principal
        </span>
        <br/>
        <span class="text-slate-100">deserves a name.</span>
      </h1>
      <p class="text-slate-400 text-sm sm:text-base max-w-md mx-auto leading-relaxed">
        Replace unreadable Internet Computer principal IDs with clean,
        memorable names — fully on-chain, no intermediaries.
      </p>
    </div>

    <!-- before / after -->
    <div class="bg-slate-800/60 rounded-lg ring-1 ring-slate-700 p-5
                max-w-sm mx-auto text-left">
      <div class="flex items-center gap-3">
        <span class="text-2xs text-slate-500 uppercase tracking-wider shrink-0 w-12">
          Before
        </span>
        <code class="text-xs text-slate-500 font-mono truncate line-through">
          k5dlc-ijshq-lsyre-qvvpq-p3g…
        </code>
      </div>
      <div class="my-3 flex items-center gap-2">
        <div class="flex-1 border-t border-dashed border-slate-700/60"></div>
        <span class="text-xs text-green-500">↓</span>
        <div class="flex-1 border-t border-dashed border-slate-700/60"></div>
      </div>
      <div class="flex items-center gap-3">
        <span class="text-2xs text-green-400 uppercase tracking-wider shrink-0 w-12">
          After
        </span>
        <code class="text-lg text-green-400 font-mono font-bold">alice</code>
      </div>
    </div>

    <div>
      <a href="/register"
        class="inline-block px-6 py-2.5 rounded-lg text-sm font-medium
               bg-green-700 hover:bg-green-600 text-white ring-1 ring-green-600/50
               transition-colors">
        Register a name →
      </a>
    </div>
  </div>

  <!-- ── Why ───────────────────────────────────────────── -->
  <div class="space-y-6">
    <h2 class="text-xl font-semibold text-slate-100 text-center">
      Why use a name?
    </h2>
    <div class="grid gap-4 sm:grid-cols-3">
      ${[
        {
          icon: '🏷️',
          title: 'Memorable',
          desc: 'Share a name, not a 63-character string. Easy to type, easy to verify, impossible to forget.',
        },
        {
          icon: '🌐',
          title: 'Fully on-chain',
          desc: 'Runs entirely on the Internet Computer. No DNS, no centralized servers, no single points of failure.',
        },
        {
          icon: '🔌',
          title: 'ICRC-ANS standard',
          desc: 'Built on the Account Name Service standard. Any IC service that supports ICRC-ANS can resolve your name.',
        },
      ].map(f => html`
        <div class="bg-slate-800/40 rounded-lg ring-1 ring-slate-700 p-4 space-y-2">
          <div class="text-2xl">${f.icon}</div>
          <h3 class="text-sm font-semibold text-slate-100">${f.title}</h3>
          <p class="text-2xs text-slate-400 leading-relaxed">${f.desc}</p>
        </div>
      `)}
    </div>
  </div>

  <!-- ── How it works ────────────────────────────────── -->
  <div class="space-y-6">
    <h2 class="text-xl font-semibold text-slate-100 text-center">
      How it works
    </h2>
    <div class="grid gap-6 sm:grid-cols-3">
      ${[
        {
          step: '1',
          title: 'Check availability',
          desc: 'Type a name and instantly see if it\'s available. Names are 1–32 characters: lowercase letters, numbers, and underscores.',
        },
        {
          step: '2',
          title: 'Set up payment',
          desc: 'Create a payment link on IILink. This authorizes the name service to collect the registration fee from your chosen principal.',
        },
        {
          step: '3',
          title: 'Register',
          desc: 'Confirm and you\'re done. Your name is live immediately — any IC service supporting ICRC-ANS can resolve it to your principal.',
        },
      ].map(s => html`
        <div class="relative bg-slate-800/40 rounded-lg ring-1 ring-slate-700 p-4 pt-8">
          <div class="absolute -top-3 left-4 w-7 h-7 rounded-full
                      bg-green-700 ring-2 ring-slate-900
                      flex items-center justify-center
                      text-xs font-bold text-white">
            ${s.step}
          </div>
          <h3 class="text-sm font-semibold text-slate-100 mb-1">${s.title}</h3>
          <p class="text-2xs text-slate-400 leading-relaxed">${s.desc}</p>
        </div>
      `)}
    </div>
  </div>

  <!-- ── Pricing ─────────────────────────────────────── -->
  <div class="space-y-8">
    <div class="text-center space-y-2">
      <h2 class="text-xl font-semibold text-slate-100">Pricing</h2>
      <p class="text-xs text-slate-400 max-w-md mx-auto">
        Shorter names are scarcer and priced at a premium.
        Pay with ${loaded ? tc.symbol : 'TCycles'} or ICP.
        Names are leased — extend any time to keep yours.
      </p>
    </div>

    ${!loaded ? html`
      <div class="text-xs text-slate-500 animate-pulse text-center py-8">
        Loading pricing…
      </div>
    ` : html`
      <!-- annual fee table -->
      <div class="bg-slate-800/40 rounded-lg ring-1 ring-slate-700 overflow-hidden">
        <div class="grid grid-cols-[1fr_auto]">
          <div class="px-4 py-2 text-2xs text-slate-500 font-medium uppercase tracking-wider
                      bg-slate-800/60 border-b border-slate-700/50">
            Name length
          </div>
          <div class="px-4 py-2 text-2xs text-slate-500 font-medium uppercase tracking-wider
                      text-right bg-slate-800/60 border-b border-slate-700/50">
            Fee / year
          </div>
          ${tiers.map((t, i) => {
            const stripe = i % 2 !== 0 ? 'bg-slate-800/20' : '';
            return html`
              <div class="px-4 py-2 text-xs text-slate-300 font-mono
                          border-b border-slate-700/20 ${stripe}">
                ${tierLabel(t)} char${t.max > 1 ? 's' : ''}
              </div>
              <div class="px-4 py-2 text-xs text-slate-100 font-mono text-right
                          border-b border-slate-700/20 ${stripe}">
                ${price1yr(t)}
              </div>
            `;
          })}
        </div>
      </div>

      <!-- duration bonuses -->
      <div class="space-y-3">
        <h3 class="text-sm font-semibold text-slate-100 text-center">
          Commit longer, get more
        </h3>
        <div class="grid gap-3 sm:grid-cols-3">
          ${packages.map((dp, i) => {
            const paid = Number(dp.years_base);
            const bonus = Number(dp.months_bonus);
            const totalDays = paid * 365 + bonus * 30;
            const pct = Math.round((bonus / (paid * 12)) * 100);
            const best = i === packages.length - 1;
            return html`
              <div class="relative bg-slate-800/40 rounded-lg ring-1 p-4
                          text-center space-y-1
                          ${best ? 'ring-green-600/60 bg-green-900/10' : 'ring-slate-700'}">
                ${best ? html`
                  <div class="absolute -top-2.5 left-1/2 -translate-x-1/2
                              px-2 py-0.5 rounded-full
                              bg-green-700 text-2xs font-medium text-white whitespace-nowrap">
                    Best value
                  </div>
                ` : ''}
                <div class="text-lg font-bold text-slate-100">
                  ${paid} year${paid > 1 ? 's' : ''}
                </div>
                ${bonus > 0 ? html`
                  <div class="text-xs text-green-400 font-medium">
                    +${bonus} month${bonus > 1 ? 's' : ''} free
                  </div>
                  <div class="text-2xs text-slate-500">
                    ${totalDays.toLocaleString()} days · +${pct}% bonus
                  </div>
                ` : html`
                  <div class="text-2xs text-slate-500">${totalDays} days</div>
                `}
              </div>
            `;
          })}
        </div>
      </div>
    `}
  </div>

  <!-- ── Name rules ──────────────────────────────────── -->
  <div class="bg-slate-800/40 rounded-lg ring-1 ring-slate-700 p-5 space-y-3
              max-w-md mx-auto">
    <h3 class="text-sm font-semibold text-slate-100 text-center">
      Name rules
    </h3>
    <ul class="space-y-1.5 text-2xs text-slate-400 leading-relaxed">
      ${[
        'Lowercase letters (a–z), digits (0–9), and underscores (_)',
        'Must start with a letter',
        'Cannot end with an underscore',
        'No consecutive underscores',
        `1–${loaded ? tiers[tiers.length - 1].max : 32} characters`,
        'One name per principal — transfer the existing name first to register a new one',
      ].map(r => html`
        <li class="flex items-start gap-2">
          <span class="text-green-500 mt-px shrink-0">·</span>
          <span>${r}</span>
        </li>
      `)}
    </ul>
  </div>

  <!-- ── Final CTA ───────────────────────────────────── -->
  <div class="text-center space-y-4 pb-8">
    <h2 class="text-2xl font-bold text-slate-100">
      Claim your name before someone else does.
    </h2>
    <p class="text-xs text-slate-400">
      Short names go fast. The best ones don't come back.
    </p>
    <a href="/register"
      class="inline-block px-6 py-2.5 rounded-lg text-sm font-medium
             bg-green-700 hover:bg-green-600 text-white ring-1 ring-green-600/50
             transition-colors">
      Register now →
    </a>
  </div>
</div>`;
  }
}