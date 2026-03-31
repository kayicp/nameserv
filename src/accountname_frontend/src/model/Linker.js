import { idlFactory } from 'declarations/accountlinker_backend';
import { Principal } from '@dfinity/principal';
import { shortPrincipal } from '../../../util/js/principal';
import Token from './Token';
import { genActor } from '../../../util/js/actor';
import { html } from 'lit-html';
import { duration2nano } from '../../../util/js/duration';
import { date2nano } from '../../../util/js/bigint';

// linker.js (Namer's linker integration)
export default class Linker {
	get_busy = false;
	get_mains_busy = false;

	mains = new Map();

	constructor(p_txt, wallet, icp_token, tcycles_token, namer_p) {
		this.id = p_txt;
		this.id_p = Principal.fromText(p_txt);
		this.wallet = wallet;
		this.notif = wallet.notif;
		this.icp_token = icp_token;
		this.tcycles_token = tcycles_token;
		this.namer_p = namer_p;
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
			const namer_a = { owner: this.namer_p, subaccount: [] };
			const credits = await this.anon.iilink_credits([namer_a]);
			this.namer_credits = credits.results[0];
			this.get_busy = false;
			this.getMains();
			this.render();
		} catch (cause) {
			this.get_busy = false;
			this.notif.errorToast('Failed to load namer credits', cause);
		}
  }

  async getMains() {
    const proxy = { owner: this.wallet.principal, subaccount: [] };
    if (proxy.owner == null) return this.get_mains_busy = false;
    this.get_mains_busy = true;
    this.render();
    let expiry_args = [];
    const mains = new Map();
    let prev_main = [];
    try {
      while (true) {
        const mains_res = await this.anon.iilink_mains({ proxy, previous: prev_main, take: [] });
        if (mains_res.results.length == 0) break;
        for (const main_p of mains_res.results) {
          prev_main = [main_p];
          const main_p_txt = main_p.toText();
          mains.set(main_p_txt, { p: main_p, expiry: 0n, links: new Map() });
          expiry_args.push({ main: { owner: main_p, subaccount: [] }, proxy });
        };
      };
    } catch (cause) {
      this.notif.errorToast(`Get mains failed ${prev_main}`, cause);
    };
    let link_args = [];
    try {
      while (expiry_args.length > 0) {
        const args = expiry_args.slice(0, 100);
        expiry_args.splice(0, 100);
        const expiry_res = await this.anon.iilink_proxy_expiries(args);
        if (expiry_res.results.length == 0) break;
        const now = date2nano();
        const spender_a = { owner: this.namer_p, subaccount: [] };
        for (let i = 0; i < expiry_res.results.length; i++) {
          const arg = args[i];
          const main_p_txt = arg.main.owner.toText();
          const res = expiry_res.results[i];
          if (res > now) {
            const main = mains.get(main_p_txt);
            main.expiry = res;
            link_args.push({ main: arg.main, spender: spender_a, token: this.icp_token.id_p });
            link_args.push({ main: arg.main, spender: spender_a, token: this.tcycles_token.id_p });
          } else mains.delete(main_p_txt);
        };
      };
    } catch (cause) {
      this.notif.errorToast(`Get main expiries failed`, cause);
    };
    try {
      while (link_args.length > 0) {
        const args = link_args.slice(0, 100);
        link_args.splice(0, 100);
        const link_res = await this.anon.iilink_icrc1_allowances(args);
        if (link_res.results.length == 0) break;
        const now = date2nano();
        for (let i = 0; i < link_res.results.length; i++) {
          const arg = args[i];
          const main_p_txt = arg.main.owner.toText();
          const token_p_txt = arg.token.toText();
          const main = mains.get(main_p_txt);
          const res = link_res.results[i];
          main.links.set(token_p_txt, res);
        }
      }
    } catch (cause) {
      this.notif.errorToast(`Get main links failed`, cause);
    }
    this.mains.clear();
    this.mains = mains;
    this.get_mains_busy = false;
    this.render();
  };

  getters_busy() {
    return this.get_busy || this.get_mains_busy;
	}
}
