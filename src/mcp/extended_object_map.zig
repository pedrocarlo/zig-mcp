const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const json = std.json;
const AddDecls = @import("meta.zig").AddDecls;

pub const BetterObjectMap = struct {
    const Self = @This();

    inner: json.ObjectMap,

    pub fn init(allocator: mem.Allocator) Self {
        return .{ .inner = json.ObjectMap.init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.inner.deinit();
    }

    pub fn jsonStringify(self: Self, jws: anytype) !void {
        try jws.beginObject();
        var it = self.inner.iterator();
        while (it.next()) |entry| {
            try jws.objectField(entry.key_ptr.*);
            try jws.write(entry.value_ptr.*);
        }
        try jws.endObject();
    }

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
        const value = try json.innerParse(json.Value, allocator, source, options);

        return try jsonParseFromValue(allocator, value, options);
    }

    pub fn jsonParseFromValue(
        allocator: mem.Allocator,
        value: json.Value,
        options: json.ParseOptions,
    ) json.ParseFromValueError!Self {
        _ = allocator;
        _ = options;

        return switch (value) {
            .object => return .{ .inner = value.object },
            // TODO better error here
            else => error.MissingField,
        };
    }
};
