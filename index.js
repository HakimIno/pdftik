// index.js
const fs = require('fs').promises;
const path = require('path');
const cheerio = require('cheerio');

class PDFTik {
    constructor(options = {}) {
        this.validateOptions(options);
        this.options = {
            pageSize: options.pageSize || 'A4',
            margins: this.validateMargins(options.margins || { top: 10, right: 10, bottom: 10, left: 10 }),
            enableImages: options.enableImages ?? true,
            encoding: options.encoding || 'UTF-8',
            maxFileSize: options.maxFileSize || 50 * 1024 * 1024 // 50MB
        };
        this.tempDir = path.join(__dirname, 'temp');
    }

    validateOptions(options) {
        if (options.pageSize && typeof options.pageSize !== 'string') {
            throw new Error('pageSize must be a string');
        }
        if (options.maxFileSize && typeof options.maxFileSize !== 'number') {
            throw new Error('maxFileSize must be a number');
        }
    }

    validateMargins(margins) {
        const validMargin = (value) => typeof value === 'number' && value >= 0;
        if (!margins || !validMargin(margins.top) || !validMargin(margins.right) || 
            !validMargin(margins.bottom) || !validMargin(margins.left)) {
            throw new Error('Invalid margins configuration');
        }
        return margins;
    }

    validateHTML(html) {
        if (!html || typeof html !== 'string') {
            throw new Error('Invalid HTML content');
        }
        if (html.length > this.options.maxFileSize) {
            throw new Error('HTML content exceeds maximum file size');
        }
        try {
            cheerio.load(html);
        } catch (err) {
            throw new Error('Invalid HTML structure');
        }
    }

    async ensureTempDir() {
        try {
            await fs.access(this.tempDir);
        } catch {
            await fs.mkdir(this.tempDir, { recursive: true });
        }
        // Verify write permissions
        const testFile = path.join(this.tempDir, 'test.tmp');
        try {
            await fs.writeFile(testFile, '');
            await fs.unlink(testFile);
        } catch (err) {
            throw new Error(`Temp directory is not writable: ${err.message}`);
        }
        return this.tempDir;
    }

    async convertHTML(html) {
        try {
            this.validateHTML(html);
            await this.ensureTempDir();

            const tempFile = path.join(this.tempDir, `temp_${Date.now()}.html`);
            await fs.writeFile(tempFile, html, { encoding: this.options.encoding });

            try {
                const pdfBuffer = await this._generatePDF(tempFile);
                return pdfBuffer;
            } finally {
                await this.safeUnlink(tempFile);
            }
        } catch (err) {
            throw new Error(`PDF generation failed: ${err.message}`);
        }
    }

    async convertBatch(items) {
        if (!Array.isArray(items)) {
            throw new Error('Items must be an array');
        }

        await this.ensureTempDir();
        const results = [];
        const CHUNK_SIZE = 50;
        const tempFiles = [];

        try {
            for (let i = 0; i < items.length; i += CHUNK_SIZE) {
                const chunk = items.slice(i, i + CHUNK_SIZE);
                const chunkPromises = chunk.map(async (item, index) => {
                    this.validateHTML(item.content);
                    const tempFile = path.join(this.tempDir, `temp_${Date.now()}_${i + index}.html`);
                    tempFiles.push(tempFile);
                    await fs.writeFile(tempFile, item.content, { encoding: this.options.encoding });
                    const pdf = await this._generatePDF(tempFile);
                    return pdf;
                });

                const chunkResults = await Promise.all(chunkPromises);
                results.push(...chunkResults);
            }
            return results;
        } catch (err) {
            throw new Error(`Batch conversion failed: ${err.message}`);
        } finally {
            // Cleanup temp files
            await Promise.all(tempFiles.map(file => this.safeUnlink(file)));
        }
    }

    async toExcel(pdfs) {
        if (!Array.isArray(pdfs) || !pdfs.every(pdf => Buffer.isBuffer(pdf))) {
            throw new Error('PDFs must be an array of buffers');
        }

        try {
            await this.ensureTempDir();
            const tempFiles = [];

            try {
                for (const [index, pdf] of pdfs.entries()) {
                    const tempFile = path.join(this.tempDir, `temp_${Date.now()}_${index}.pdf`);
                    tempFiles.push(tempFile);
                    await fs.writeFile(tempFile, pdf);
                }

                return await this._generateExcel(tempFiles);
            } finally {
                await Promise.all(tempFiles.map(file => this.safeUnlink(file)));
            }
        } catch (err) {
            throw new Error(`Excel conversion failed: ${err.message}`);
        }
    }

    async _generatePDF(htmlFile) {
        // Mock implementation - replace with actual Zig native module integration
        const content = await fs.readFile(htmlFile, 'utf8');
        return Buffer.from(content);
    }

    async _generateExcel(pdfFiles) {
        // Mock implementation - replace with actual Zig native module integration
        return Buffer.from('Excel content');
    }

    async safeUnlink(file) {
        try {
            await fs.unlink(file);
        } catch (err) {
            console.error(`Failed to delete temp file ${file}:`, err);
        }
    }

    async destroy() {
        try {
            await fs.rm(this.tempDir, { recursive: true, force: true });
        } catch (err) {
            console.error('Cleanup failed:', err);
        }
    }
}

module.exports = PDFTik;