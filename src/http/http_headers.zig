const std = @import("std");
const constants = @import("constants.zig");

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

    pub fn parse(buffer: []u8, alloc: std.mem.Allocator) !HttpHeaders {
        var headers = HttpHeaders{ .headers = &.{} };

        const headers_end = std.mem.indexOf(u8, buffer, constants.EOL ++ constants.EOL) orelse return headers;
        const header_section = buffer[0..headers_end];

        const headers_start_index = std.mem.indexOf(u8, header_section, constants.EOL) orelse return headers;
        const all_headers = header_section[headers_start_index + constants.EOL.len ..];

        var headers_split = std.mem.splitSequence(u8, all_headers, constants.EOL);

        while (headers_split.next()) |header_line| {
            if (header_line.len == 0) continue;

            var header_parts = std.mem.splitSequence(u8, header_line, ":");

            const key = header_parts.next() orelse continue;
            var value_slice = header_parts.next() orelse continue;

            while (value_slice.len > 0 and value_slice[0] == ' ') {
                value_slice = value_slice[1..];
            }

            try headers.add(alloc, key, value_slice);
        }

        return headers;
    }

    pub fn stringfy(self: *const HttpHeaders, buffer: []u8) ![]u8 {
        var fbs = std.io.fixedBufferStream(buffer);
        var writer = fbs.writer();

        for (self.headers) |header| {
            if (header.key.len > 0 and header.value.len > 0) {
                try writer.print("{s}: {s}\r\n", .{ header.key, header.value });
            }
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
