const std = @import("std");
const net = std.net;
const req = @import("http_request.zig");
const res = @import("http_response.zig");

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

    var resp = res.HttpResponse{
        .status = undefined,
    };

    if (std.mem.eql(u8, request.uri, "/")) {
        resp.status = res.HttpResponseStatusCode.OK;
    } else {
        resp.status = res.HttpResponseStatusCode.NotFound;
    }

    std.debug.print("Request: {any}, {s}, {s}\n", .{ request.method, request.uri, request.version });

    _ = try connection.stream.writer().write(try resp.done(&resp_buffer));

    connection.stream.close();
}
