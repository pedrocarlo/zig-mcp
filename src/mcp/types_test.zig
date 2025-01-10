const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const json = std.json;
const builtin = std.builtin;
const log = std.log;
const BetterObjectMap = @import("extended_object_map.zig").BetterObjectMap;
const types = @import("types.zig");

test "progressToken parse" {
    const TestStruct = struct { progressToken: types.ProgressToken };

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

test "initialize request" {
    var experimental = BetterObjectMap.init(testing.allocator);
    defer experimental.deinit();

    try experimental.inner.put("test", json.Value{ .integer = 1 });

    var sampling = BetterObjectMap.init(testing.allocator);
    defer sampling.deinit();

    try sampling.inner.put("test", json.Value{ .integer = 1 });

    const initial_req = types.InitializeRequest{
        .params = .{
            .protocolVersion = "1.0",
            .capabilities = .{
                .experimental = experimental,
                .sampling = sampling,
            },
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
        \\  },
        \\  "sampling": {
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

    const parsed = try json.parseFromSlice(types.Request, testing.allocator, document_str, .{});
    defer parsed.deinit();

    const parsed_initialize = parsed.value.request.initialize;
    try testing.expectEqualDeep(initial_req.method, parsed_initialize.method);

    try testing.expectEqualDeep(initial_req.params.?.protocolVersion, parsed_initialize.params.?.protocolVersion);

    try testing.expectEqualDeep(experimental.inner.get("test"), parsed_initialize.params.?.capabilities.experimental.?.inner.get("test"));

    try testing.expectEqualDeep(initial_req.params.?.capabilities.roots, parsed_initialize.params.?.capabilities.roots);

    const sampling_expected = initial_req.params.?.capabilities.sampling;
    const sampling_actual = parsed_initialize.params.?.capabilities.sampling;

    try testing.expect(sampling_expected != null);
    try testing.expect(sampling_actual != null);

    var iterator = sampling_expected.?.inner.iterator();

    while (iterator.next()) |entry| {
        const field_name = entry.key_ptr.*;

        const expected_result = sampling_actual.?.inner.get(field_name);

        try testing.expectEqualDeep(entry.value_ptr.*, expected_result);
    }
}
