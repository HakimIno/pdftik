// src/converter.zig
const std = @import("std");
const Document = @import("document.zig").PdfDocument;
const Pool = @import("pool.zig").MemoryPool;
const Excel = @import("excel.zig").ExcelConverter;

pub const Converter = struct {
    allocator: std.mem.Allocator,
    memory_pool: *Pool,
    settings: Settings,

    pub const Settings = struct {
        page_size: []const u8 = "A4",
        margins: Margins = .{},
        encoding: []const u8 = "UTF-8",
        enable_images: bool = true,
    };

    pub const Margins = struct {
        top: u32 = 10,
        right: u32 = 10,
        bottom: u32 = 10,
        left: u32 = 10,
    };

    pub fn init(allocator: std.mem.Allocator, settings: Settings) !*Converter {
        const pool = try Pool.init(allocator, 1024 * 1024 * 10);
        const self = try allocator.create(Converter);
        self.* = .{
            .allocator = allocator,
            .memory_pool = pool,
            .settings = settings,
        };
        return self;
    }

    pub fn deinit(self: *Converter) void {
        self.memory_pool.deinit();
        self.allocator.destroy(self);
    }

    pub fn convertToExcel(self: *Converter, pdfs: []const []const u8) ![]u8 {
        var excel = try Excel.init(self.allocator);
        defer excel.deinit();
        return excel.convert(pdfs);
    }

    pub fn convertBatch(self: *Converter, items: []const []const u8) ![]u8 {
        var doc = try Document.init(self.allocator, self.memory_pool);
        defer doc.deinit();

        const chunk_size = 50;
        var i: usize = 0;
        while (i < items.len) : (i += chunk_size) {
            const end = @min(i + chunk_size, items.len);
            try self.processChunk(doc, items[i..end]);
            self.memory_pool.reset();
        }

        return doc.toBuffer();
    }

    fn processChunk(self: *Converter, doc: *Document, items: []const []const u8) !void {
        for (items) |html| {
            try doc.addPage(html);
        }
    }
};
