import { idlFactory } from 'declarations/accountlinker_backend';
import { Principal } from '@dfinity/principal';
import { shortPrincipal } from '../../../util/js/principal';
import Token from './Token';
import { genActor } from '../../../util/js/actor';
import { html } from 'lit-html';
import { duration2nano } from '../../../util/js/duration';
import { date2nano } from '../../../util/js/bigint';

export default class Linker {
	get_busy = false;
	filter_links_busy = false;
	get_link_busy = false;

	link = {
		main_p: null,
		allowance: 0n,
		expires_at: 0n,
	};
	filters = new Map();

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
			const namer_a = { owner : this.namer_p, subaccount: [] };
			const credits = await this.anon.iilink_credits([namer_a]);
			this.namer_credits = credits.results[0];
			this.get_busy = false;
			this.render();
		} catch (cause) {
			this.get_busy = false;
			this.notif.errorToast(`Get namer credits failed`, cause);
		}
	}

	async getLink(main_p, pay_with_icp) {
		this.get_link_busy = true;
		const proxy = { owner : this.wallet.principal, subaccount: [] }
		if (proxy.owner == null) {
			this.link = { main_p: null, allowance: 0n, expires_at: 0n };
			this.render();
		} else {
			const spender = { owner : this.namer_p, subaccount: [] };
			const main = { owner: main_p, subaccount: [] };
			try {
				const links_res = await this.anon.iilink_icrc1_allowances([{
					proxy, spender, main, token: pay_with_icp? this.icp_token.id_p : this.tcycles_token.id_p,
				}]);
				const link = links_res.results[0];
				this.link = { main_p, allowance: link.allowance, expires_at: link.expires_at };
				this.get_link_busy = false;
				this.render();
			} catch (cause) {
				this.get_link_busy = false;
				this.notif.errorToast(`Get link failed`, cause);
			}
		}
		
	};

	async filterLinks(allowance, pay_with_icp) {
		this.filter_links_busy = true;
		this.render();
		const proxy = { owner : this.wallet.principal, subaccount: [] }
		const filters = new Map();
		if (proxy.owner != null) {
			const spender = { owner : this.namer_p, subaccount: [] };
			let prev_main = [];
			try {
				while (true) {
					const filters_res = await this.anon.iilink_icrc1_sufficient_allowances({
						proxy, spender, allowance,
						token: pay_with_icp? this.icp_token.id_p : this.tcycles_token.id_p, 
						previous: prev_main, take: []
					});
					if (filters_res.results.length == 0) break;
					const now = date2nano();
					for (const filtered of filters_res.results) {
						prev_main = [filtered.main];
						if (filtered.main.subaccount.length > 0 || filtered.expires_at < now || filtered.allowance < allowance) continue;
						const main_p_txt = filtered.main.owner.toText();
						filters.set(main_p_txt, {
							p: filtered.main.owner,
							allowance: filtered.allowance,
							expires_at: filtered.expires_at,
						});
					}
				}
			} catch (cause) {
				this.notif.errorToast(`Get filtered links failed ${{ prev_main }}`, cause);
			}
		} 
		this.filter_links_busy = false;
		this.filters.clear();
		this.filters = filters;
		this.render();
	};
}