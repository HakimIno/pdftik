// src/document.zig
const std = @import("std");
const c = @cImport({
    @cInclude("wkhtmltox/pdf.h");
});
const pool = @import("pool.zig");

pub const PdfDocument = struct {
    converter: *c.wkhtmltopdf_converter,
    settings: *c.wkhtmltopdf_global_settings,
    allocator: std.mem.Allocator,
    memory_pool: *pool.MemoryPool,

    pub fn init(allocator: std.mem.Allocator, memory_pool: *pool.MemoryPool) !*PdfDocument {
        if (c.wkhtmltopdf_init(0) == 0) return error.InitializationFailed;

        const doc = try allocator.create(PdfDocument);
        doc.* = .{
            .allocator = allocator,
            .memory_pool = memory_pool,
            .settings = c.wkhtmltopdf_create_global_settings() orelse return error.SettingsCreationFailed,
            .converter = undefined,
        };

        doc.converter = c.wkhtmltopdf_create_converter(doc.settings) orelse {
            c.wkhtmltopdf_destroy_global_settings(doc.settings);
            allocator.destroy(doc);
            return error.ConverterCreationFailed;
        };

        return doc;
    }

    pub fn deinit(self: *PdfDocument) void {
        c.wkhtmltopdf_destroy_converter(self.converter);
        c.wkhtmltopdf_destroy_global_settings(self.settings);
        _ = c.wkhtmltopdf_deinit();
        self.allocator.destroy(self);
    }

    pub fn addPage(self: *PdfDocument, html: []const u8) !void {
        const object_settings = c.wkhtmltopdf_create_object_settings() orelse return error.ObjectSettingsCreationFailed;
        defer c.wkhtmltopdf_destroy_object_settings(object_settings);

        const temp_path = try self.writeTempHTML(html);
        defer self.allocator.free(temp_path);

        _ = c.wkhtmltopdf_set_object_setting(object_settings, "page", temp_path.ptr);
        _ = c.wkhtmltopdf_add_object(self.converter, object_settings, null);
    }

    pub fn toBuffer(self: *PdfDocument) ![]u8 {
        if (c.wkhtmltopdf_convert(self.converter) == 0) return error.ConversionFailed;

        var output_len: c_ulong = undefined;
        const output_ptr = c.wkhtmltopdf_get_output(self.converter, &output_len);
        if (output_ptr == null) return error.OutputFailed;

        const buffer = try self.allocator.alloc(u8, output_len);
        @memcpy(buffer, output_ptr[0..output_len]);
        return buffer;
    }

    fn writeTempHTML(self: *PdfDocument, html: []const u8) ![]u8 {
        const temp_dir = try std.fs.selfExeDirPath(self.allocator);
        const temp_path = try std.fmt.allocPrint(self.allocator, "{s}/temp_{d}.html", .{ temp_dir, std.time.milliTimestamp() });

        const file = try std.fs.createFileAbsolute(temp_path, .{});
        defer file.close();
        try file.writeAll(html);

        return temp_path;
    }
};
