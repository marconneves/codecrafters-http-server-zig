const std = @import("std");
const req = @import("http_request.zig");
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

    pub fn done(self: *const HttpResponse, buffer: []u8) ![]u8 {
        const status_parsed = parse_status(self.status);

        return std.fmt.bufPrint(
            buffer,
            "{s} {s}" ++ constants.EOL ++ constants.EOL,
            .{ self.version, status_parsed },
        );
    }

    fn parse_status(status_enum: HttpResponseStatusCode) []const u8 {
        const status_map = std.static_string_map.StaticStringMap([]const u8).initComptime(.{
            .{ @tagName(.OK), "200 Ok" },
            .{ @tagName(.Created), "201 Created" },
            .{ @tagName(.BadRequest), "400 Bad Request" },
            .{ @tagName(.NotFound), "404 Not Found" },
        });

        return status_map.get(@tagName(status_enum)).?;
    }
};
