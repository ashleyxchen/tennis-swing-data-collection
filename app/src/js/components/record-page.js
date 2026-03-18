import WatchMotion from '../services/watch-motion-service.js';

class RecordPage extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this._state = 'idle'; // idle, recording, paused, transferring, processing
    this._recordingId = null;
    this._strokeType = 'forehand';
    this._impactLabel = 'impact';
    this._elapsedMs = 0;
    this._sampleCount = 0;
    this._watchStatus = { isReachable: false, isPaired: false, isWatchAppInstalled: false };
    this._listeners = [];
  }

  connectedCallback() {
    this.render();
    this._pollStatus();
    this._addListeners();
  }

  disconnectedCallback() {
    this._listeners.forEach(h => h.remove());
    this._listeners = [];
    if (this._pollTimer) clearInterval(this._pollTimer);
  }

  async _pollStatus() {
    try {
      this._watchStatus = await WatchMotion.getWatchStatus();
      this._updateStatusIndicator();
    } catch (e) {
      console.warn('getWatchStatus failed:', e);
    }
    this._pollTimer = setInterval(async () => {
      try {
        this._watchStatus = await WatchMotion.getWatchStatus();
        this._updateStatusIndicator();
      } catch (e) { /* ignore */ }
    }, 3000);
  }

  _addListeners() {
    const stateListener = WatchMotion.addListener('recordingStateChanged', (data) => {
      if (data.state) this._state = data.state;
      if (data.sampleCount != null) this._sampleCount = data.sampleCount;
      if (data.elapsedMs != null) this._elapsedMs = data.elapsedMs;
      this._updateRecordingUI();
    });

    const completeListener = WatchMotion.addListener('recordingComplete', (data) => {
      this._state = 'idle';
      this._sampleCount = data.sampleCount || 0;
      this._updateRecordingUI();
      this._showCompleteBanner(data);
    });

    const errorListener = WatchMotion.addListener('watchError', (data) => {
      this._showError(data.message || 'Watch error');
    });

    this._listeners.push(stateListener, completeListener, errorListener);
  }

  _updateStatusIndicator() {
    const dot = this.shadowRoot.querySelector('#status-dot');
    const label = this.shadowRoot.querySelector('#status-label');
    if (!dot || !label) return;

    if (this._watchStatus.isReachable) {
      dot.style.background = '#34c759';
      label.textContent = 'Watch Connected';
    } else if (this._watchStatus.isPaired && this._watchStatus.isWatchAppInstalled) {
      dot.style.background = '#ff9500';
      label.textContent = 'Watch Paired (Open watch app)';
    } else if (this._watchStatus.isPaired && !this._watchStatus.isWatchAppInstalled) {
      dot.style.background = '#ff3b30';
      label.textContent = 'Watch App Not Installed';
    } else {
      dot.style.background = '#ff3b30';
      label.textContent = 'Watch Not Paired';
    }
  }

  _updateRecordingUI() {
    const stateEl = this.shadowRoot.querySelector('#rec-state');
    const timeEl = this.shadowRoot.querySelector('#rec-time');
    const samplesEl = this.shadowRoot.querySelector('#rec-samples');
    const controls = this.shadowRoot.querySelector('#controls');
    const config = this.shadowRoot.querySelector('#config');
    const livePanel = this.shadowRoot.querySelector('#live-panel');

    if (this._state === 'idle') {
      if (config) config.style.display = '';
      if (livePanel) livePanel.style.display = 'none';
      if (controls) {
        controls.innerHTML = `<button id="btn-start" class="btn btn-start">Start Recording</button>`;
        controls.querySelector('#btn-start').onclick = () => this._start();
      }
    } else {
      if (config) config.style.display = 'none';
      if (livePanel) livePanel.style.display = '';
      if (stateEl) stateEl.textContent = this._state.toUpperCase();
      if (timeEl) timeEl.textContent = this._formatTime(this._elapsedMs);
      if (samplesEl) samplesEl.textContent = this._sampleCount.toLocaleString();

      if (controls) {
        if (this._state === 'recording') {
          controls.innerHTML = `
            <button id="btn-pause" class="btn btn-pause">Pause</button>
            <button id="btn-stop" class="btn btn-stop">Stop</button>
          `;
          controls.querySelector('#btn-pause').onclick = () => this._pause();
          controls.querySelector('#btn-stop').onclick = () => this._stop();
        } else if (this._state === 'paused') {
          controls.innerHTML = `
            <button id="btn-resume" class="btn btn-resume">Resume</button>
            <button id="btn-stop" class="btn btn-stop">Stop</button>
          `;
          controls.querySelector('#btn-resume').onclick = () => this._resume();
          controls.querySelector('#btn-stop').onclick = () => this._stop();
        } else {
          controls.innerHTML = `<p class="processing-text">Processing...</p>`;
        }
      }
    }
  }

  async _start() {
    try {
      const result = await WatchMotion.startRecording({
        strokeType: this._strokeType,
        impactLabel: this._impactLabel,
      });
      this._recordingId = result.recordingId;
      this._state = 'recording';
      this._elapsedMs = 0;
      this._sampleCount = 0;
      this._updateRecordingUI();
    } catch (e) {
      this._showError(e.message || 'Failed to start recording');
    }
  }

  async _pause() {
    if (!this._recordingId) return;
    try {
      await WatchMotion.pauseRecording({ recordingId: this._recordingId });
      this._state = 'paused';
      this._updateRecordingUI();
    } catch (e) {
      this._showError(e.message || 'Failed to pause');
    }
  }

  async _resume() {
    if (!this._recordingId) return;
    try {
      await WatchMotion.resumeRecording({ recordingId: this._recordingId });
      this._state = 'recording';
      this._updateRecordingUI();
    } catch (e) {
      this._showError(e.message || 'Failed to resume');
    }
  }

  async _stop() {
    if (!this._recordingId) return;
    try {
      await WatchMotion.stopRecording({ recordingId: this._recordingId });
      this._state = 'transferring';
      this._updateRecordingUI();
    } catch (e) {
      this._showError(e.message || 'Failed to stop');
    }
  }

  _showCompleteBanner(data) {
    const banner = this.shadowRoot.querySelector('#banner');
    if (!banner) return;
    banner.textContent = `Recording complete: ${data.strokesDetected || 0} strokes detected (${data.sampleCount || 0} samples)`;
    banner.style.display = 'block';
    setTimeout(() => { banner.style.display = 'none'; }, 5000);
  }

  _showError(msg) {
    const banner = this.shadowRoot.querySelector('#banner');
    if (!banner) return;
    banner.textContent = msg;
    banner.style.background = '#ff3b30';
    banner.style.display = 'block';
    setTimeout(() => {
      banner.style.display = 'none';
      banner.style.background = '';
    }, 4000);
  }

  _formatTime(ms) {
    const totalSec = Math.floor(ms / 1000);
    const min = Math.floor(totalSec / 60);
    const sec = totalSec % 60;
    return `${min}:${sec.toString().padStart(2, '0')}`;
  }

  _selectStroke(type) {
    this._strokeType = type;
    this.shadowRoot.querySelectorAll('.stroke-btn').forEach(b => {
      b.classList.toggle('selected', b.dataset.type === type);
    });
  }

  _selectImpact(label) {
    this._impactLabel = label;
    this.shadowRoot.querySelectorAll('.impact-btn').forEach(b => {
      b.classList.toggle('selected', b.dataset.label === label);
    });
  }

  render() {
    this.shadowRoot.innerHTML = `
      <style>
        :host { display: block; padding: 16px; }
        .status-bar {
          display: flex;
          align-items: center;
          gap: 8px;
          padding: 10px 12px;
          background: #fff;
          border-radius: 10px;
          margin-bottom: 16px;
        }
        #status-dot {
          width: 10px;
          height: 10px;
          border-radius: 50%;
          background: #ff3b30;
          flex-shrink: 0;
        }
        #status-label {
          font-size: 14px;
          color: #666;
        }
        .section-label {
          font-size: 13px;
          font-weight: 600;
          color: #666;
          text-transform: uppercase;
          letter-spacing: 0.5px;
          margin-bottom: 8px;
        }
        .picker {
          display: flex;
          gap: 8px;
          flex-wrap: wrap;
          margin-bottom: 20px;
        }
        .stroke-btn, .impact-btn {
          padding: 10px 16px;
          border: 2px solid #d1d1d6;
          border-radius: 10px;
          background: #fff;
          font-size: 14px;
          font-weight: 500;
          cursor: pointer;
          transition: all 0.15s;
        }
        .stroke-btn.selected {
          border-color: #007aff;
          background: #e8f0fe;
          color: #007aff;
        }
        .impact-btn.selected {
          border-color: #34c759;
          background: #e8f8ed;
          color: #34c759;
        }
        #controls {
          display: flex;
          gap: 12px;
          justify-content: center;
          margin-top: 24px;
        }
        .btn {
          padding: 14px 32px;
          border: none;
          border-radius: 12px;
          font-size: 16px;
          font-weight: 600;
          cursor: pointer;
          min-width: 120px;
        }
        .btn-start { background: #34c759; color: #fff; }
        .btn-pause { background: #ff9500; color: #fff; }
        .btn-resume { background: #007aff; color: #fff; }
        .btn-stop { background: #ff3b30; color: #fff; }
        #live-panel {
          display: none;
          background: #fff;
          border-radius: 12px;
          padding: 20px;
          text-align: center;
        }
        #rec-state {
          font-size: 13px;
          font-weight: 600;
          letter-spacing: 1px;
          color: #34c759;
          margin-bottom: 8px;
        }
        #rec-time {
          font-size: 48px;
          font-weight: 300;
          font-variant-numeric: tabular-nums;
          margin-bottom: 4px;
        }
        #rec-samples {
          font-size: 14px;
          color: #666;
        }
        .processing-text {
          text-align: center;
          color: #666;
          font-style: italic;
        }
        #banner {
          display: none;
          position: fixed;
          top: max(env(safe-area-inset-top), 12px);
          left: 16px;
          right: 16px;
          padding: 12px 16px;
          background: #34c759;
          color: #fff;
          border-radius: 10px;
          font-size: 14px;
          font-weight: 500;
          text-align: center;
          z-index: 100;
        }
      </style>

      <div id="banner"></div>

      <div class="status-bar">
        <div id="status-dot"></div>
        <span id="status-label">Checking...</span>
      </div>

      <div id="config">
        <div class="section-label">Stroke Type</div>
        <div class="picker">
          <button class="stroke-btn selected" data-type="forehand">Forehand</button>
          <button class="stroke-btn" data-type="backhand">Backhand</button>
          <button class="stroke-btn" data-type="serve">Serve</button>
          <button class="stroke-btn" data-type="shadow_swing">Shadow</button>
          <button class="stroke-btn" data-type="idle">Idle</button>
        </div>

        <div class="section-label">Impact Label</div>
        <div class="picker">
          <button class="impact-btn selected" data-label="impact">Impact</button>
          <button class="impact-btn" data-label="no_impact">No Impact</button>
        </div>
      </div>

      <div id="live-panel">
        <div id="rec-state">RECORDING</div>
        <div id="rec-time">0:00</div>
        <div id="rec-samples">0 samples</div>
      </div>

      <div id="controls">
        <button id="btn-start" class="btn btn-start">Start Recording</button>
      </div>
    `;

    // Wire up stroke type buttons
    this.shadowRoot.querySelectorAll('.stroke-btn').forEach(btn => {
      btn.addEventListener('click', () => this._selectStroke(btn.dataset.type));
    });

    // Wire up impact label buttons
    this.shadowRoot.querySelectorAll('.impact-btn').forEach(btn => {
      btn.addEventListener('click', () => this._selectImpact(btn.dataset.label));
    });

    // Wire up start button
    this.shadowRoot.querySelector('#btn-start').addEventListener('click', () => this._start());
  }
}

customElements.define('record-page', RecordPage);
