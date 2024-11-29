// main.zig
const std = @import("std");
const c = @cImport({
    @cInclude("wkhtmltox/pdf.h");
});
const types = @import("types.zig");

pub const PDFTik = struct {
    allocator: std.mem.Allocator,
    settings: *c.wkhtmltopdf_global_settings,
    converter: *c.wkhtmltopdf_converter,

    pub fn init(allocator: std.mem.Allocator) !*PDFTik {
        if (c.wkhtmltopdf_init(0) == 0) {
            return error.InitializationFailed;
        }

        const self = try allocator.create(PDFTik);
        self.allocator = allocator;
        self.settings = c.wkhtmltopdf_create_global_settings() orelse return error.SettingsCreationFailed;
        self.converter = c.wkhtmltopdf_create_converter(self.settings) orelse return error.ConverterCreationFailed;

        return self;
    }

    pub fn deinit(self: *PDFTik) void {
        c.wkhtmltopdf_destroy_converter(self.converter);
        c.wkhtmltopdf_destroy_global_settings(self.settings);
        _ = c.wkhtmltopdf_deinit(); // เพิ่ม _ = เพื่อเพิกเฉยค่า return
        self.allocator.destroy(self);
    }

    pub fn generatePDF(self: *PDFTik, items: []const types.Record) ![]u8 {
        const object_settings = c.wkhtmltopdf_create_object_settings() orelse return error.ObjectSettingsCreationFailed;
        defer c.wkhtmltopdf_destroy_object_settings(object_settings);

        var buffer = std.ArrayList(u8).init(self.allocator);
        errdefer buffer.deinit();

        for (items) |record| {
            const html = try record.toHTML();
            defer self.allocator.free(html);
            try self.renderHTML(object_settings, html);
        }

        return buffer.toOwnedSlice();
    }

    fn renderHTML(self: *PDFTik, settings: *c.wkhtmltopdf_object_settings, html: []const u8) !void {
        _ = c.wkhtmltopdf_set_object_setting(settings, "web.defaultEncoding", "utf-8");
        _ = c.wkhtmltopdf_set_object_setting(settings, "web.loadImages", "true");
        _ = c.wkhtmltopdf_set_object_setting(settings, "web.enableJavascript", "false");

        const temp_path = try self.writeTempHTML(html);
        defer std.fs.deleteFileAbsolute(temp_path) catch {};

        _ = c.wkhtmltopdf_set_object_setting(settings, "page", temp_path.ptr);
        _ = c.wkhtmltopdf_convert(self.converter);
    }

    fn writeTempHTML(self: *PDFTik, html: []const u8) ![]u8 {
        var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const temp_dir = try std.fs.selfExeDirPath(&buffer); // แก้ไขการใช้ selfExeDirPath

        const temp_path = try std.fmt.allocPrint(self.allocator, "{s}/temp_{d}.html", .{ temp_dir, std.time.milliTimestamp() });

        const file = try std.fs.createFileAbsolute(temp_path, .{});
        defer file.close();

        try file.writeAll(html);
        return temp_path;
    }
};
