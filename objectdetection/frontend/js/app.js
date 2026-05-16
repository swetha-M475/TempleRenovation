/**
 * Main Application Controller
 *
 * Orchestrates tab switching, uploads, API calls, and result rendering.
 * No external JS libraries — vanilla JS only.
 */

(function () {
    'use strict';

    const API_BASE = ''; // empty = same origin (Flask serves frontend)

    // ─── State ─────────────────────────────────────────────
    const state = {
        analyzeFile: null,
        compareFile1: null,
        compareFile2: null,
        analyzing: false,
        comparing: false,
    };

    // ─── DOM Elements ──────────────────────────────────────
    const navTabs = document.querySelectorAll('.nav-tab');
    const tabContents = document.querySelectorAll('.tab-content');
    const navIndicator = document.getElementById('navIndicator');

    const btnAnalyze = document.getElementById('btn-analyze');
    const btnCompare = document.getElementById('btn-compare');

    const analyzeResults = document.getElementById('analyzeResults');
    const compareResults = document.getElementById('compareResults');

    // ─── Tab Switching ─────────────────────────────────────
    function activateTab(tabName) {
        // Update tab buttons
        navTabs.forEach(tab => {
            tab.classList.toggle('active', tab.dataset.tab === tabName);
        });

        // Update tab content panels
        tabContents.forEach(panel => {
            const isActive = panel.id === 'tab-' + tabName;
            panel.classList.toggle('active', isActive);
        });

        // Animate nav indicator
        updateNavIndicator();
    }

    function updateNavIndicator() {
        const activeTab = document.querySelector('.nav-tab.active');
        if (!activeTab || !navIndicator) return;

        const tabsContainer = activeTab.parentElement;
        const containerRect = tabsContainer.getBoundingClientRect();
        const tabRect = activeTab.getBoundingClientRect();

        navIndicator.style.width = tabRect.width + 'px';
        navIndicator.style.left = (tabRect.left - containerRect.left) + 'px';
    }

    navTabs.forEach(tab => {
        tab.addEventListener('click', () => {
            activateTab(tab.dataset.tab);
        });
    });

    // Initialize indicator position
    setTimeout(updateNavIndicator, 50);
    window.addEventListener('resize', updateNavIndicator);

    // ─── Upload Setup ──────────────────────────────────────
    // Single analysis upload
    window.initSingleUpload('dropZone1', 'preview1', function (file) {
        state.analyzeFile = file;
        btnAnalyze.disabled = !file;
    });

    // Comparison uploads
    window.initDualUpload(
        'dropZone2', 'preview2', function (file) {
            state.compareFile1 = file;
            btnCompare.disabled = !(state.compareFile1 && state.compareFile2);
        },
        'dropZone3', 'preview3', function (file) {
            state.compareFile2 = file;
            btnCompare.disabled = !(state.compareFile1 && state.compareFile2);
        }
    );

    // ─── Analyze Flow ──────────────────────────────────────
    btnAnalyze.addEventListener('click', async () => {
        if (!state.analyzeFile) {
            window.showToast('Please upload an image first.', 'error');
            return;
        }
        if (state.analyzing) return;

        state.analyzing = true;
        _setLoading(btnAnalyze, true, 'Analyzing...');
        analyzeResults.style.display = 'none';

        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 30000);

        try {
            const formData = new FormData();
            formData.append('image', state.analyzeFile);

            const response = await fetch(API_BASE + '/api/analyze', {
                method: 'POST',
                body: formData,
                signal: controller.signal,
            });

            clearTimeout(timeout);
            const data = await response.json();

            if (!response.ok || data.status !== 'success') {
                throw new Error(data.error || 'Analysis failed');
            }

            window.renderAnalysisResults(data, 'canvas-analyze');
            window.showToast('Analysis complete!', 'success');
        } catch (err) {
            if (err.name === 'AbortError') {
                window.showToast('Request timed out after 30 seconds.', 'error');
            } else {
                window.showToast('Analysis failed: ' + err.message, 'error');
            }
            console.error('Analysis error:', err);
        } finally {
            state.analyzing = false;
            _setLoading(btnAnalyze, false);
        }
    });

    // ─── Compare Flow ──────────────────────────────────────
    btnCompare.addEventListener('click', async () => {
        if (!state.compareFile1 || !state.compareFile2) {
            window.showToast('Please upload both images.', 'error');
            return;
        }
        if (state.comparing) return;

        state.comparing = true;
        _setLoading(btnCompare, true, 'Comparing...');
        compareResults.style.display = 'none';

        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 30000);

        try {
            const formData = new FormData();
            formData.append('image1', state.compareFile1);
            formData.append('image2', state.compareFile2);

            const response = await fetch(API_BASE + '/api/compare', {
                method: 'POST',
                body: formData,
                signal: controller.signal,
            });

            clearTimeout(timeout);
            const data = await response.json();

            if (!response.ok || data.status !== 'success') {
                throw new Error(data.error || 'Comparison failed');
            }

            window.renderComparisonResults(data);
            window.showToast('Comparison complete!', 'success');
        } catch (err) {
            if (err.name === 'AbortError') {
                window.showToast('Request timed out after 30 seconds.', 'error');
            } else {
                window.showToast('Comparison failed: ' + err.message, 'error');
            }
            console.error('Comparison error:', err);
        } finally {
            state.comparing = false;
            _setLoading(btnCompare, false);
        }
    });

    // ─── Health Check on Page Load ─────────────────────────
    (async function healthCheck() {
        try {
            const controller = new AbortController();
            const timeout = setTimeout(() => controller.abort(), 5000);

            const resp = await fetch(API_BASE + '/api/health', {
                signal: controller.signal,
            });
            clearTimeout(timeout);

            const data = await resp.json();

            if (!data.model_loaded) {
                const banner = document.getElementById('warningBanner');
                if (banner) banner.style.display = '';
            }
        } catch (err) {
            console.warn('Health check failed:', err.message);
        }
    })();

    // ─── UI Helpers ────────────────────────────────────────
    function _setLoading(btn, loading, text) {
        const btnText = btn.querySelector('.btn-text');
        const btnLoader = btn.querySelector('.btn-loader');

        if (loading) {
            btn.disabled = true;
            if (btnText) btnText.style.display = 'none';
            if (btnLoader) {
                btnLoader.style.display = '';
                const span = btnLoader.querySelector('span:last-child') || btnLoader.lastChild;
                if (span && span.nodeType === Node.TEXT_NODE) {
                    span.textContent = text || 'Processing...';
                }
            }
        } else {
            btn.disabled = false;
            if (btnText) btnText.style.display = '';
            if (btnLoader) btnLoader.style.display = 'none';
        }
    }
})();
