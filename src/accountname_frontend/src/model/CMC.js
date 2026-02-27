import { idlFactory, canisterId } from "../additional_declarations/cmc";
import { genActor } from '../../../util/js/actor';
import { html } from 'lit-html';
import { Principal } from '@dfinity/principal';

const is_ic = process.env.DFX_NETWORK === 'ic';
const icp_power = BigInt(10 ** 8);
const per_myriad = 10_000n;
const per_myriad_per_icp = icp_power * per_myriad;
const tcycles_power = BigInt(10 ** 12);

export default class CMC {
	anon = null;

	constructor(wallet) {
		this.id = canisterId;
		this.id_p = Principal.fromText(this.id);
		this.wallet = wallet;
		this.notif = wallet.notif;
		this.xdr_permyriad_per_icp = null;
		this.timestamp_seconds = null;
		this.get();
	}

	render() {
		this.wallet.render();
	};

	async get() {
		this.get_busy = true;
		try {
			if (is_ic) {
				if (this.anon == null) this.anon = await genActor(idlFactory, this.id);

				const icp_xdr = await this.anon.get_icp_xdr_conversion_rate();
				this.xdr_permyriad_per_icp = icp_xdr.data.xdr_permyriad_per_icp;
				this.timestamp_seconds = icp_xdr.data.timestamp_seconds;
			} else {
				this.xdr_permyriad_per_icp = 16_746n;
				this.timestamp_seconds = Date.now() / 1000;
			}
			this.get_busy = false;
			this.render();
		} catch (cause) {
			this.get_busy = false;
			return this.notif.errorToast(`CMC ${shortPrincipal(this.id_p)} Meta Failed`, cause);
		}
	}

	icp(cycles) {
		return (cycles * per_myriad_per_icp) / (tcycles_power * this.xdr_permyriad_per_icp);
	}
}