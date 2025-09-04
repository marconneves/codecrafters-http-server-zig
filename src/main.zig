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

    while (true) {
        try stdout.print("await connection!\n", .{});
        const connection = try listener.accept();

        _ = try std.Thread.spawn(.{}, handleRequest, .{ alloc, connection });
    }
}

fn handleRequest(alloc: std.mem.Allocator, connection: net.Server.Connection) !void {
    defer connection.stream.close();

    const request = try req.HttpRequest.parse(alloc, connection.stream.reader().any());
    defer request.deinit(alloc);

    var resp_buffer: [1024]u8 = undefined;

    var headers = HttpHeaders{ .headers = &.{} };
    defer headers.deinit(alloc);

    var resp = res.HttpResponse{ .connection = connection, .status = res.HttpResponseStatusCode.NotFound, .headers = headers };

    if (std.mem.eql(u8, request.uri, "/")) {
        try headers.add(alloc, "Content-Type", "text/plain");
        resp.status = res.HttpResponseStatusCode.OK;
        resp.body = "";
        resp.headers = headers;
    } else if (std.mem.startsWith(u8, request.uri, "/files/")) {
        var parts = std.mem.splitSequence(u8, request.uri, "/");

        _ = parts.next();
        _ = parts.next();

        if (parts.next()) |file_name| {
            if (std.fs.cwd().openFile(file_name, .{ .mode = .read_only })) |file| {
                const data = try file.readToEndAlloc(alloc, 1024 * 1024);

                const stat = try file.stat();
                const file_size = stat.size;

                std.debug.print("File '{s}' exists.\n", .{file_name});

                try headers.add(alloc, "Content-Type", "application/octet-stream");

                var len_buffer: [32]u8 = undefined;
                const len_str = try std.fmt.bufPrint(&len_buffer, "{}", .{file_size});
                try headers.add(alloc, "Content-Length", len_str);

                resp.status = res.HttpResponseStatusCode.OK;
                resp.body = data;
                resp.headers = headers;
            } else |_| {
                try headers.add(alloc, "Content-Type", "text/plain");
                resp.status = res.HttpResponseStatusCode.NotFound;
                resp.body = "";
                resp.headers = headers;
            }
        } else {
            try headers.add(alloc, "Content-Type", "text/plain");
            resp.status = res.HttpResponseStatusCode.BadRequest;
            resp.body = "";
            resp.headers = headers;
        }
    } else if (std.mem.startsWith(u8, request.uri, "/echo/")) {
        var parts = std.mem.splitSequence(u8, request.uri, "/");

        _ = parts.next();
        _ = parts.next();

        if (parts.next()) |body_value| {
            try headers.add(alloc, "Content-Type", "text/plain");

            var len_buffer: [32]u8 = undefined;
            const len_str = try std.fmt.bufPrint(&len_buffer, "{}", .{body_value.len});
            try headers.add(alloc, "Content-Length", len_str);

            resp.status = res.HttpResponseStatusCode.OK;
            resp.body = body_value;
            resp.headers = headers;
        } else {
            try headers.add(alloc, "Content-Type", "text/plain");
            resp.status = res.HttpResponseStatusCode.BadRequest;
            resp.body = "";
            resp.headers = headers;
        }
    } else if (std.mem.eql(u8, request.uri, "/user-agent")) {
        if (request.headers.get("User-Agent")) |agent| {
            try headers.add(alloc, "Content-Type", "text/plain");

            var len_buffer: [32]u8 = undefined;
            const len_str = try std.fmt.bufPrint(&len_buffer, "{}", .{agent.len});
            try headers.add(alloc, "Content-Length", len_str);

            resp.status = res.HttpResponseStatusCode.OK;
            resp.body = agent;
            resp.headers = headers;
        } else {
            try headers.add(alloc, "Content-Type", "text/plain");
            resp.status = res.HttpResponseStatusCode.BadRequest;
            resp.body = "";
            resp.headers = headers;
        }
    } else {
        try headers.add(alloc, "Content-Type", "text/plain");
        resp.status = res.HttpResponseStatusCode.NotFound;
        resp.headers = headers;
    }

    std.debug.print("Request: {any}, {s}, {s}\n", .{ request.method, request.uri, request.version });

    try resp.done(&resp_buffer);
}
