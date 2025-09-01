const std = @import("std");
const net = std.net;

const req = @import("http/http_request.zig");
const res = @import("http/http_response.zig");

const headersImport = @import("http/http_headers.zig");
const HttpHeaders = headersImport.HttpHeaders;
const HttpHeader = headersImport.HttpHeader;

pub fn main() !void {
    var gba = std.heap.GeneralPurposeAllocator(.{}){};

    const alloc = gba.allocator();
    const stdout = std.io.getStdOut().writer();

    const address = try net.Address.resolveIp("127.0.0.1", 4221);

    var listener = try address.listen(.{
        .reuse_address = true,
    });

    defer listener.deinit();

    var connection = try listener.accept();
    try stdout.print("client connected!\n", .{});

    const request = try req.HttpRequest.parse(alloc, connection.stream.reader().any());
    defer request.deinit(alloc);

    var resp_buffer: [1024]u8 = undefined;

    var headers = HttpHeaders{ .headers = &.{} };
    defer headers.deinit(alloc);

    try headers.add(alloc, "Content-Type", "text/plain");

    var resp = res.HttpResponse{ .status = undefined, .headers = headers };

    if (std.mem.eql(u8, request.uri, "/")) {
        resp.status = res.HttpResponseStatusCode.OK;
        resp.body = "";
        resp.headers = headers;
    } else if (std.mem.startsWith(u8, request.uri, "/echo/")) {
        var parts = std.mem.splitSequence(u8, request.uri, "/");

        _ = parts.next();
        _ = parts.next();

        if (parts.next()) |body_value| {
            resp.status = res.HttpResponseStatusCode.OK;

            var len_buffer: [32]u8 = undefined;
            const len_str = try std.fmt.bufPrint(&len_buffer, "{}", .{body_value.len});
            try headers.add(alloc, "Content-Length", len_str);

            resp.body = body_value;
            resp.headers = headers;
        } else {
            resp.status = res.HttpResponseStatusCode.BadRequest;
            resp.body = "";
            resp.headers = headers;
        }
    } else {
        resp.status = res.HttpResponseStatusCode.NotFound;
        resp.headers = headers;
    }

    std.debug.print("Request: {any}, {s}, {s}\n", .{ request.method, request.uri, request.version });

    _ = try connection.stream.writer().write(try resp.done(&resp_buffer));

    connection.stream.close();
}
