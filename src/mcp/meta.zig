const std = @import("std");
const builtin = std.builtin;
const mem = std.mem;
const json = std.json;

/// Comptime merge of fields
pub fn Merge(comptime StructA: type, comptime StructB: type) type {
    const a_fields = @typeInfo(StructA).Struct.fields;
    const b_fields = @typeInfo(StructB).Struct.fields;

    // log.debug("fields a: {}\n fields b: {}\n", .{ a_fields, b_fields });
    @compileLog("fields a", a_fields);

    return @Type(builtin.Type{ .Struct = .{
        .layout = .auto,
        .fields = a_fields ++ b_fields,
        .is_tuple = false,
        .decls = &.{},
    } });
}

/// Comptime Extend of fields
///
/// Adds fields from parents but does not override fields in child.
/// If there is an overlaping field name, the child field is prioritized
///
/// Does not extends declarations
pub fn Extend(comptime Child: type, comptime types: []const type) type {
    const child_fields = @typeInfo(Child).Struct.fields;

    const field_names = blk: {
        const lst = std.meta.fieldNames(Child);
        var ret: [lst.len]struct { []const u8 } = undefined;
        for (std.meta.fieldNames(Child), 0..) |name, index| {
            ret[index] = .{name};
        }
        break :blk ret;
    };

    // const child_field_enum = std.meta.FieldEnum(Child);
    const child_field_names = std.StaticStringMap(void).initComptime(field_names);

    comptime var len: usize = 0;
    inline for (types) |T| {
        const t = @typeInfo(T);

        inline for (t.Struct.fields) |field| {
            const child_field_name = child_field_names.get(field.name);
            // If it does not conflict with child fields add the parents' field
            if (child_field_name == null) {
                len += 1;
            }
        }
        // Add child fields to len
        // len += child_fields.len;
    }

    var fields: [len]builtin.Type.StructField = undefined;
    var i: usize = 0;
    inline for (types) |T| {
        inline for (@typeInfo(T).Struct.fields) |field| {
            const child_field_name = child_field_names.get(field.name);
            if (child_field_name == null) {
                fields[i] = field;
                i += 1;
            }
        }
    }
    const decls = @typeInfo(Child).Struct.decls;

    // @compileLog("fields\n", fields, "\n child fields\n", field_names);

    return @Type(builtin.Type{ .Struct = .{
        .layout = .auto,
        .fields = child_fields ++ fields,
        .is_tuple = false,
        .decls = decls,
    } });
}

/// Adds non overlapping declarations.
/// Generating new type with added declarations
pub fn AddDecls(comptime Child: type, comptime Other: type) type {
    const child = @typeInfo(Child);

    const fields = child.@"struct".fields ++ @typeInfo(Other).@"struct".fields;

    const decls = [_]builtin.Type.Declaration{};

    return @Type(builtin.Type{ .@"struct" = .{
        .layout = .auto,
        .fields = fields,
        .is_tuple = false,
        .decls = &decls
        // .decls = decls,
    } });
}
