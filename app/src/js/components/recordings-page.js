import WatchMotion from '../services/watch-motion-service.js';

class RecordingsPage extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this._recordings = [];
    this._selected = new Set();
    this._selectMode = false;
  }

  connectedCallback() {
    this.render();
    this._loadRecordings();

    // Listen for new completions
    this._listener = WatchMotion.addListener('recordingComplete', () => {
      this._loadRecordings();
    });
  }

  disconnectedCallback() {
    if (this._listener) this._listener.remove();
  }

  async _loadRecordings() {
    try {
      const result = await WatchMotion.listRecordings();
      this._recordings = (result.recordings || []).sort(
        (a, b) => new Date(b.createdAt) - new Date(a.createdAt)
      );
      this._renderList();
    } catch (e) {
      console.warn('listRecordings failed:', e);
    }
  }

  _toggleSelectMode() {
    this._selectMode = !this._selectMode;
    this._selected.clear();
    this._renderList();
  }

  _toggleSelect(id) {
    if (this._selected.has(id)) {
      this._selected.delete(id);
    } else {
      this._selected.add(id);
    }
    this._renderList();
  }

  _selectAll() {
    if (this._selected.size === this._recordings.length) {
      this._selected.clear();
    } else {
      this._recordings.forEach(r => this._selected.add(r.id));
    }
    this._renderList();
  }

  async _deleteSelected() {
    if (this._selected.size === 0) return;
    const ids = [...this._selected];
    try {
      await WatchMotion.deleteRecordings({ recordingIds: ids });
      this._selected.clear();
      this._selectMode = false;
      await this._loadRecordings();
    } catch (e) {
      console.warn('deleteRecordings failed:', e);
    }
  }

  async _deleteOne(id) {
    try {
      await WatchMotion.deleteRecording({ recordingId: id });
      await this._loadRecordings();
    } catch (e) {
      console.warn('deleteRecording failed:', e);
    }
  }

  async _renameOne(id, currentName) {
    const newName = prompt('Rename recording:', currentName);
    if (!newName || newName === currentName) return;
    try {
      await WatchMotion.renameRecording({ recordingId: id, name: newName });
      await this._loadRecordings();
    } catch (e) {
      console.warn('renameRecording failed:', e);
    }
  }

  _exportSelected() {
    if (this._selected.size === 0) return;
    const shell = document.querySelector('app-shell');
    if (shell) shell.setExportIds([...this._selected]);
    window.location.hash = '#/export';
  }

  _formatDate(dateStr) {
    const d = new Date(dateStr);
    return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
  }

  _stateColor(state) {
    switch (state) {
      case 'complete': return '#34c759';
      case 'recording': return '#007aff';
      case 'paused': return '#ff9500';
      case 'transferring': case 'processing': return '#ff9500';
      case 'error': return '#ff3b30';
      default: return '#8e8e93';
    }
  }

  _renderList() {
    const list = this.shadowRoot.querySelector('#list');
    const toolbar = this.shadowRoot.querySelector('#toolbar');
    const emptyEl = this.shadowRoot.querySelector('#empty');

    if (this._recordings.length === 0) {
      list.innerHTML = '';
      emptyEl.style.display = 'block';
      toolbar.style.display = 'none';
      return;
    }

    emptyEl.style.display = 'none';
    toolbar.style.display = 'flex';

    // Toolbar
    if (this._selectMode) {
      toolbar.innerHTML = `
        <button id="btn-select-all" class="toolbar-btn">${this._selected.size === this._recordings.length ? 'Deselect All' : 'Select All'}</button>
        <span class="toolbar-count">${this._selected.size} selected</span>
        <button id="btn-delete-sel" class="toolbar-btn danger" ${this._selected.size === 0 ? 'disabled' : ''}>Delete</button>
        <button id="btn-export-sel" class="toolbar-btn primary" ${this._selected.size === 0 ? 'disabled' : ''}>Export</button>
        <button id="btn-done" class="toolbar-btn">Done</button>
      `;
      toolbar.querySelector('#btn-select-all').onclick = () => this._selectAll();
      toolbar.querySelector('#btn-delete-sel').onclick = () => this._deleteSelected();
      toolbar.querySelector('#btn-export-sel').onclick = () => this._exportSelected();
      toolbar.querySelector('#btn-done').onclick = () => this._toggleSelectMode();
    } else {
      toolbar.innerHTML = `
        <span class="toolbar-count">${this._recordings.length} recording${this._recordings.length !== 1 ? 's' : ''}</span>
        <button id="btn-select" class="toolbar-btn">Select</button>
      `;
      toolbar.querySelector('#btn-select').onclick = () => this._toggleSelectMode();
    }

    // List
    list.innerHTML = this._recordings.map(r => `
      <div class="item ${this._selected.has(r.id) ? 'selected' : ''}" data-id="${r.id}">
        ${this._selectMode ? `<div class="checkbox ${this._selected.has(r.id) ? 'checked' : ''}"></div>` : ''}
        <div class="item-content">
          <div class="item-header">
            <span class="item-name">${r.name || 'Untitled'}</span>
            <span class="item-state" style="color: ${this._stateColor(r.state)}">${r.state}</span>
          </div>
          <div class="item-meta">
            <span class="tag stroke">${r.strokeType}</span>
            <span class="tag impact">${r.impactLabel}</span>
            ${r.detectedStrokes != null ? `<span class="meta-text">${r.detectedStrokes} strokes</span>` : ''}
            ${r.sampleCount != null ? `<span class="meta-text">${r.sampleCount} samples</span>` : ''}
          </div>
          <div class="item-date">${this._formatDate(r.createdAt)}</div>
        </div>
        ${!this._selectMode ? `
          <div class="item-actions">
            <button class="action-btn rename-btn" data-id="${r.id}" data-name="${(r.name || '').replace(/"/g, '&quot;')}">Rename</button>
            <button class="action-btn delete-btn" data-id="${r.id}">Delete</button>
          </div>
        ` : ''}
      </div>
    `).join('');

    // Wire up events
    if (this._selectMode) {
      list.querySelectorAll('.item').forEach(item => {
        item.addEventListener('click', () => this._toggleSelect(item.dataset.id));
      });
    } else {
      list.querySelectorAll('.item-content').forEach(el => {
        el.addEventListener('click', () => {
          const id = el.closest('.item').dataset.id;
          window.location.hash = `#/recording/${id}`;
        });
      });
      list.querySelectorAll('.rename-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          this._renameOne(btn.dataset.id, btn.dataset.name);
        });
      });
      list.querySelectorAll('.delete-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          this._deleteOne(btn.dataset.id);
        });
      });
    }
  }

  render() {
    this.shadowRoot.innerHTML = `
      <style>
        :host { display: block; padding: 16px; }
        #toolbar {
          display: none;
          align-items: center;
          gap: 8px;
          margin-bottom: 12px;
          flex-wrap: wrap;
        }
        .toolbar-btn {
          padding: 6px 12px;
          border: 1px solid #d1d1d6;
          border-radius: 8px;
          background: #fff;
          font-size: 13px;
          font-weight: 500;
          cursor: pointer;
        }
        .toolbar-btn.primary {
          background: #007aff;
          color: #fff;
          border-color: #007aff;
        }
        .toolbar-btn.danger {
          color: #ff3b30;
          border-color: #ff3b30;
        }
        .toolbar-btn:disabled {
          opacity: 0.4;
          cursor: default;
        }
        .toolbar-count {
          font-size: 13px;
          color: #666;
          flex: 1;
        }
        .item {
          display: flex;
          align-items: center;
          gap: 12px;
          background: #fff;
          border-radius: 10px;
          padding: 12px;
          margin-bottom: 8px;
        }
        .item.selected {
          background: #e8f0fe;
        }
        .checkbox {
          width: 22px;
          height: 22px;
          border-radius: 50%;
          border: 2px solid #d1d1d6;
          flex-shrink: 0;
        }
        .checkbox.checked {
          background: #007aff;
          border-color: #007aff;
        }
        .item-content {
          flex: 1;
          min-width: 0;
          cursor: pointer;
        }
        .item-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 4px;
        }
        .item-name {
          font-size: 15px;
          font-weight: 500;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }
        .item-state {
          font-size: 11px;
          font-weight: 600;
          text-transform: uppercase;
          letter-spacing: 0.5px;
        }
        .item-meta {
          display: flex;
          gap: 6px;
          align-items: center;
          flex-wrap: wrap;
          margin-bottom: 2px;
        }
        .tag {
          font-size: 11px;
          padding: 2px 6px;
          border-radius: 4px;
          font-weight: 500;
        }
        .tag.stroke {
          background: #e8f0fe;
          color: #007aff;
        }
        .tag.impact {
          background: #e8f8ed;
          color: #34c759;
        }
        .meta-text {
          font-size: 12px;
          color: #8e8e93;
        }
        .item-date {
          font-size: 12px;
          color: #8e8e93;
        }
        .item-actions {
          display: flex;
          gap: 4px;
          flex-shrink: 0;
        }
        .action-btn {
          padding: 4px 8px;
          border: 1px solid #d1d1d6;
          border-radius: 6px;
          background: #fff;
          font-size: 12px;
          cursor: pointer;
        }
        .delete-btn {
          color: #ff3b30;
          border-color: #ffcdd2;
        }
        #empty {
          display: none;
          text-align: center;
          padding: 60px 20px;
          color: #8e8e93;
          font-size: 15px;
        }
      </style>

      <div id="toolbar"></div>
      <div id="list"></div>
      <div id="empty">No recordings yet. Go to Record to start collecting data.</div>
    `;
  }
}

customElements.define('recordings-page', RecordingsPage);
