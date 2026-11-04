//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const chdb_zig = @import("chdb.zig");

pub const Connection = chdb_zig.Connection;
pub const Error = chdb_zig.Error;
pub const Result = chdb_zig.Result;
pub const StreamingHandle = chdb_zig.StreamingHandle;
pub const Iterator = chdb_zig.Iterator;
pub const ConnectionOptions = chdb_zig.ConnectionOptions;

pub const initConnection = Connection.init;

test "basic connection initialization" {
    const allocator = std.testing.allocator;
    const options = chdb_zig.ConnectionOptions{ .UseMultiQuery = true };
    const cHandle = try chdb_zig.Connection.init(allocator, options);
    defer cHandle.deinit();
    try std.testing.expect(cHandle.conn != null);
}

test "typed rows with nextAs and findFirstAs" {
    const allocator = std.testing.allocator;
    const cHandle = try chdb_zig.Connection.init(allocator, .{ .UseMultiQuery = true });
    defer cHandle.deinit();
    var result = try cHandle.query(@constCast("SELECT number AS n FROM numbers(5)"));
    defer result.deinit();
    try std.testing.expect(result.isSuccess());

    const Row = struct { n: u64 };
    var it = result.iter(allocator);
    var expected: u64 = 0;
    while (try it.nextAs(Row)) |row| {
        defer row.deinit();
        try std.testing.expectEqual(expected, row.data.single.n);
        expected += 1;
    }
    try std.testing.expectEqual(@as(u64, 5), expected);

    // A row that does not fit the type is an error, and its arena is freed.
    it.reset();
    try std.testing.expectError(chdb_zig.Error.InvalidRow, it.nextAs(struct { n: []const u8 }));

    const atLeastThree = struct {
        fn f(row: Row) bool {
            return row.n >= 3;
        }
    }.f;
    it.reset();
    const found = (try it.findFirstAs(Row, atLeastThree)) orelse return error.TestUnexpectedResult;
    defer found.deinit();
    try std.testing.expectEqual(@as(u64, 3), found.data.single.n);

    const never = struct {
        fn f(row: Row) bool {
            return row.n > 100;
        }
    }.f;
    it.reset();
    try std.testing.expect((try it.findFirstAs(Row, never)) == null);
}
