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

export default class Register {
  static PATH = '/register';

  constructor(namer, linker) {
    this.namer = namer;
    this.icp_token = namer.icp_token;
    this.tcycles_token = namer.tcycles_token;
    this.wallet = namer.wallet;
    this.notif = namer.notif;
    this.linker = linker;
    this.cmc = new CMC(this.wallet);
    this.selected_duration_idx = 0;
    this.button = html`
    <button 
        class="inline-flex items-center px-2 py-1 text-xs rounded-md font-medium bg-green-800 hover:bg-green-700 text-slate-100 ring-1 ring-slate-700"
        @click=${(e) => {
            e.preventDefault();
            if (window.location.pathname.startsWith(Register.PATH)) return;
            history.pushState({}, '', Register.PATH);
            window.dispatchEvent(new PopStateEvent('popstate'));
        }}>Register</button>
    `;
  }

  render() {
    if (this.namer.length_tiers.length === 0)
      return html`<p class="text-sm text-slate-400">Loading Namer canister…</p>`;

    const max_len    = this.namer.length_tiers[this.namer.length_tiers.length - 1].max;
    const len        = this.namer.name_str.length;
    const sub        = this.namer.name_str_sub;
    const isError    = sub.startsWith('Error:');
    const isOk       = sub.startsWith('Ok:');
    const busy       = this.namer.check_busy;
    const isExtending = sub.startsWith('Ok: You');
    const loggedIn   = this.wallet.principal != null;

    /* ── pricing ─────────────────────────────────────────────── */
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

    const pay_token  = this.namer.pay_with_icp ? this.icp_token : this.tcycles_token;
    const cmc_ready  = !this.namer.pay_with_icp || !this.cmc.get_busy;
    const effective_price = this.namer.pay_with_icp
      ? (cmc_ready ? this.cmc.icp(tcycles_raw) : 0n)
      : tcycles_raw;

    const fmtFee = (raw) => {
      if (this.namer.pay_with_icp)
        return `${this.cmc.get_busy ? '…' : this.icp_token.cleaner(this.cmc.icp(raw))} ${this.icp_token.symbol}`;
      return `${this.tcycles_token.cleaner(raw)} ${this.tcycles_token.symbol}`;
    };
    const fmtAmt = (a) => `${pay_token.cleaner(a)} ${pay_token.symbol}`;

    const refresh = () => {
      const t = this.namer.length_tiers.find(
        t => this.namer.name_str.length >= t.min && this.namer.name_str.length <= t.max);
      const p = this.namer.duration_packages[this.selected_duration_idx]
             ?? this.namer.duration_packages[0];
      if (!t || !p) return;
      const raw   = BigInt(t.tcycles_fee_multiplier) * this.tcycles_token.fee * BigInt(p.years_base);
      const price = this.namer.pay_with_icp ? this.cmc.icp(raw) : raw;
      if (this.namer.selected_renew_main_p != null)
        this.linker.getLink(this.namer.selected_renew_main_p, this.namer.pay_with_icp);
      else
        this.linker.filterLinks(price, this.namer.pay_with_icp);
    };

    const filters   = [...this.linker.filters.entries()];
    const selReg    = this.namer.selected_register_main_p;
    const selRegTxt = selReg?.toText();
    const link      = this.linker.link;
    const linkOk    = link.main_p != null && cmc_ready && link.allowance >= effective_price;

    const openIILink = (mainPrincipal) => {
      const params = new URLSearchParams({
        token: pay_token.id,
        spender: this.namer.id,
        proxy: this.wallet.principal.toText(),
        amount: pay_token.cleaner(effective_price + pay_token.fee),
        expiry_unit: "days",
        expiry_amount: 1,
      });
      if (mainPrincipal) params.set('main', mainPrincipal.toText());
      window.open(`${iilink_origin}/links/new?${params.toString()}`, "_blank", "noopener,noreferrer");
    };

    return html`
<div class="max-w-md mx-auto space-y-8">
  <div>
    <h3 class="text-lg font-semibold text-slate-100 mb-2">
      ${isExtending ? 'Extend' : 'Register'} a name
    </h3>
    <p class="text-xs text-slate-400 mb-4">
      ${isExtending
        ? 'Extend the expiry of a name you own.'
        : 'Check if a name is available, then rent it and point it to your principal.'}
    </p>

    <div class="bg-slate-800/40 p-4 rounded-md ring-1 ring-slate-700 space-y-3">

      <!-- ── Name ──────────────────────────────────────── -->
      <label class="block text-xs text-slate-400">
        <!-- (6) name + char count inline -->
        <div class="flex items-center justify-between">
          <span>Name</span>
          <span class="text-2xs text-slate-500">${len} / ${max_len} characters</span>
        </div>
        <div class="mt-1 flex gap-2 items-center">
          <input type="text" placeholder="e.g. alice_42"
            .value=${this.namer.name_str}
            @input=${(e) => {
              this.namer.name_str = e.target.value;
              this.namer.name_str_sub = '';
              this.namer.selected_renew_main_p = null;
              this.namer.selected_register_main_p = null;
              this.linker.filters.clear();
              this.linker.link = { main_p: null, allowance: 0n, expires_at: 0n };
              this.wallet.render();
            }}
            ?disabled=${busy}
            class="flex-1 bg-slate-900/30 px-2 py-1 rounded text-xs ring-1 ring-slate-700
                   font-mono text-slate-100 disabled:opacity-50 disabled:cursor-not-allowed" />

          <button type="button"
            @click=${async () => {
              await this.namer.validateName(
                (mp, pwi) => this.linker.getLink(mp, pwi)
              );
              if (this.namer.name_str_sub.startsWith('Ok:')
                  && !this.namer.name_str_sub.startsWith('Ok: You'))
                refresh();
            }}
            ?disabled=${busy || len === 0}
            class="shrink-0 px-3 py-1 rounded-md text-xs bg-green-700 hover:bg-green-600
                   text-slate-100 ring-1 ring-slate-700
                   disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-slate-700/50"
          >${busy ? 'Checking…' : 'Check name'}</button>
        </div>
        <!-- (6) result on its own line -->
        ${sub.length > 0 ? html`
          <div class="mt-1.5">
            <span class="text-2xs ${
              busy    ? 'text-slate-400 animate-pulse'
            : isError ? 'text-red-400'
            : isOk    ? 'text-green-400'
                      : 'text-slate-400'}">${sub}</span>
          </div>
        ` : ''}
      </label>

      ${isOk && tier ? html`

