const std = @import("std");
const constants = @import("constants.zig");
const HttpHeaders = @import("http_headers.zig").HttpHeaders;

const mem = std.mem;

pub const HttpRequestMethod = enum(u8) { POST, GET, PUT, DELETE, PATCH };

pub const HttpRequest = struct {
    method: HttpRequestMethod,
    uri: []const u8,
    version: []const u8,
    headers: HttpHeaders,

    pub fn init(method: HttpRequestMethod, uri: []const u8, version: []const u8) HttpRequest {
        return HttpRequest{ .method = method, .uri = uri, .version = version };
    }

    pub fn allocInit(alloc: std.mem.Allocator, method: HttpRequestMethod, uri: []const u8, version: []const u8, headers: HttpHeaders) !HttpRequest {
        return HttpRequest{ .method = method, .uri = try alloc.dupe(u8, uri), .version = try alloc.dupe(u8, version), .headers = headers };
    }

    pub fn deinit(self: *const HttpRequest, alloc: std.mem.Allocator) void {
        alloc.free(self.uri);
        alloc.free(self.version);
    }

    fn parse_method(method_str: []const u8) !HttpRequestMethod {
        const method_map = std.static_string_map.StaticStringMap(HttpRequestMethod).initComptime(.{
            .{ "GET", HttpRequestMethod.GET },
            .{ "POST", HttpRequestMethod.POST },
            .{ "PATCH", HttpRequestMethod.PATCH },
            .{ "PUT", HttpRequestMethod.PUT },
            .{ "DELETE", HttpRequestMethod.DELETE },
        });

        return method_map.get(method_str).?;
    }

    pub fn parse(alloc: std.mem.Allocator, reader: std.io.AnyReader) !HttpRequest {
        var request: ?HttpRequest = undefined;
        const buffer = try alloc.alloc(u8, 1024);
        defer alloc.free(buffer);

        @memset(buffer, 0);

        _ = try reader.read(buffer);

        var sections_split = mem.splitSequence(u8, buffer, constants.EOL);

        const parsed_secton = sections_split.next() orelse return error.InvalidRequest;

        var parts = mem.splitAny(u8, parsed_secton, " ");

        const method = try HttpRequest.parse_method(parts.next().?);
        const uri = parts.next().?;
        const version = parts.next().?;

        const headers = try HttpHeaders.parse(buffer, alloc);

        request = try HttpRequest.allocInit(alloc, method, uri, version, headers);

        return request.?;
    }
};
