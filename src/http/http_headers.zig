const std = @import("std");

pub const HttpHeader = struct {
    key: []const u8,
    value: []const u8,
};

pub const HttpHeaders = struct {
    headers: []HttpHeader,

    pub fn add(self: *HttpHeaders, alloc: std.mem.Allocator, key: []const u8, value: []const u8) !void {
        const header = HttpHeader{
            .key = try alloc.dupe(u8, key),
            .value = try alloc.dupe(u8, value),
        };

        const new_headers = try alloc.realloc(self.headers, self.headers.len + 1);

        new_headers[self.headers.len] = header;

        self.headers = new_headers;
    }

    pub fn get(self: *const HttpHeaders, key: []const u8) ?[]const u8 {
        for (self.headers) |header| {
            if (std.mem.eql(u8, header.key, key)) {
                return header.value;
            }
        }

        return null;
    }

    // pub fn parse(buffer: []u8) HttpHeaders {}

    pub fn stringfy(self: *const HttpHeaders, buffer: []u8) ![]u8 {
        var fbs = std.io.fixedBufferStream(buffer);
        var writer = fbs.writer();

        for (self.headers) |header| {
            try writer.print("{s}: {s}\r\n", .{ header.key, header.value });
        }

        return fbs.getWritten();
    }

    pub fn deinit(self: *HttpHeaders, alloc: std.mem.Allocator) void {
        for (self.headers) |header| {
            alloc.free(header.key);
            alloc.free(header.value);
        }
        alloc.free(self.headers);
        self.headers = &.{};
    }
};
