const std = @import("std");
const HttpHeaders = @import("http_headers.zig").HttpHeaders;
const constants = @import("constants.zig");

pub const HttpResponseStatusCode = enum(u16) {
    OK = 200,
    Created = 201,
    BadRequest = 400,
    NotFound = 404,
};

pub const HttpResponse = struct {
    version: []const u8 = "HTTP/1.1",
    status: HttpResponseStatusCode,
    headers: HttpHeaders,
    body: []const u8 = "",

    pub fn done(self: *const HttpResponse, buffer: []u8) ![]u8 {
        const status_parsed = parse_status(self.status);

        var headers_buffer: [1024]u8 = undefined;

        const headers_parse = try self.headers.stringfy(&headers_buffer);

        return std.fmt.bufPrint(
            buffer,
            "{s} {s}\r\n{s}\r\n{s}" ++ constants.EOL ++ constants.EOL,
            .{ self.version, status_parsed, headers_parse, self.body },
        );
    }

    fn parse_status(status_enum: HttpResponseStatusCode) []const u8 {
        const status_map = std.static_string_map.StaticStringMap([]const u8).initComptime(.{
            .{ @tagName(.OK), "200 OK" },
            .{ @tagName(.Created), "201 Created" },
            .{ @tagName(.BadRequest), "400 Bad Request" },
            .{ @tagName(.NotFound), "404 Not Found" },
        });

        return status_map.get(@tagName(status_enum)).?;
    }
};
