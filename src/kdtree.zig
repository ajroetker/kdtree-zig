const std = @import("std");
const testing = std.testing;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const test_allocator = std.testing.allocator;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub const Node = struct {
    data: []const u8,
    left: ?*Node = null,
    right: ?*Node = null,
    pub fn insert(
        self: *Node,
        allocator: *const Allocator,
        point: []const u8,
        axis: usize,
    ) void {
        if (point[axis] < self.data[axis]) {
            if (self.left == null) {
                self.left = allocator.create(Node) catch |err| {
                    std.debug.print("error creating node: {}\n", .{err});
                    return;
                };
                self.left.?.* = Node{ .data = point };
            } else {
                self.left.?.insert(allocator, point, @mod((axis + 1), self.data.len));
            }
        } else {
            if (self.right == null) {
                self.right = allocator.create(Node) catch |err| {
                    std.debug.print("error creating node: {}\n", .{err});
                    return;
                };
                self.right.?.* = Node{ .data = point };
            } else {
                self.right.?.insert(allocator, point, @mod((axis + 1), self.data.len));
            }
        }
        return;
    }
    pub fn rangeSearch(
        self: *const Node,
        accumulator: *ArrayList([]const u8),
        // min, max in each dimension
        range: []const [2]u8,
        axis: usize,
    ) void {
        for (range, 0..) |min_max, dimension| {
            if (min_max[0] > self.data[dimension] or min_max[1] < self.data[dimension]) {
                self.checkChildren(accumulator, range, dimension);
                return;
            }
        }
        self.checkChildren(accumulator, range, axis);
        accumulator.append(self.data) catch |err| {
            std.debug.print("error appending: {}\n", .{err});
            return;
        };
    }
    fn checkChildren(
        self: *const Node,
        accumulator: *ArrayList([]const u8),
        // min, max in each dimension
        range: []const [2]u8,
        axis: usize,
    ) void {
        if (self.left != null) {
            if (self.left.?.data[axis] >= range[axis][0]) {
                self.left.?.rangeSearch(accumulator, range, @mod((axis + 1), self.data.len));
            }
        }
        if (self.right != null) {
            if (self.right.?.data[axis] <= range[axis][1]) {
                self.right.?.rangeSearch(accumulator, range, @mod((axis + 1), self.data.len));
            }
        }
    }

    pub fn dealloc(self: *Node, allocator: *const Allocator) void {
        if (self.left) |left_node| {
            left_node.dealloc(allocator);
            allocator.destroy(left_node);
        }
        if (self.right) |right_node| {
            right_node.dealloc(allocator);
            allocator.destroy(right_node);
        }
    }
};

pub const KDTree = extern struct {
    root: ?*Node = null,
    allocator: *const Allocator,
    pub fn insert(
        self: *KDTree,
        point: []const u8,
    ) void {
        if (self.root == null) {
            self.root = self.allocator.create(Node) catch |err| {
                std.debug.print("error creating node: {}\n", .{err});
                return;
            };
            self.root.?.* = Node{ .data = point };
        } else {
            self.root.?.insert(self.allocator, point, 0);
        }
    }
    pub fn rangeSearch(
        self: *const KDTree,
        accumulator: *ArrayList([]const u8),
        // min, max in each dimension
        range: []const [2]u8,
    ) void {
        if (self.root == null) {
            return;
        }
        self.root.?.rangeSearch(accumulator, range, 0);
    }

    pub fn dealloc(self: *KDTree) void {
        if (self.root) |root_node| {
            root_node.dealloc(self.allocator);
            self.allocator.destroy(root_node);
        }
    }
};

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);

    var oman = KDTree{ .allocator = &test_allocator };
    var kdtree: *KDTree = &oman;
    kdtree.insert(&[_]u8{ 1, 2, 0 });
    kdtree.insert(&[_]u8{ 1, 0, 0 });
    kdtree.insert(&[_]u8{ 0, 2, 2 });
    kdtree.insert(&[_]u8{ 1, 2, 2 });
    var array = ArrayList([]const u8).init(test_allocator);
    kdtree.rangeSearch(&array, &[3][2]u8{ [2]u8{ 0, 2 }, [2]u8{ 0, 2 }, [2]u8{ 1, 2 } });
    try testing.expect(array.items.len == 2);
    array.clearAndFree();
    kdtree.dealloc();
}