        <!-- ── Duration ────────────────────────────────── -->
        <div class="pt-2 border-t border-slate-700/50">
          <!-- (7) duration + total days inline -->
          <div class="flex items-center justify-between text-xs text-slate-400 mb-1">
            <span>Duration</span>
            <span class="text-2xs text-slate-500">Total: ${total_days} days</span>
          </div>
          <div class="flex flex-col gap-1.5">
            ${this.namer.duration_packages.map((dp, i) => html`
              <label class="flex items-center gap-2 cursor-pointer rounded px-2 py-1.5 ring-1
                ${this.selected_duration_idx === i
                  ? 'ring-green-600/60 bg-green-900/20'
                  : 'ring-slate-700 bg-slate-900/30 hover:bg-slate-800/60'}">
                <input type="radio" name="duration"
                  .checked=${this.selected_duration_idx === i}
                  @change=${() => {
                    this.selected_duration_idx = i;
                    refresh();
                    this.wallet.render();
                  }}
                  class="accent-green-500" />
                <span class="flex-1 text-xs text-slate-100">
                  ${dp.years_base} year${Number(dp.years_base) > 1 ? 's' : ''}
                </span>
                ${Number(dp.months_bonus) > 0 ? html`
                  <span class="text-2xs text-green-400">
                    +${dp.months_bonus} month${Number(dp.months_bonus) > 1 ? 's' : ''} bonus
                  </span>
                ` : ''}
              </label>
            `)}
          </div>
        </div>

        <!-- ── Pay with (1: inline) ─────────────────────── -->
        <div class="flex items-center gap-2 pt-2 text-xs text-slate-400">
          <span class="shrink-0">Pay with</span>
          <select
            @change=${(e) => {
              this.namer.pay_with_icp = e.target.value === 'icp';
              refresh();
              this.wallet.render();
            }}
            class="bg-slate-900/30 px-2 py-1 rounded text-xs ring-1 ring-slate-700 font-mono text-slate-100">
            <option value="tcycles" ?selected=${!this.namer.pay_with_icp}>
              ${this.tcycles_token.symbol}
            </option>
            <option value="icp" ?selected=${this.namer.pay_with_icp}>
              ${this.icp_token.symbol}
            </option>
          </select>
          ${this.namer.pay_with_icp ? html`
            <button type="button"
              @click=${() => this.cmc.get()}
              ?disabled=${this.cmc.get_busy}
              class="px-2 py-1 rounded text-2xs ring-1 ring-slate-700
                     bg-slate-900/30 hover:bg-slate-700/60 text-slate-300
                     disabled:opacity-50 disabled:cursor-not-allowed"
            >${this.cmc.get_busy ? 'Refreshing…' : '↻ Rate'}</button>
          ` : ''}
        </div>

