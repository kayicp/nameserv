import { html, render } from 'lit-html';
import PubSub from '../../util/js/pubsub';
import Notif from './model/Notif';
import Wallet from './model/Wallet';
import Token from './model/Token';
import Home from './element/home';
import Register from './element/register';
import { Principal } from '@dfinity/principal';

Principal.prototype.toString = function () {
  return this.toText();
}
Principal.prototype.toJSON = function () {
  return this.toString();
}
BigInt.prototype.toJSON = function () {
  return this.toString();
};
const blob2hex = blob => Array.from(blob).map(byte => byte.toString(16).padStart(2, '0')).join('');
Uint8Array.prototype.toJSON = function () {
  return blob2hex(this) // Array.from(this).toString();
}
const pubsub = new PubSub();
const notif = new Notif(pubsub);
const wallet = new Wallet(notif);
const network = process.env.DFX_NETWORK;
const icrc1s = new Map();
icrc1s.set('ryjl3-tyaaa-aaaaa-aaaba-cai', new Token('ryjl3-tyaaa-aaaaa-aaaba-cai', wallet, 'ICP'));
icrc1s.set('um5iw-rqaaa-aaaaq-qaaba-cai', new Token('um5iw-rqaaa-aaaaq-qaaba-cai', wallet, 'TCYCLES'));

const home = new Home();
const register = new Register();

pubsub.on('refresh', () => {
  // for (const [token_id_txt, token_detail] of icrc1s) {
  //   token_detail.get();
  // };
  // linker.get()
});

class App {
  greeting = '';

  constructor() {
    this.#render();
  }

  #render() {
    let body = html`
      <main>
      </main>
    `;
    render(body, document.getElementById('root'));
  }
}

export default App;
