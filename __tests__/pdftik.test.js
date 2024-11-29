// __tests__/pdftik.test.js
const PDFTik = require('../index');
const fs = require('fs').promises;
const path = require('path');

describe('PDFTik', () => {
    let pdftik;
    const tempDir = path.join(__dirname, '../temp');

    beforeEach(async () => {
        pdftik = new PDFTik({
            pageSize: 'A4',
            margins: { top: 10, right: 10, bottom: 10, left: 10 },
            enableImages: true,
            maxFileSize: 1024 * 1024 // 1MB for testing
        });
        await pdftik.ensureTempDir();
    });

    afterEach(async () => {
        if (pdftik) {
            await pdftik.destroy();
        }
    });

    describe('Initialization', () => {
        test('should create instance with default options', () => {
            const instance = new PDFTik();
            expect(instance).toBeDefined();
        });

        test('should create instance with custom options', () => {
            const instance = new PDFTik({
                pageSize: 'Letter',
                margins: { top: 20, right: 20, bottom: 20, left: 20 }
            });
            expect(instance).toBeDefined();
        });

        test('should throw on invalid options', () => {
            expect(() => new PDFTik({ pageSize: 123 })).toThrow('pageSize must be a string');
            expect(() => new PDFTik({ margins: { top: 'invalid' } })).toThrow('Invalid margins configuration');
        });
    });

    describe('HTML to PDF Conversion', () => {
        test('should convert simple HTML to PDF', async () => {
            const html = '<h1>Hello World</h1>';
            const pdf = await pdftik.convertHTML(html);
            expect(Buffer.isBuffer(pdf)).toBe(true);
        });

        test('should handle complex HTML with CSS', async () => {
            const html = `
                <style>
                    .container { color: blue; padding: 20px; }
                </style>
                <div class="container">
                    <h1>Test</h1>
                </div>
            `;
            const pdf = await pdftik.convertHTML(html);
            expect(Buffer.isBuffer(pdf)).toBe(true);
        });

        test('should reject oversized content', async () => {
            const hugeHtml = 'x'.repeat(2 * 1024 * 1024); // 2MB
            await expect(pdftik.convertHTML(hugeHtml)).rejects.toThrow('exceeds maximum file size');
        });
    });

    describe('Batch Processing', () => {
        test('should convert multiple HTML documents', async () => {
            const items = [
                { content: '<h1>Doc 1</h1>' },
                { content: '<h1>Doc 2</h1>' }
            ];
            const pdfs = await pdftik.convertBatch(items);
            expect(Array.isArray(pdfs)).toBe(true);
            expect(pdfs.length).toBe(2);
        });

        test('should handle errors in batch', async () => {
            const items = [
                { content: '<h1>Valid</h1>' },
                { content: null },
                { content: '<h1>Also Valid</h1>' }
            ];
            await expect(pdftik.convertBatch(items)).rejects.toThrow();
        });
    });

    describe('File System Handling', () => {
        test('should handle temp directory creation', async () => {
            await fs.rm(tempDir, { recursive: true, force: true });
            await pdftik.ensureTempDir();
            const exists = await fs.access(tempDir).then(() => true).catch(() => false);
            expect(exists).toBe(true);
        });

        test('should cleanup temp files', async () => {
            await pdftik.convertHTML('<h1>Test</h1>');
            const files = await fs.readdir(tempDir);
            expect(files.length).toBe(0);
        });
    });
});