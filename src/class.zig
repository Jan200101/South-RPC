const std = @import("std");
const builtin = @import("builtin");

const Fn = std.builtin.Type.Fn;
const StructField = std.builtin.Type.StructField;

pub fn Class(comptime base: anytype, comptime members: anytype) type {
    const BaseType = @TypeOf(base);
    const base_type_info = @typeInfo(BaseType);

    if (base_type_info != .Struct or base_type_info.Struct.is_tuple != true) {
        @compileError("expected tuple base argument, found " ++ @typeName(BaseType));
    }

    const MembersType = @TypeOf(members);
    const members_type_info = @typeInfo(MembersType);

    if (members_type_info != .Struct or members_type_info.Struct.is_tuple != false) {
        @compileError("expected struct members argument, found " ++ @typeName(MembersType));
    }

    const ClassStruct = @Type(.{
        .Struct = .{
            .layout = .@"extern",
            .fields = comptime blk: {
                var class_fields = struct {
                    fields: []const StructField = &[_]StructField{},

                    fn add_virtual(self: anytype, comptime field: StructField) void {
                        self.add_field(.{
                            .name = "vtable",
                            .type = @Type(.{
                                .Struct = .{
                                    .layout = .@"extern",
                                    .fields = &[_]StructField{
                                        field,
                                    },
                                    .decls = &.{},
                                    .is_tuple = false,
                                },
                            }),
                            .default_value = null,
                            .is_comptime = false,
                            .alignment = 0,
                        });
                    }

                    fn add_field(comptime self: anytype, comptime field: StructField) void {
                        if (std.mem.eql(u8, field.name, "vtable")) {
                            const vtable_index: ?comptime_int = for (0.., self.fields) |i, f| {
                                if (std.mem.eql(u8, f.name, "vtable")) break i;
                            } else null;

                            if (vtable_index) |i| {
                                const old_vtable = self.fields[i];
                                const OldVTableType = old_vtable.type;
                                const old_vtable_type_info = @typeInfo(OldVTableType);
                                if (old_vtable_type_info != .Optional) {
                                    @compileError("expected vtable to be optional, found " ++ @typeName(OldVTableType));
                                }

                                const OldVTablePointerType = old_vtable_type_info.Optional.child;
                                const old_vtable_pointer_type_info = @typeInfo(OldVTablePointerType);
                                if (old_vtable_pointer_type_info != .Pointer) {
                                    @compileError("expected vtable to be optional pointer, found " ++ @typeName(OldVTableType));
                                }

                                const OldVTableStructType = old_vtable_pointer_type_info.Pointer.child;
                                const old_vtable_struct_type_info = @typeInfo(OldVTableStructType);
                                if (old_vtable_struct_type_info != .Struct or old_vtable_struct_type_info.Struct.is_tuple != false) {
                                    @compileError("expected vtable to be optional pointer to struct, found pointer to " ++ @typeName(OldVTableType));
                                }

                                const FieldType = field.type;
                                const field_type_info = @typeInfo(FieldType);
                                if (field_type_info != .Struct or field_type_info.Struct.is_tuple != false) {
                                    @compileError("expected new vtable addition to be struct, found " ++ @typeName(FieldType));
                                }

                                self.fields = &[_]StructField{
                                    .{
                                        .name = old_vtable.name,
                                        .type = @Type(.{
                                            .Optional = .{
                                                .child = @Type(.{
                                                    .Pointer = .{
                                                        .size = old_vtable_pointer_type_info.Pointer.size,
                                                        .is_const = old_vtable_pointer_type_info.Pointer.is_const,
                                                        .is_volatile = old_vtable_pointer_type_info.Pointer.is_volatile,
                                                        .alignment = old_vtable_pointer_type_info.Pointer.alignment,
                                                        .address_space = old_vtable_pointer_type_info.Pointer.address_space,
                                                        .child = @Type(.{
                                                            .Struct = .{
                                                                .layout = old_vtable_struct_type_info.Struct.layout,
                                                                .backing_integer = old_vtable_struct_type_info.Struct.backing_integer,
                                                                .fields = old_vtable_struct_type_info.Struct.fields ++ field_type_info.Struct.fields,
                                                                .decls = old_vtable_struct_type_info.Struct.decls,
                                                                .is_tuple = old_vtable_struct_type_info.Struct.is_tuple,
                                                            },
                                                        }),
                                                        .is_allowzero = old_vtable_pointer_type_info.Pointer.is_allowzero,
                                                        .sentinel = old_vtable_pointer_type_info.Pointer.sentinel,
                                                    },
                                                }),
                                            },
                                        }),
                                        .default_value = old_vtable.default_value,
                                        .is_comptime = old_vtable.is_comptime,
                                        .alignment = old_vtable.alignment,
                                    },
                                } ++ self.fields[1..];
                            } else {
                                const FieldType = field.type;
                                const field_type_info = @typeInfo(FieldType);

                                // If we get vtable pointer lets pretend its the real deal
                                if (field_type_info == .Pointer) {
                                    const VTableType = field_type_info.Pointer.child;
                                    const vtable_info = @typeInfo(VTableType);
                                    if (vtable_info != .Struct or vtable_info.Struct.is_tuple != false) {
                                        @compileError("expected vtable to be pointer to struct, found ponter to " ++ @typeName(VTableType));
                                    }

                                    self.fields = self.fields ++ &[_]StructField{field};
                                    return;
                                } else if (field_type_info != .Struct or field_type_info.Struct.is_tuple != false) {
                                    @compileError("expected vtable to be struct, found " ++ @typeName(FieldType));
                                }

                                self.fields = &[_]StructField{
                                    .{
                                        .name = field.name,
                                        .type = @Type(.{
                                            .Optional = .{
                                                .child = @Type(.{
                                                    .Pointer = .{
                                                        .size = .One,
                                                        .is_const = true,
                                                        .is_volatile = false,
                                                        .alignment = 0,
                                                        .address_space = .generic,
                                                        .child = @Type(.{
                                                            .Struct = .{
                                                                .layout = .@"extern",
                                                                .fields = field_type_info.Struct.fields,
                                                                .decls = &.{},
                                                                .is_tuple = false,
                                                            },
                                                        }),
                                                        .is_allowzero = false,
                                                        .sentinel = null,
                                                    },
                                                }),
                                            },
                                        }),
                                        .default_value = null,
                                        .is_comptime = false,
                                        .alignment = 0,
                                    },
                                } ++ self.fields;
                            }
                            return;
                        }

                        for (self.fields) |f| {
                            if (std.mem.eql(u8, f.name, field.name)) {
                                @compileError("duplicate field " ++ f.name);
                            }
                        }
                        self.fields = self.fields ++ &[_]StructField{field};
                    }
                }{};

                // Deal with inheritance first
                for (base) |b| {
                    const b_type_info = @typeInfo(b);

                    if (b_type_info != .Struct or b_type_info.Struct.is_tuple != false) {
                        @compileError("expected struct base, found " ++ @typeName(b));
                    } else if (b_type_info.Struct.layout != .@"extern") {
                        @compileError("expected extern struct, found " ++ @tagName(b_type_info.Struct.layout));
                    }

                    for (b_type_info.Struct.fields) |f| {
                        class_fields.add_field(f);
                    }
                }

                // Deal with all new members
                for (members_type_info.Struct.fields) |member_field| {
                    const member_field_info = @typeInfo(member_field.type);
                    const member = @field(members, member_field.name);

                    if (member_field_info != .Struct or member_field_info.Struct.is_tuple != false) {
                        @compileError("expected struct");
                    }

                    const member_type = member.type;
                    const member_default_value = if (@hasField(@TypeOf(member), "default_value")) &@as(member_type, member.default_value) else null;
                    const member_virtual = if (@hasField(@TypeOf(member), "virtual")) member.virtual else false;

                    if (member_virtual) {
                        class_fields.add_virtual(.{
                            .name = member_field.name,
                            .type = member_type,
                            .default_value = member_default_value,
                            .is_comptime = false,
                            .alignment = 0,
                        });

                        continue;
                    }

                    class_fields.add_field(.{
                        .name = member_field.name,
                        .type = member_type,
                        .default_value = member_default_value,
                        .is_comptime = false,
                        .alignment = 0,
                    });
                }

                break :blk class_fields.fields;
            },
            .decls = members_type_info.Struct.decls,
            .is_tuple = false,
        },
    });

    //_ = ClassStruct;
    return ClassStruct;
}

