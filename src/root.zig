const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const json = std.json;

const Tag = enum { string, number };

const TestId = union(Tag) {
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

        return Self.jsonParseFromValue(allocator, value, options);
    }

    // You can write this branching directly inside `jsonParse`, unless
    // this structure is indirectly parsed
    pub fn jsonParseFromValue(
        allocator: mem.Allocator,
        value: json.Value,
        options: json.ParseOptions,
    ) json.ParseFromValueError!Self {
        _ = allocator;
        _ = options;
        return switch (value) {
            .string => |v| Self{ .string = v },
            .integer => |v| Self{ .number = v },
            else => error.UnexpectedToken,
        };
    }
};

const TestStruct = struct { id: TestId };

test "union string and number" {
    const document_str =
        \\{"id":1}
    ;
    const parsed = try json.parseFromSlice(TestStruct, testing.allocator, document_str, .{});
    defer parsed.deinit();

    switch (parsed.value.id) {
        .string => unreachable, // try testing.expectEqualSlices(u8, "1", v)
        .number => |v| try testing.expectEqual(1, v),
    }

    const document_str_2 =
        \\{"id":"1"}
    ;
    const parsed2 = try json.parseFromSlice(TestStruct, testing.allocator, document_str_2, .{ .allocate = .alloc_always });
    defer parsed2.deinit();

    switch (parsed2.value.id) {
        .string => |v| try testing.expectEqualSlices(u8, "1", v),
        .number => unreachable,
    }
}
