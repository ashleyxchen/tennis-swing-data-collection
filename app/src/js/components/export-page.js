import WatchMotion from '../services/watch-motion-service.js';

class ExportPage extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this._recordingIds = [];
    this._recordings = [];
    this._exporting = false;
    this._exportPath = null;
    this._summary = null;
  }

  set recordingIds(ids) {
    this._recordingIds = ids || [];
    if (this.isConnected) this._loadRecordings();
  }

  connectedCallback() {
    this.render();
    this._loadRecordings();
  }

  async _loadRecordings() {
    if (this._recordingIds.length === 0) {
      this._updateContent();
      return;
    }

    this._recordings = [];
    for (const id of this._recordingIds) {
      try {
        const rec = await WatchMotion.getRecording({ recordingId: id });
        this._recordings.push(rec);
      } catch (e) { /* skip missing */ }
    }
    this._updateContent();
  }

  _updateContent() {
    const content = this.shadowRoot.querySelector('#content');
    if (!content) return;

    if (this._recordingIds.length === 0) {
      content.innerHTML = `
        <div class="empty">
          <p>No recordings selected for export.</p>
          <p>Go to <a href="#/recordings">Recordings</a> and use Select to choose recordings to export.</p>
        </div>
      `;
      return;
    }

    // Build summary of selected recordings
    const strokeCounts = {};
    const impactCounts = {};
    let totalStrokes = 0;

    this._recordings.forEach(r => {
      strokeCounts[r.strokeType] = (strokeCounts[r.strokeType] || 0) + 1;
      impactCounts[r.impactLabel] = (impactCounts[r.impactLabel] || 0) + 1;
      totalStrokes += r.detectedStrokes || 0;
    });

    let html = `
      <div class="summary-card">
        <div class="summary-title">Export Summary</div>
        <div class="summary-row">
          <span>Recordings</span>
          <span>${this._recordings.length}</span>
        </div>
        <div class="summary-row">
          <span>Total detected strokes</span>
          <span>${totalStrokes}</span>
        </div>
        <div class="summary-divider"></div>
        <div class="summary-subtitle">By Stroke Type</div>
    `;

    for (const [type, count] of Object.entries(strokeCounts)) {
      html += `<div class="summary-row"><span>${type}</span><span>${count}</span></div>`;
    }

    html += `<div class="summary-divider"></div><div class="summary-subtitle">By Impact Label</div>`;

    for (const [label, count] of Object.entries(impactCounts)) {
      html += `<div class="summary-row"><span>${label}</span><span>${count}</span></div>`;
    }

    html += `</div>`;

    if (this._summary) {
      html += `
        <div class="result-card">
          <div class="summary-title">Export Complete</div>
          <div class="summary-row">
            <span>Stroke windows extracted</span>
            <span>${this._summary.totalStrokes || 0}</span>
          </div>
          <button id="btn-share" class="btn btn-share">Share Dataset</button>
        </div>
      `;
    }

    if (!this._exporting && !this._summary) {
      html += `<button id="btn-generate" class="btn btn-generate">Generate Dataset</button>`;
    } else if (this._exporting) {
      html += `<div class="progress">Generating CSV files...</div>`;
    }

    content.innerHTML = html;

    // Wire up buttons
    const genBtn = content.querySelector('#btn-generate');
    if (genBtn) genBtn.onclick = () => this._generate();

    const shareBtn = content.querySelector('#btn-share');
    if (shareBtn) shareBtn.onclick = () => this._share();
  }

  async _generate() {
    this._exporting = true;
    this._updateContent();

    try {
      const result = await WatchMotion.exportDataset({ recordingIds: this._recordingIds });
      this._exportPath = result.exportPath;
      this._summary = result.summary;
    } catch (e) {
      console.warn('exportDataset failed:', e);
    }

    this._exporting = false;
    this._updateContent();
  }

  async _share() {
    if (!this._exportPath) return;
    try {
      await WatchMotion.shareExport({ exportPath: this._exportPath });
    } catch (e) {
      console.warn('shareExport failed:', e);
    }
  }

  render() {
    this.shadowRoot.innerHTML = `
      <style>
        :host { display: block; padding: 16px; }
        .summary-card, .result-card {
          background: #fff;
          border-radius: 12px;
          padding: 16px;
          margin-bottom: 16px;
        }
        .summary-title {
          font-size: 17px;
          font-weight: 600;
          margin-bottom: 12px;
        }
        .summary-subtitle {
          font-size: 13px;
          font-weight: 600;
          color: #666;
          text-transform: uppercase;
          letter-spacing: 0.5px;
          margin-bottom: 8px;
        }
        .summary-row {
          display: flex;
          justify-content: space-between;
          padding: 6px 0;
          font-size: 15px;
        }
        .summary-divider {
          height: 1px;
          background: #e5e5ea;
          margin: 10px 0;
        }
        .btn {
          display: block;
          width: 100%;
          padding: 14px;
          border: none;
          border-radius: 12px;
          font-size: 16px;
          font-weight: 600;
          cursor: pointer;
          text-align: center;
        }
        .btn-generate {
          background: #007aff;
          color: #fff;
        }
        .btn-share {
          background: #34c759;
          color: #fff;
          margin-top: 12px;
        }
        .progress {
          text-align: center;
          padding: 20px;
          color: #666;
          font-style: italic;
        }
        .empty {
          text-align: center;
          padding: 60px 20px;
          color: #8e8e93;
        }
        .empty a {
          color: #007aff;
        }
      </style>
      <div id="content"></div>
    `;
  }
}

customElements.define('export-page', ExportPage);