pub fn print_struct(comptime tag: std.builtin.Type, comptime prefix: []const u8) void {
    if (tag != .Struct) {
        @compileError("bruh");
    }

    std.debug.print("{s}struct len {} layout {}\n", .{
        prefix,
        tag.Struct.fields.len,
        tag.Struct.layout,
    });

    inline for (1.., tag.Struct.fields) |i, field| {
        std.debug.print("{s}{}: \"{s}\" {} = {any} ({}, {})\n", .{
            prefix ++ "\t",
            i,
            field.name,
            field.type,
            field.default_value,
            field.is_comptime,
            field.alignment,
        });

        const t = @typeInfo(field.type);
        if (t == .Struct) {
            print_struct(t, prefix ++ "\t");
        } else if (t == .Pointer) {
            const p = @typeInfo(t.Pointer.child);
            if (p == .Struct) {
                print_struct(p, prefix ++ "\t");
            }
        }
    }
    std.debug.print("\n", .{});
}

fn compare_struct_type(comptime a: std.builtin.Type, comptime b: std.builtin.Type) !void {
    if (a != .Struct or b != .Struct) {
        return error.TestUnexpectedResult;
    }

    try std.testing.expectEqual(a.Struct.layout, b.Struct.layout);
    try std.testing.expectEqual(a.Struct.backing_integer, b.Struct.backing_integer);
    try std.testing.expect(a.Struct.fields.len == b.Struct.fields.len);
    try std.testing.expectEqual(a.Struct.decls.len, b.Struct.decls.len);
    try std.testing.expectEqual(a.Struct.is_tuple, b.Struct.is_tuple);

    inline for (0..@min(a.Struct.fields.len, b.Struct.fields.len)) |i| {
        const field_a = a.Struct.fields[i];
        const field_b = b.Struct.fields[i];

        try std.testing.expect(std.mem.eql(u8, field_a.name, field_b.name));
        try std.testing.expectEqual(field_a.type, field_b.type);
        if (field_a.default_value != null and field_b.default_value != null) {
            const default_value_a = @as(*const field_a.type, @alignCast(@ptrCast(field_a.default_value)));
            const default_value_b = @as(*const field_b.type, @alignCast(@ptrCast(field_b.default_value)));

            try std.testing.expectEqual(default_value_a.*, default_value_b.*);
        } else {
            try std.testing.expectEqual(field_a.default_value, field_b.default_value);
        }
        try std.testing.expectEqual(field_a.is_comptime, field_b.is_comptime);
        try std.testing.expectEqual(field_a.alignment, field_b.alignment);
    }
}

test "basic layout" {
    const struct_layout = extern struct {
        len: usize = 0xCAFE,
        field: f32,
    };

    const class_layout = Class(.{}, .{
        .len = .{ .type = usize, .default_value = 0xCAFE },
        .field = .{ .type = f32 },
    });

    try compare_struct_type(
        @typeInfo(struct_layout),
        @typeInfo(class_layout),
    );
}
