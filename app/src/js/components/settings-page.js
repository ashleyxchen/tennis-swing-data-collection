import WatchMotion from '../services/watch-motion-service.js';

class SettingsPage extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this._accelThreshold = 3.0;
    this._gyroThreshold = 8.0;
    this._saved = false;
  }

  connectedCallback() {
    this.render();
    this._loadSettings();
  }

  async _loadSettings() {
    try {
      const settings = await WatchMotion.getSettings();
      this._accelThreshold = settings.accelThreshold ?? 3.0;
      this._gyroThreshold = settings.gyroThreshold ?? 8.0;
      this._updateSliders();
    } catch (e) {
      console.warn('getSettings failed:', e);
    }
  }

  _updateSliders() {
    const accelSlider = this.shadowRoot.querySelector('#accel-slider');
    const accelValue = this.shadowRoot.querySelector('#accel-value');
    const gyroSlider = this.shadowRoot.querySelector('#gyro-slider');
    const gyroValue = this.shadowRoot.querySelector('#gyro-value');

    if (accelSlider) accelSlider.value = this._accelThreshold;
    if (accelValue) accelValue.textContent = this._accelThreshold.toFixed(1);
    if (gyroSlider) gyroSlider.value = this._gyroThreshold;
    if (gyroValue) gyroValue.textContent = this._gyroThreshold.toFixed(1);
  }

  async _save() {
    try {
      await WatchMotion.updateSettings({
        accelThreshold: this._accelThreshold,
        gyroThreshold: this._gyroThreshold,
      });
      this._saved = true;
      const banner = this.shadowRoot.querySelector('#banner');
      if (banner) {
        banner.style.display = 'block';
        setTimeout(() => {
          banner.style.display = 'none';
        }, 2000);
      }
    } catch (e) {
      console.warn('updateSettings failed:', e);
    }
  }

  render() {
    this.shadowRoot.innerHTML = `
      <style>
        :host { display: block; padding: 16px; }
        .card {
          background: #fff;
          border-radius: 12px;
          padding: 16px;
          margin-bottom: 16px;
        }
        .card-title {
          font-size: 17px;
          font-weight: 600;
          margin-bottom: 16px;
        }
        .setting-row {
          margin-bottom: 20px;
        }
        .setting-label {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 8px;
        }
        .setting-name {
          font-size: 15px;
          font-weight: 500;
        }
        .setting-value {
          font-size: 15px;
          font-weight: 600;
          color: #007aff;
          font-variant-numeric: tabular-nums;
        }
        .setting-desc {
          font-size: 12px;
          color: #8e8e93;
          margin-bottom: 8px;
        }
        input[type="range"] {
          width: 100%;
          height: 4px;
          -webkit-appearance: none;
          appearance: none;
          background: #e5e5ea;
          border-radius: 2px;
          outline: none;
        }
        input[type="range"]::-webkit-slider-thumb {
          -webkit-appearance: none;
          appearance: none;
          width: 28px;
          height: 28px;
          background: #fff;
          border: 2px solid #007aff;
          border-radius: 50%;
          cursor: pointer;
          box-shadow: 0 1px 3px rgba(0,0,0,0.15);
        }
        .btn-save {
          display: block;
          width: 100%;
          padding: 14px;
          border: none;
          border-radius: 12px;
          background: #007aff;
          color: #fff;
          font-size: 16px;
          font-weight: 600;
          cursor: pointer;
        }
        #banner {
          display: none;
          text-align: center;
          padding: 10px;
          background: #34c759;
          color: #fff;
          border-radius: 10px;
          font-size: 14px;
          font-weight: 500;
          margin-bottom: 12px;
        }
      </style>

      <div id="banner">Settings saved</div>

      <div class="card">
        <div class="card-title">Swing Detection Thresholds</div>

        <div class="setting-row">
          <div class="setting-label">
            <span class="setting-name">Accelerometer Threshold</span>
            <span class="setting-value" id="accel-value">${this._accelThreshold.toFixed(1)}</span>
          </div>
          <div class="setting-desc">Acceleration magnitude (g) to trigger swing detection. Range: 1.0 - 10.0</div>
          <input type="range" id="accel-slider" min="0.1" max="10.0" step="0.05" value="${this._accelThreshold}">
        </div>

        <div class="setting-row">
          <div class="setting-label">
            <span class="setting-name">Gyroscope Threshold</span>
            <span class="setting-value" id="gyro-value">${this._gyroThreshold.toFixed(1)}</span>
          </div>
          <div class="setting-desc">Rotation rate magnitude (rad/s) to trigger swing detection. Range: 2.0 - 20.0</div>
          <input type="range" id="gyro-slider" min="0.1" max="20.0" step="0.05" value="${this._gyroThreshold}">
        </div>
      </div>

      <button class="btn-save" id="btn-save">Save Settings</button>
    `;

    // Wire up sliders
    this.shadowRoot.querySelector('#accel-slider').addEventListener('input', (e) => {
      this._accelThreshold = parseFloat(e.target.value);
      this.shadowRoot.querySelector('#accel-value').textContent = this._accelThreshold.toFixed(1);
    });

    this.shadowRoot.querySelector('#gyro-slider').addEventListener('input', (e) => {
      this._gyroThreshold = parseFloat(e.target.value);
      this.shadowRoot.querySelector('#gyro-value').textContent = this._gyroThreshold.toFixed(1);
    });

    this.shadowRoot.querySelector('#btn-save').addEventListener('click', () => this._save());
  }
}

customElements.define('settings-page', SettingsPage);
