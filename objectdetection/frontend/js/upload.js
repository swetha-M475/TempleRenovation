/**
 * Upload Module — Drag-and-drop file handling with preview
 *
 * Exports:
 *   initSingleUpload(zoneId, previewId, callback)
 *   initDualUpload(zone1Id, prev1Id, cb1, zone2Id, prev2Id, cb2)
 */

(function () {
    'use strict';

    /**
     * DropZone class — handles a single drop zone element
     */
    class DropZone {
        constructor(elementId, onFileSelected) {
            this.zone = document.getElementById(elementId);
            if (!this.zone) return;
            this.callback = onFileSelected;
            this.file = null;

            // Find child elements
            this.content = this.zone.querySelector('.drop-zone-content');
            this.preview = this.zone.querySelector('.drop-preview');
            this.previewImg = this.zone.querySelector('.drop-preview img');
            this.removeBtn = this.zone.querySelector('.remove-btn');
            this.fileInput = this.zone.querySelector('input[type="file"]');

            this._bindEvents();
        }

        _bindEvents() {
            if (!this.zone) return;

            // Click to open file picker
            this.zone.addEventListener('click', (e) => {
                if (e.target === this.removeBtn || e.target.closest('.remove-btn')) return;
                this.fileInput.click();
            });

            // File input change
            this.fileInput.addEventListener('change', (e) => {
                if (e.target.files.length > 0) {
                    this._handleFile(e.target.files[0]);
                }
            });

            // Drag events
            this.zone.addEventListener('dragover', (e) => {
                e.preventDefault();
                this.zone.classList.add('drag-active');
            });

            this.zone.addEventListener('dragleave', () => {
                this.zone.classList.remove('drag-active');
            });

            this.zone.addEventListener('drop', (e) => {
                e.preventDefault();
                this.zone.classList.remove('drag-active');
                const files = e.dataTransfer.files;
                if (files.length > 0) {
                    this._handleFile(files[0]);
                }
            });

            // Remove button
            if (this.removeBtn) {
                this.removeBtn.addEventListener('click', (e) => {
                    e.stopPropagation();
                    this.clear();
                    if (this.callback) this.callback(null);
                });
            }
        }

        _handleFile(file) {
            // Validate file type
            const validTypes = ['image/jpeg', 'image/png', 'image/webp'];
            if (!validTypes.includes(file.type)) {
                window.showToast('Only JPG, PNG, and WebP images are supported.', 'error');
                return;
            }

            // Validate file size (max 20 MB)
            if (file.size > 20 * 1024 * 1024) {
                window.showToast('Image is too large. Maximum size is 20 MB.', 'error');
                return;
            }

            this.file = file;

            // Show preview
            const reader = new FileReader();
            reader.onload = (e) => {
                this.previewImg.src = e.target.result;
                this.preview.style.display = 'block';
                this.content.style.display = 'none';
                this.zone.classList.add('has-image');
            };
            reader.readAsDataURL(file);

            if (this.callback) this.callback(file);
        }

        clear() {
            this.file = null;
            if (this.previewImg) this.previewImg.src = '';
            if (this.preview) this.preview.style.display = 'none';
            if (this.content) this.content.style.display = '';
            if (this.zone) this.zone.classList.remove('has-image');
            if (this.fileInput) this.fileInput.value = '';
        }

        getFile() {
            return this.file;
        }
    }

    /**
     * Initialize a single upload zone
     */
    function initSingleUpload(zoneId, previewId, callback) {
        return new DropZone(zoneId, callback);
    }

    /**
     * Initialize dual upload zones (for comparison)
     */
    function initDualUpload(zone1Id, prev1Id, cb1, zone2Id, prev2Id, cb2) {
        const dz1 = new DropZone(zone1Id, cb1);
        const dz2 = new DropZone(zone2Id, cb2);
        return { zone1: dz1, zone2: dz2 };
    }

    // Export
    window.DropZone = DropZone;
    window.initSingleUpload = initSingleUpload;
    window.initDualUpload = initDualUpload;
})();
