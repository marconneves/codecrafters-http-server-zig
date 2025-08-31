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

    var buffer: [1024]u8 = undefined;

    const bytes_read = try connection.stream.reader().read(&buffer);

    if (bytes_read > 0) {
        const request_data = buffer[0..bytes_read];
        try stdout.print("Buffer como string: {s}\n", .{request_data});

        if (std.mem.indexOf(u8, request_data, "GET / ") != null) {
            _ = try connection.stream.writer().write("HTTP/1.1 200 OK\r\n\r\n");
        } else {
            _ = try connection.stream.writer().write("HTTP/1.1 404 Not Found\r\n\r\n");
        }
    } else {
        _ = try connection.stream.writer().write("HTTP/1.1 500 Internal Server Error\r\n\r\n");
    }

    connection.stream.close();
}
