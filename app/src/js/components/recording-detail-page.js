import { Chart, registerables } from 'chart.js';
import annotationPlugin from 'chartjs-plugin-annotation';
import WatchMotion from '../services/watch-motion-service.js';

Chart.register(...registerables, annotationPlugin);

class RecordingDetailPage extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this._recordingId = null;
    this._chart = null;
  }

  set recordingId(id) {
    this._recordingId = id;
    if (this.isConnected) this._load();
  }

  connectedCallback() {
    this.render();
    if (this._recordingId) this._load();
  }

  disconnectedCallback() {
    if (this._chart) {
      this._chart.destroy();
      this._chart = null;
    }
  }

  async _load() {
    const container = this.shadowRoot.querySelector('#header-card');
    const chartWrap = this.shadowRoot.querySelector('#chart-wrap');
    const loading = this.shadowRoot.querySelector('#loading');
    const errorEl = this.shadowRoot.querySelector('#error');

    loading.style.display = 'block';
    errorEl.style.display = 'none';
    container.style.display = 'none';
    chartWrap.style.display = 'none';

    try {
      // Load recording metadata and sample data in parallel
      const [recording, samplesResult] = await Promise.all([
        WatchMotion.getRecording({ recordingId: this._recordingId }),
        WatchMotion.getRecordingSamples({ recordingId: this._recordingId, maxPoints: 2000 })
      ]);

      loading.style.display = 'none';
      container.style.display = 'block';
      chartWrap.style.display = 'block';

      this._renderHeader(recording);
      this._renderChart(samplesResult, recording);
    } catch (e) {
      console.warn('Failed to load recording detail:', e);
      loading.style.display = 'none';
      errorEl.style.display = 'block';
      errorEl.textContent = 'Failed to load recording data.';
    }
  }

  _renderHeader(rec) {
    const card = this.shadowRoot.querySelector('#header-card');
    const durationSec = rec.durationMs != null ? (rec.durationMs / 1000).toFixed(1) : '--';

    card.innerHTML = `
      <h2 class="rec-name">${rec.name || 'Untitled'}</h2>
      <div class="tags">
        <span class="tag stroke">${rec.strokeType}</span>
        <span class="tag impact">${rec.impactLabel}</span>
      </div>
      <div class="meta-grid">
        <div class="meta-item">
          <span class="meta-label">Duration</span>
          <span class="meta-value">${durationSec}s</span>
        </div>
        <div class="meta-item">
          <span class="meta-label">Samples</span>
          <span class="meta-value">${rec.sampleCount ?? '--'}</span>
        </div>
        <div class="meta-item">
          <span class="meta-label">Strokes</span>
          <span class="meta-value">${rec.detectedStrokes ?? '--'}</span>
        </div>
      </div>
      <div class="threshold-row">
        <span class="threshold-label">Accel threshold:</span>
        <span class="threshold-value">${rec.accelThreshold} g</span>
        <span class="threshold-label">Gyro threshold:</span>
        <span class="threshold-value">${rec.gyroThreshold} rad/s</span>
      </div>
    `;
  }

  _renderChart(data, rec) {
    if (this._chart) {
      this._chart.destroy();
      this._chart = null;
    }

    const canvas = this.shadowRoot.querySelector('#chart');
    const { timestamps, accelMagnitudes, gyroMagnitudes, peakTimestamps } = data;

    // Convert ms to seconds for display
    const timesSec = timestamps.map(t => t / 1000);
    const peaksSec = peakTimestamps.map(t => t / 1000);

    // Build peak annotations
    const annotations = {};
    peaksSec.forEach((t, i) => {
      annotations[`peak${i}`] = {
        type: 'line',
        xMin: t,
        xMax: t,
        borderColor: 'rgba(255, 59, 48, 0.7)',
        borderWidth: 1.5,
        borderDash: [4, 3],
        label: {
          display: true,
          content: `P${i + 1}`,
          position: 'start',
          backgroundColor: 'rgba(255, 59, 48, 0.8)',
          color: '#fff',
          font: { size: 9, weight: 'bold' },
          padding: 2
        }
      };
    });

    // Threshold lines
    annotations['accelThreshold'] = {
      type: 'line',
      yMin: rec.accelThreshold,
      yMax: rec.accelThreshold,
      yScaleID: 'yAccel',
      borderColor: 'rgba(0, 122, 255, 0.4)',
      borderWidth: 1,
      borderDash: [6, 3],
      label: {
        display: true,
        content: `${rec.accelThreshold}g`,
        position: 'start',
        backgroundColor: 'rgba(0, 122, 255, 0.6)',
        color: '#fff',
        font: { size: 9 },
        padding: 2
      }
    };
    annotations['gyroThreshold'] = {
      type: 'line',
      yMin: rec.gyroThreshold,
      yMax: rec.gyroThreshold,
      yScaleID: 'yGyro',
      borderColor: 'rgba(255, 149, 0, 0.4)',
      borderWidth: 1,
      borderDash: [6, 3],
      label: {
        display: true,
        content: `${rec.gyroThreshold} rad/s`,
        position: 'end',
        backgroundColor: 'rgba(255, 149, 0, 0.6)',
        color: '#fff',
        font: { size: 9 },
        padding: 2
      }
    };

    // Build data points
    const accelData = timesSec.map((t, i) => ({ x: t, y: accelMagnitudes[i] }));
    const gyroData = timesSec.map((t, i) => ({ x: t, y: gyroMagnitudes[i] }));

    this._chart = new Chart(canvas, {
      type: 'line',
      data: {
        datasets: [
          {
            label: 'Accel Magnitude (g)',
            data: accelData,
            borderColor: 'rgba(0, 122, 255, 0.9)',
            backgroundColor: 'rgba(0, 122, 255, 0.1)',
            borderWidth: 1.5,
            pointRadius: 0,
            tension: 0.2,
            yAxisID: 'yAccel',
            fill: false
          },
          {
            label: 'Gyro Magnitude (rad/s)',
            data: gyroData,
            borderColor: 'rgba(255, 149, 0, 0.9)',
            backgroundColor: 'rgba(255, 149, 0, 0.1)',
            borderWidth: 1.5,
            pointRadius: 0,
            tension: 0.2,
            yAxisID: 'yGyro',
            fill: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false
        },
        scales: {
          x: {
            type: 'linear',
            title: { display: true, text: 'Time (s)', font: { size: 11 } },
            ticks: { font: { size: 10 }, maxTicksLimit: 10 }
          },
          yAccel: {
            type: 'linear',
            position: 'left',
            title: { display: true, text: 'Accel (g)', color: 'rgba(0, 122, 255, 0.9)', font: { size: 11 } },
            ticks: { font: { size: 10 }, color: 'rgba(0, 122, 255, 0.7)' },
            beginAtZero: true,
            grid: { drawOnChartArea: true }
          },
          yGyro: {
            type: 'linear',
            position: 'right',
            title: { display: true, text: 'Gyro (rad/s)', color: 'rgba(255, 149, 0, 0.9)', font: { size: 11 } },
            ticks: { font: { size: 10 }, color: 'rgba(255, 149, 0, 0.7)' },
            beginAtZero: true,
            grid: { drawOnChartArea: false }
          }
        },
        plugins: {
          legend: {
            position: 'top',
            labels: { font: { size: 11 }, usePointStyle: true, boxWidth: 8 }
          },
          annotation: { annotations },
          decimation: {
            enabled: true,
            algorithm: 'lttb',
            samples: 800
          }
        }
      }
    });
  }

  render() {
    this.shadowRoot.innerHTML = `
      <style>
        :host {
          display: block;
          padding: 0 16px 16px;
        }
        .back-bar {
          display: flex;
          align-items: center;
          padding: 10px 0;
        }
        .back-btn {
          background: none;
          border: none;
          color: #007aff;
          font-size: 15px;
          font-weight: 500;
          cursor: pointer;
          padding: 4px 0;
          font-family: inherit;
        }
        .back-btn::before {
          content: '\\2039';
          font-size: 22px;
          margin-right: 4px;
          vertical-align: middle;
          line-height: 1;
        }
        #header-card {
          display: none;
          background: #fff;
          border-radius: 12px;
          padding: 16px;
          margin-bottom: 12px;
        }
        .rec-name {
          margin: 0 0 8px;
          font-size: 18px;
          font-weight: 600;
        }
        .tags {
          display: flex;
          gap: 6px;
          margin-bottom: 12px;
        }
        .tag {
          font-size: 11px;
          padding: 2px 8px;
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
        .meta-grid {
          display: grid;
          grid-template-columns: repeat(3, 1fr);
          gap: 8px;
          margin-bottom: 12px;
        }
        .meta-item {
          display: flex;
          flex-direction: column;
          align-items: center;
        }
        .meta-label {
          font-size: 11px;
          color: #8e8e93;
          margin-bottom: 2px;
        }
        .meta-value {
          font-size: 16px;
          font-weight: 600;
        }
        .threshold-row {
          display: flex;
          gap: 8px;
          align-items: center;
          flex-wrap: wrap;
          font-size: 12px;
          color: #666;
          border-top: 1px solid #f0f0f0;
          padding-top: 10px;
        }
        .threshold-label {
          color: #8e8e93;
        }
        .threshold-value {
          font-weight: 600;
          color: #1a1a1a;
          margin-right: 8px;
        }
        #chart-wrap {
          display: none;
          background: #fff;
          border-radius: 12px;
          padding: 12px;
          overflow-x: auto;
          -webkit-overflow-scrolling: touch;
        }
        .chart-container {
          position: relative;
          height: 280px;
          min-width: 100%;
        }
        #loading {
          display: none;
          text-align: center;
          padding: 60px 20px;
          color: #8e8e93;
          font-size: 15px;
        }
        #error {
          display: none;
          text-align: center;
          padding: 40px 20px;
          color: #ff3b30;
          font-size: 15px;
        }
      </style>

      <div class="back-bar">
        <button class="back-btn" id="back-btn">Recordings</button>
      </div>
      <div id="loading">Loading recording data...</div>
      <div id="error"></div>
      <div id="header-card"></div>
      <div id="chart-wrap">
        <div class="chart-container">
          <canvas id="chart"></canvas>
        </div>
      </div>
    `;

    this.shadowRoot.querySelector('#back-btn').addEventListener('click', () => {
      window.location.hash = '#/recordings';
    });
  }
}

customElements.define('recording-detail-page', RecordingDetailPage);
