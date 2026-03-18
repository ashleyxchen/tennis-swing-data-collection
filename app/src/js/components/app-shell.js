import { SplashScreen } from '@capacitor/splash-screen';
import './record-page.js';
import './recordings-page.js';
import './recording-detail-page.js';
import './export-page.js';
import './settings-page.js';

class AppShell extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this._currentPage = null;
    this._exportIds = [];
  }

  connectedCallback() {
    this.render();
    window.addEventListener('hashchange', () => this.route());
    this.route();
    SplashScreen.hide();
  }

  route() {
    const hash = window.location.hash || '#/record';
    const content = this.shadowRoot.querySelector('#content');

    // Remove current page
    if (this._currentPage) {
      this._currentPage.remove();
      this._currentPage = null;
    }

    // Update active nav (recording detail keeps Recordings tab active)
    this.shadowRoot.querySelectorAll('nav a').forEach(a => {
      const href = a.getAttribute('href');
      const isActive = href === hash ||
        (href === '#/recordings' && hash.startsWith('#/recording/'));
      a.classList.toggle('active', isActive);
    });

    let page;
    if (hash.startsWith('#/recording/')) {
      const id = hash.slice('#/recording/'.length);
      page = document.createElement('recording-detail-page');
      page.recordingId = id;
    } else if (hash === '#/record') {
      page = document.createElement('record-page');
    } else if (hash === '#/recordings') {
      page = document.createElement('recordings-page');
    } else if (hash.startsWith('#/export')) {
      page = document.createElement('export-page');
      page.recordingIds = this._exportIds;
    } else if (hash === '#/settings') {
      page = document.createElement('settings-page');
    } else {
      page = document.createElement('record-page');
    }

    content.appendChild(page);
    this._currentPage = page;
  }

  setExportIds(ids) {
    this._exportIds = ids;
  }

  render() {
    this.shadowRoot.innerHTML = `
      <style>
        :host {
          display: flex;
          flex-direction: column;
          height: 100%;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          color: #1a1a1a;
          background: #f5f5f7;
        }
        header {
          background: #1a1a1a;
          color: #fff;
          padding: 12px 16px;
          padding-top: max(env(safe-area-inset-top), 12px);
          text-align: center;
        }
        header h1 {
          margin: 0;
          font-size: 17px;
          font-weight: 600;
          letter-spacing: 0.5px;
        }
        #content {
          flex: 1;
          overflow-y: auto;
          -webkit-overflow-scrolling: touch;
        }
        nav {
          display: flex;
          background: #fff;
          border-top: 1px solid #d1d1d6;
          padding-bottom: env(safe-area-inset-bottom);
        }
        nav a {
          flex: 1;
          text-align: center;
          padding: 8px 0 6px;
          text-decoration: none;
          font-size: 10px;
          font-weight: 500;
          color: #8e8e93;
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 2px;
        }
        nav a.active {
          color: #007aff;
        }
        nav a svg {
          width: 24px;
          height: 24px;
          fill: currentColor;
        }
      </style>
      <header>
        <h1>Motion Collector</h1>
      </header>
      <div id="content"></div>
      <nav>
        <a href="#/record" class="active">
          <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="12" cy="12" r="4"/></svg>
          Record
        </a>
        <a href="#/recordings">
          <svg viewBox="0 0 24 24"><path d="M3 13h2v-2H3v2zm0 4h2v-2H3v2zm0-8h2V7H3v2zm4 4h14v-2H7v2zm0 4h14v-2H7v2zM7 7v2h14V7H7z"/></svg>
          Recordings
        </a>
        <a href="#/settings">
          <svg viewBox="0 0 24 24"><path d="M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58a.49.49 0 00.12-.61l-1.92-3.32a.49.49 0 00-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54a.484.484 0 00-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96a.49.49 0 00-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.07.62-.07.94s.02.64.07.94l-2.03 1.58a.49.49 0 00-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6A3.6 3.6 0 1112 8.4a3.6 3.6 0 010 7.2z"/></svg>
          Settings
        </a>
      </nav>
    `;
  }
}

customElements.define('app-shell', AppShell);
