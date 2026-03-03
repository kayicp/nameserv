import { html, render } from 'lit-html';
import PubSub from '../../util/js/pubsub';
import Notif from './model/Notif';
import Wallet from './model/Wallet';
import Token from './model/Token';
import Namer from './model/Namer';
import Linker from './model/Linker';
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

const icp_token = new Token('ryjl3-tyaaa-aaaaa-aaaba-cai', wallet, 'ICP');
const tcycles_token = new Token('um5iw-rqaaa-aaaaq-qaaba-cai', wallet, 'TCYCLES');

const namer = new Namer('zyfw5-4qaaa-aaaac-qc7za-cai', wallet, icp_token, tcycles_token);
const home = new Home(namer);

const linker = new Linker('lhuc4-nqaaa-aaaan-qz3gq-cai', wallet, icp_token, tcycles_token, namer.id_p);
const register = new Register(namer, linker);

pubsub.on('refresh', () => {
  // for (const [token_id_txt, token_detail] of icrc1s) {
  //   token_detail.get();
  // };
  // linker.get()
});


pubsub.on('render', _render);
window.addEventListener('popstate', _render);


function _render() {
  const pathn = window.location.pathname;
  let page = html`<div class="text-xs text-slate-400">404: Not Found</div>`;
  if (pathn == Home.PATH) {
    page = home.render();
  } else if (pathn.startsWith(Register.PATH)) {
    page = register.render();
  }
  const body = html`
    <div class="min-h-screen flex flex-col">
      <header class="flex items-center gap-2 p-2 bg-slate-900 border-b border-slate-800 sticky top-0 z-10">
        <button
          class="inline-flex items-center px-2 py-1 text-xs rounded-md font-medium bg-slate-800 hover:bg-slate-700 text-slate-100 ring-1 ring-slate-700"
          @click=${() => {
            history.pushState({}, '', '/'); 
            window.dispatchEvent(new PopStateEvent('popstate'));
            _render();
          }}>
          ICRC ANS
        </button>

        <div class="flex items-center gap-2 ml-2">
          ${register.button}
        </div>

        <div class="ml-auto">
          ${wallet.button()}
        </div>
      </header>

      <main class="p-3 max-w-6xl mx-auto flex-1 relative">
        ${page}
      </main>

      <footer class="p-2 text-xs text-slate-400">
        © ICRC Account Name Service
      </footer>

      ${notif.draw()}
    </div>
  `;
  render(body, document.getElementById('root'));
};

class App {
  constructor() {
    _render();
  }
}
export default App;
