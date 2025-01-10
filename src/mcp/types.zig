const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const json = std.json;
const builtin = std.builtin;
const log = std.log;
const BetterObjectMap = @import("extended_object_map.zig").BetterObjectMap;

test {
    @import("std").testing.refAllDecls(@This());
}

pub const LATEST_PROTOCOL_VERSION = "2024-11-05";
pub const JSONRPC_VERSION = "2.0";

const ProgressTokenTags = enum { string, number };

/// A progress token, used to associate progress notifications with the original request.
pub const ProgressToken = union(ProgressTokenTags) {
    const Self = @This();

    string: []const u8,
    number: i64,

    pub fn jsonStringify(self: *Self, jw: anytype) !void {
        try switch (self.*) {
            .string => |str| jw.write(str),
            .number => |num| jw.write(num),
        };
    }

    pub fn jsonParse(
        allocator: mem.Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!Self {
        const value = try json.innerParse(json.Value, allocator, source, options);

        return switch (value) {
            .string => |v| Self{ .string = v },
            .integer => |v| Self{ .number = v },
            else => error.UnexpectedToken,
        };
    }
};

test "progressToken parse" {
    const TestStruct = struct { progressToken: ProgressToken };

    const document_str =
        \\{"progressToken":1}
    ;
    const parsed = try json.parseFromSlice(TestStruct, testing.allocator, document_str, .{});
    defer parsed.deinit();

    switch (parsed.value.progressToken) {
        .string => unreachable, // try testing.expectEqualSlices(u8, "1", v)
        .number => |v| try testing.expectEqual(1, v),
    }

    const document_str_2 =
        \\{"progressToken":"1"}
    ;
    const parsed2 = try json.parseFromSlice(TestStruct, testing.allocator, document_str_2, .{ .allocate = .alloc_always });
    defer parsed2.deinit();

    switch (parsed2.value.progressToken) {
        .string => |v| try testing.expectEqualSlices(u8, "1", v),
        .number => unreachable,
    }
}

/// An opaque token used to represent a cursor for pagination.
pub const Cursor = *[]u8;

const RequestTypes = union(enum) {
    initialize: InitializeRequest,
};

pub const Request = struct {
    const Self = @This();

    request: RequestTypes,

    // pub fn jsonStringify(self: *Self, jw: anytype) !void {
    //     try switch (self.*.request) {
    //         .initialize => |req| jw.write(req),
    //     };
    // }

    pub fn jsonParse(
        allocator: mem.Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) !Self {
        const value = try json.innerParse(json.Value, allocator, source, options);

        return Self.jsonParseFromValue(allocator, value, options);
    }

    pub fn jsonParseFromValue(
        allocator: mem.Allocator,
        value: json.Value,
        options: json.ParseOptions,
    ) json.ParseFromValueError!Self {
        _ = options;

        const method = value.object.get("method");

        if (method == null) {
            return error.MissingField;
        }

        const methodStr = switch (method.?) {
            .string => method.?.string,
            else => return error.UnexpectedToken,
        };

        if (mem.eql(u8, "initialize", methodStr)) {
            const parsed = try json.innerParseFromValue(InitializeRequest, allocator, value, .{});

            return Self{ .request = .{ .initialize = parsed } };
        }
        return error.UnexpectedToken;
    }
};

const RequestIdtags = enum { string, number };

/// A uniquely identifying ID for a request in JSON-RPC.
pub const RequestId = union(RequestIdtags) {
    const Self = @This();

    string: []const u8,
    number: i64,

    pub fn jsonStringify(self: *Self, jw: anytype) !void {
        try switch (self.*) {
            .string => |str| jw.write(str),
            .number => |num| jw.write(num),
        };
    }

    pub fn jsonParse(
        allocator: mem.Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!Self {
        const value = try json.innerParse(json.Value, allocator, source, options);
        return switch (value) {
            .string => |v| Self{ .string = v },
            .integer => |v| Self{ .number = v },
            else => error.UnexpectedToken,
        };
    }
};

pub const InitializeRequest = struct {
    const Self = @This();

    method: []const u8 = "initialize",
    params: ?struct {
        /// The latest version of the Model Context Protocol that the client supports. The client MAY decide to support older versions as well.
        protocolVersion: []const u8,
        capabilities: ClientCapabilities,
        clientInfo: Implementation,
    },
};

/// Capabilities a client may support. Known capabilities are defined here, in this schema, but this is not a closed set: any client can define its own, additional capabilities.
const ClientCapabilities = struct {
    /// Experimental, non-standard capabilities that the client supports.
    experimental: ?BetterObjectMap = null,

    /// Present if the client supports listing roots.
    roots: ?struct {
        /// Whether the client supports notifications for changes to the roots list.
        listChanged: ?bool = null,
    } = null,

    //// Present if the client supports sampling from an LLM.
    sampling: ?BetterObjectMap = null,
};

/// Describes the name and version of an MCP implementation.
const Implementation = struct {
    name: []const u8,
    version: []const u8,
};

test "initialize request" {
    const initialReq = InitializeRequest{
        .params = .{
            .protocolVersion = "1.0",
            .capabilities = .{ .experimental = .{ .inner = BetterObjectMap } },
            .clientInfo = .{
                .name = "client",
                .version = "0.0.0",
            },
        },
    };
    // _ = initialReq;

    const document_str =
        \\ {
        \\ "method": "initialize",
        \\  "params": {
        \\  "protocolVersion": "1.0",
        \\"capabilities": {
        \\  "experimental": {
        \\      "test": 1
        \\  }
        \\},
        \\"clientInfo": {
        \\  "name": "client",
        \\  "version": "0.0.0"
        \\}
        \\}
        \\}
    ;

    const parsed = try json.parseFromSlice(Request, testing.allocator, document_str, .{});
    defer parsed.deinit();

    try testing.expectEqualDeep(initialReq, parsed.value.request.initialize);

    // std.debug.print("type {}\n", .{parsed.value});
}
