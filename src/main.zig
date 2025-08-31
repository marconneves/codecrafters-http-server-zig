const std = @import("std");
const net = std.net;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    // Uncomment this block to pass the first stage
    const address = try net.Address.resolveIp("127.0.0.1", 4221);

    var listener = try address.listen(.{
        .reuse_address = true,
    });

    defer listener.deinit();

    var connection = try listener.accept();
    try stdout.print("client connected!", .{});

    _ = try connection.stream.writer().write("HTTP/1.1 200 OK\r\n\r\n");
    connection.stream.close();
}