        <!-- ── Fee (4: grouped) ────────────────────────── -->
        <div class="mt-1 rounded-md ring-1 ring-slate-700 bg-slate-900/20 divide-y divide-slate-700/50">
          <div class="px-3 py-2 flex items-center justify-between">
            <span class="text-xs text-slate-400">${isExtending ? 'Extension' : 'Registration'} fee</span>
            <span class="text-sm font-mono text-slate-100">${fmtFee(tcycles_raw)}</span>
          </div>
          <div class="px-3 py-2 flex items-center justify-between">
            <span class="text-xs text-slate-400">Transfer fee</span>
            <span class="text-sm font-mono text-slate-100">${pay_token.cleaner(pay_token.fee)} ${pay_token.symbol}</span>
          </div>
          <div class="px-3 py-2 flex items-center justify-between bg-slate-800/30">
            <span class="text-xs text-slate-300 font-medium">Total</span>
            <span class="text-sm font-mono text-slate-100 font-medium">${pay_token.cleaner(effective_price + pay_token.fee)} ${pay_token.symbol}</span>
          </div>
        </div>

        <!-- ── Action ──────────────────────────────────── -->
        ${!loggedIn ? html`
          <div class="pt-3 border-t border-slate-700/50 text-center">
            <p class="text-xs text-slate-400 py-2">
              Log in to ${isExtending ? 'extend' : 'register'} this name.
            </p>
          </div>

        ` : isExtending ? html`
          <!-- ── Extend expiry ─────────────────────────── -->
          <div class="pt-2 border-t border-slate-700/50 space-y-3">
            <div class="text-xs text-slate-400">
              Extending expiry for
              <span class="font-mono text-slate-100 ml-1">
                ${shortPrincipal(this.namer.selected_renew_main_p)}
              </span>
            </div>

            <div class="text-xs text-slate-400">
              <!-- (2) refresh button for allowance -->
              <div class="flex items-center justify-between mb-1">
                <span>Link allowance</span>
                <button type="button"
                  @click=${() => this.linker.getLink(this.namer.selected_renew_main_p, this.namer.pay_with_icp)}
                  ?disabled=${this.linker.get_link_busy}
                  class="px-2 py-0.5 rounded text-2xs ring-1 ring-slate-700
                         bg-slate-900/30 hover:bg-slate-700/60 text-slate-300
                         disabled:opacity-50 disabled:cursor-not-allowed"
                >${this.linker.get_link_busy ? '↻ …' : '↻ Refresh'}</button>
              </div>
              ${this.linker.get_link_busy ? html`
                <div class="text-2xs text-slate-500 animate-pulse">Loading…</div>
              ` : link.main_p != null ? html`
                <div class="bg-slate-900/30 px-2 py-1.5 rounded ring-1 ring-slate-700
                            flex items-center justify-between">
                  <span class="text-xs font-mono text-slate-100">${fmtAmt(link.allowance)}</span>
                  ${linkOk ? html`
                    <span class="text-2xs text-green-400">✓ sufficient</span>
                  ` : html`
                    <span class="text-2xs text-red-400">✗ need ${fmtAmt(effective_price)}</span>
                  `}
                </div>
                <!-- (3) IILink button only when insufficient -->
                ${!linkOk ? html`
                  <div class="mt-1.5 text-center">
                    <button type="button"
                      class="text-2xs text-green-400 underline hover:text-green-300
                             hover:no-underline bg-transparent p-0 border-0 cursor-pointer"
                      @click=${() => openIILink(this.namer.selected_renew_main_p)}
                    >Open IILink to increase allowance</button>
                  </div>
                ` : ''}
              ` : html`
                <div class="text-2xs text-slate-500">No link found</div>
                <div class="mt-1 text-center">
                  <button type="button"
                    class="text-2xs text-green-400 underline hover:text-green-300
                           hover:no-underline bg-transparent p-0 border-0 cursor-pointer"
                    @click=${() => openIILink(this.namer.selected_renew_main_p)}
                  >Open IILink to set up a link</button>
                </div>
              `}
            </div>

            <button type="button"
              @click=${() => this.namer.register(
                effective_price, pay_token, this.namer.selected_renew_main_p, total_days
              )}
              ?disabled=${this.namer.busy || this.linker.get_link_busy || !linkOk}
              class="w-full px-3 py-2 rounded-md text-sm font-medium
                    bg-green-700 hover:bg-green-600 text-white ring-1 ring-green-600/50
                    disabled:opacity-50 disabled:cursor-not-allowed
                    disabled:bg-slate-700/50 disabled:ring-slate-700"
            >${this.namer.busy ? 'Extending…' : 'Extend expiry'}</button>
          </div>

        ` : html`
          <!-- ── Register ──────────────────────────────── -->
          <div class="pt-2 border-t border-slate-700/50 space-y-3">
            <label class="block text-xs text-slate-400">
              <!-- (2) refresh button for principal list -->
              <div class="flex items-center justify-between mb-1">
                <span>Main principal
                  <span class="text-2xs text-slate-500 ml-1">
                    ${this.linker.filter_links_busy
                      ? '(searching…)'
                      : `(${filters.length} found)`}
                  </span>
                </span>
                <button type="button"
                  @click=${() => refresh()}
                  ?disabled=${this.linker.filter_links_busy}
                  class="px-2 py-0.5 rounded text-2xs ring-1 ring-slate-700
                         bg-slate-900/30 hover:bg-slate-700/60 text-slate-300
                         disabled:opacity-50 disabled:cursor-not-allowed"
                >${this.linker.filter_links_busy ? '↻ …' : '↻ Refresh'}</button>
              </div>

              <div class="flex flex-col gap-1.5 max-h-40 overflow-y-auto">
                ${this.linker.filter_links_busy ? html`
                  <div class="text-2xs text-slate-500 animate-pulse py-2 text-center">
                    Searching for linked principals…
                  </div>
                ` : filters.length === 0 ? html`
                  <div class="text-2xs text-slate-500 py-2 text-center">
                    No linked principals with sufficient allowance found.
                  </div>
                ` : filters.map(([ptxt, f]) => {
                  const existing = this.namer.mains.get(ptxt);
                  return html`
                    <label class="flex items-center gap-2 cursor-pointer rounded px-2 py-1.5 ring-1
                      ${selRegTxt === ptxt
                        ? 'ring-green-600/60 bg-green-900/20'
                        : 'ring-slate-700 bg-slate-900/30 hover:bg-slate-800/60'}">
                      <input type="radio" name="main"
                        .checked=${selRegTxt === ptxt}
                        @change=${() => {
                          this.namer.selected_register_main_p = f.p;
                          this.wallet.render();
                        }}
                        class="accent-green-500" />
                      <span class="flex-1 text-xs font-mono text-slate-100 truncate">
                        ${shortPrincipal(f.p)}
                        ${existing?.name ? html`
                          <span class="text-2xs text-amber-400 font-sans ml-1">
                            replaces "${existing.name}"
                          </span>
                        ` : ''}
                      </span>
                      <span class="text-2xs text-slate-400 shrink-0">
                        ${fmtAmt(f.allowance)}
                      </span>
                    </label>`;
                })}
              </div>
            </label>

            <!-- (3) IILink button always shown for registration -->
            <div class="text-center">
              <button type="button"
                class="text-2xs text-green-400 underline hover:text-green-300
                       hover:no-underline bg-transparent p-0 border-0 cursor-pointer"
                @click=${() => openIILink(selReg)}
              >Open IILink to create or increase a link</button>
            </div>

            <button type="button"
              @click=${() => this.namer.register(
                effective_price, pay_token, selReg, total_days
              )}
              ?disabled=${this.namer.busy || this.linker.filter_links_busy
                              || selReg == null || !cmc_ready}
              class="w-full px-3 py-2 rounded-md text-sm font-medium
                    bg-green-700 hover:bg-green-600 text-white ring-1 ring-green-600/50
                    disabled:opacity-50 disabled:cursor-not-allowed
                    disabled:bg-slate-700/50 disabled:ring-slate-700"
            >${this.namer.busy ? 'Registering…' : 'Register'}</button>
          </div>
        `}

      ` : ''}
    </div>
  </div>
</div>`;
  }
}