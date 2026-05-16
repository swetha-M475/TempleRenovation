/**
 * Results Rendering Module
 *
 * Exports:
 *   renderAnalysisResults(data, canvasId)
 *   renderComparisonResults(data)
 *   showToast(message, type)
 */

(function () {
    'use strict';

    // ─── Toast Notifications ───────────────────────────────
    function showToast(message, type) {
        type = type || 'success';
        const container = document.getElementById('toast-container');
        if (!container) return;

        const toast = document.createElement('div');
        toast.className = 'toast toast-' + type;
        toast.textContent = message;
        container.appendChild(toast);

        // Auto-remove after 4 seconds
        setTimeout(() => {
            toast.classList.add('toast-out');
            setTimeout(() => {
                if (toast.parentNode) toast.parentNode.removeChild(toast);
            }, 300);
        }, 4000);
    }

    // ─── Render Analysis Results ───────────────────────────
    function renderAnalysisResults(data, canvasId) {
        const detections = data.detections || {};
        const qualityData = data.quality || {};
        const orientData = data.orientation || {};

        // Show results container
        const resultsEl = document.getElementById('analyzeResults');
        if (resultsEl) resultsEl.style.display = '';

        // 1. Draw annotated image on canvas
        _drawAnnotatedImage(detections.annotated_image_base64, canvasId);

        // 2. Render detections list
        _renderDetectionsList(detections.detections || [], 'detectionsList');

        // 3. Render quality section
        _renderQualityGrid(qualityData, orientData);

        // 4. Render domain interpretation
        const interpEl = document.getElementById('interpText');
        if (interpEl) {
            interpEl.textContent = detections.domain_interpretation || 'No interpretation available.';
        }
    }

    function _drawAnnotatedImage(base64, canvasId) {
        const canvas = document.getElementById(canvasId);
        if (!canvas || !base64) return;
        const ctx = canvas.getContext('2d');
        const img = new Image();
        img.onload = function () {
            canvas.width = img.width;
            canvas.height = img.height;
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        };
        img.src = 'data:image/jpeg;base64,' + base64;
    }

    function _renderDetectionsList(detections, containerId) {
        const el = document.getElementById(containerId);
        if (!el) return;

        if (detections.length === 0) {
            el.innerHTML = '<div class="no-detections">No temple-related objects detected</div>';
            return;
        }

        el.innerHTML = detections.map(det => {
            const conf = det.confidence || 0;
            const pct = Math.round(conf * 100);
            const confClass = pct >= 75 ? 'conf-high' : pct >= 50 ? 'conf-med' : 'conf-low';
            const badgeClass = _getBadgeClass(det.class_name);
            const emoji = _getEmoji(det.class_name);
            const inferred = det.inferred ? ' inferred' : '';
            const inferredTag = det.inferred ? '<span class="inferred-tag">INFERRED</span>' : '';

            return `
                <div class="detection-item${inferred}">
                    <span class="det-badge ${badgeClass}">${emoji} ${det.class_name}</span>
                    <div class="det-info">
                        <div class="det-meta">
                            ${det.inferred ? 'Spatially inferred from Lingam' : 'Confidence: ' + det.confidence_pct}
                            ${inferredTag}
                        </div>
                    </div>
                    <div class="conf-wrap ${confClass}">
                        <div class="conf-value">${pct}%</div>
                        <div class="conf-bar"><div class="conf-bar-fill" style="width:${pct}%"></div></div>
                    </div>
                </div>
            `;
        }).join('');
    }

    function _renderQualityGrid(quality, orient) {
        const grid = document.getElementById('qualityGrid');
        if (!grid) return;

        const cards = [
            {
                label: 'Blur Level',
                value: quality.blur_level || 'N/A',
                detail: 'Score: ' + (quality.blur_score ?? 'N/A'),
                color: quality.blur_level === 'low' ? 'q-success' : quality.blur_level === 'medium' ? 'q-warning' : 'q-danger',
            },
            {
                label: 'Brightness',
                value: quality.brightness_level || 'N/A',
                detail: 'Mean: ' + (quality.brightness ?? 'N/A'),
                color: quality.brightness_level === 'normal' ? 'q-success' : 'q-warning',
            },
            {
                label: 'Noise',
                value: Math.round(quality.noise_score || 0),
                detail: 'Laplacian std',
                color: (quality.noise_score || 0) < 20 ? 'q-success' : 'q-warning',
            },
            {
                label: 'Reliability',
                value: quality.reliability || 'N/A',
                detail: 'Multiplier: ' + (quality.confidence_multiplier ?? 'N/A'),
                color: quality.reliability === 'high' ? 'q-success' : quality.reliability === 'medium' ? 'q-warning' : 'q-danger',
            },
            {
                label: 'Orientation',
                value: orient.orientation || 'N/A',
                detail: (orient.width || '?') + ' × ' + (orient.height || '?'),
                color: 'q-success',
            },
        ];

        grid.innerHTML = cards.map(c => `
            <div class="quality-card">
                <div class="q-label">${c.label}</div>
                <div class="q-value ${c.color}">${c.value}</div>
                <div class="q-detail">${c.detail}</div>
            </div>
        `).join('');
    }

    // ─── Render Comparison Results ─────────────────────────
    function renderComparisonResults(data) {
        const resultsEl = document.getElementById('compareResults');
        if (resultsEl) resultsEl.style.display = '';

        const sim = data.similarity || {};
        const changes = data.changes || {};
        const dup = data.duplicate_check || {};
        const det1 = data.image1_detections || {};
        const det2 = data.image2_detections || {};

        // 1. Side-by-side annotated images
        const img1El = document.getElementById('compareImg1');
        const img2El = document.getElementById('compareImg2');
        if (img1El && det1.annotated_image_base64) {
            img1El.src = 'data:image/jpeg;base64,' + det1.annotated_image_base64;
        }
        if (img2El && det2.annotated_image_base64) {
            img2El.src = 'data:image/jpeg;base64,' + det2.annotated_image_base64;
        }

        // Detection lists
        _renderDetectionsList(det1.detections || [], 'compareDetList1');
        _renderDetectionsList(det2.detections || [], 'compareDetList2');

        // 2. SSIM circular progress
        const score = sim.ssim_score || 0;
        const circumference = 2 * Math.PI * 50; // r=50
        const offset = circumference * (1 - score);
        const scoreColor = score > 0.85 ? 'var(--success)' : score > 0.6 ? 'var(--warning)' : 'var(--danger)';

        const fillEl = document.getElementById('ssimFill');
        const numEl = document.getElementById('ssimScoreNum');
        const labelEl = document.getElementById('ssimLabel');
        const interpEl = document.getElementById('ssimInterpretation');
        const metaEl = document.getElementById('ssimMeta');

        if (fillEl) {
            fillEl.setAttribute('stroke', scoreColor);
            // Animate after a short delay
            setTimeout(() => {
                fillEl.style.strokeDashoffset = offset;
            }, 100);
        }
        if (numEl) {
            numEl.style.color = scoreColor;
            numEl.textContent = (score * 100).toFixed(1);
        }
        if (labelEl) labelEl.textContent = sim.similarity_label || '';
        if (interpEl) interpEl.textContent = sim.interpretation || '';
        if (metaEl) {
            metaEl.innerHTML =
                'Structural changes: <strong>' + (sim.structural_change_regions || 0) + '</strong> · ' +
                'Illumination changes: <strong>' + (sim.illumination_change_regions || 0) + '</strong>';
        }

        // 3. Diff toggle button
        const diffToggle = document.getElementById('diffToggle');
        const diffOverlay = document.getElementById('diffOverlay');
        if (sim.diff_image_base64) {
            diffOverlay.src = 'data:image/jpeg;base64,' + sim.diff_image_base64;
            diffToggle.style.display = '';

            // Remove old listeners
            const newToggle = diffToggle.cloneNode(true);
            diffToggle.parentNode.replaceChild(newToggle, diffToggle);

            let showingDiff = false;
            newToggle.addEventListener('click', () => {
                showingDiff = !showingDiff;
                diffOverlay.style.display = showingDiff ? '' : 'none';
                newToggle.classList.toggle('active', showingDiff);
                newToggle.innerHTML = showingDiff
                    ? '<span>🔬</span> Hide Differences'
                    : '<span>🔬</span> Show Differences';
            });
        }

        // 4. Change summary
        _renderChangeSummary(changes);

        // 5. Anomalies
        _renderAnomalies(changes.anomalies || []);

        // 6. Duplicate check
        const dupCard = document.getElementById('dupCard');
        const dupInfo = document.getElementById('dupInfo');
        if (dupCard && dupInfo) {
            dupCard.style.display = '';
            const dupText = dup.is_duplicate
                ? '✅ These images appear to be duplicates (pHash distance: ' + dup.phash_distance + ').'
                : '❌ These images are not duplicates (pHash distance: ' + dup.phash_distance + ').';
            dupInfo.textContent = dupText;
        }
    }

    function _renderChangeSummary(changes) {
        const grid = document.getElementById('changeSummaryGrid');
        const details = document.getElementById('changeDetails');
        if (!grid || !details) return;

        const newCount = (changes.new_objects || []).length;
        const removedCount = (changes.removed_objects || []).length;
        const shiftedCount = (changes.shifted_objects || []).length;
        const stableCount = (changes.stable_objects || []).length;

        grid.innerHTML = `
            <div class="change-stat">
                <div class="stat-num stat-new">+${newCount}</div>
                <div class="stat-label">New</div>
            </div>
            <div class="change-stat">
                <div class="stat-num stat-removed">-${removedCount}</div>
                <div class="stat-label">Removed</div>
            </div>
            <div class="change-stat">
                <div class="stat-num stat-shifted">~${shiftedCount}</div>
                <div class="stat-label">Shifted</div>
            </div>
            <div class="change-stat">
                <div class="stat-num stat-stable">=${stableCount}</div>
                <div class="stat-label">Stable</div>
            </div>
        `;

        // Change level badge
        let levelClass = 'level-minor';
        if (changes.change_level === 'moderate') levelClass = 'level-moderate';
        if (changes.change_level === 'major') levelClass = 'level-major';

        let html = `
            <div style="margin-bottom:16px;">
                <span class="change-level-badge ${levelClass}">${changes.change_level || 'minor'}</span>
                <span style="color:var(--text-secondary); font-size:0.85rem; margin-left:10px;">${changes.change_summary || ''}</span>
            </div>
        `;

        // Individual entries
        const entries = [];
        (changes.new_objects || []).forEach(cls => {
            entries.push({ type: 'new', label: cls, icon: '+' });
        });
        (changes.removed_objects || []).forEach(cls => {
            entries.push({ type: 'removed', label: cls, icon: '-' });
        });
        (changes.shifted_objects || []).forEach(obj => {
            entries.push({ type: 'shifted', label: obj.class + ' (IoU: ' + obj.iou + ')', icon: '~' });
        });
        (changes.stable_objects || []).forEach(cls => {
            entries.push({ type: 'stable', label: cls, icon: '=' });
        });

        if (entries.length > 0) {
            html += entries.map(e => `
                <div class="change-entry entry-${e.type}">
                    <span class="change-tag tag-${e.type}">${e.icon} ${e.type}</span>
                    <span style="flex:1; font-size:0.85rem;">${e.label}</span>
                </div>
            `).join('');
        }

        details.innerHTML = html;
    }

    function _renderAnomalies(anomalies) {
        const section = document.getElementById('anomaliesSection');
        if (!section) return;

        if (anomalies.length === 0) {
            section.innerHTML = '';
            return;
        }

        section.innerHTML = anomalies.map(a => {
            const isCritical = a.severity === 'critical';
            const cardClass = isCritical ? '' : ' anomaly-warning';
            const icon = isCritical ? '🚨' : '⚠️';
            return `
                <div class="anomaly-card${cardClass}">
                    <h4>${icon} ${a.type}</h4>
                    <p>${a.description}</p>
                </div>
            `;
        }).join('');
    }

    // ─── Helpers ──────────────────────────────────────────
    function _getBadgeClass(className) {
        if (!className) return 'temple';
        const lower = className.toLowerCase();
        if (lower.includes('lingam')) return 'lingam';
        if (lower.includes('nandhi')) return 'nandhi';
        if (lower.includes('temple')) return 'temple';
        if (lower.includes('shed')) return 'shed';
        if (lower.includes('avudaiyar')) return 'avudaiyar';
        return 'temple';
    }

    function _getEmoji(className) {
        if (!className) return '📦';
        const lower = className.toLowerCase();
        if (lower.includes('lingam')) return '🕉️';
        if (lower.includes('nandhi')) return '🐂';
        if (lower.includes('temple')) return '🛕';
        if (lower.includes('shed')) return '🏚️';
        if (lower.includes('avudaiyar')) return '⬡';
        return '📦';
    }

    // Export
    window.renderAnalysisResults = renderAnalysisResults;
    window.renderComparisonResults = renderComparisonResults;
    window.showToast = showToast;
})();
