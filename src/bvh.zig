const std = @import("std");

const hittable = @import("hittable.zig");
const Hittable = hittable.Hittable;
const HitRecord = hittable.HitRecord;

const Ray = @import("Ray.zig");

const Aabb = @import("Aabb.zig");

pub const BvhTree = struct {
    allocator: std.mem.Allocator,
    rand: std.Random,

    root: ?*Hittable = null,

    pub fn init(allocator: std.mem.Allocator, rand: std.Random) BvhTree {
        return .{
            .allocator = allocator,
            .rand = rand,
        };
    }

    pub fn deinit(self: *BvhTree) void {
        if (self.root) |r| {
            self.destroySubtree(r);
            self.root = null;
        }
    }

    fn destroySubtree(self: *BvhTree, node: *Hittable) void {
        return switch (node.*) {
            .bvh_node => |n| {
                self.destroySubtree(n.left);
                self.destroySubtree(n.right);
                self.allocator.destroy(node);
            },
            else => return,
        };
    }

    pub fn createNode(self: BvhTree, left: *Hittable, right: *Hittable) !*Hittable {
        const hit_node = try self.allocator.create(Hittable);
        const node = BvhNode.init(left, right);
        hit_node.* = .{ .bvh_node = node };
        return hit_node;
    }

    pub fn fromSlice(self: *BvhTree, items: []Hittable) !*Hittable {
        const len = items.len;
        if (len == 1) {
            const node = try self.createNode(&items[0], &items[0]);
            self.root = node;
            return node;
        }

        if (len == 2) {
            const node = try self.createNode(&items[0], &items[1]);
            self.root = node;
            return node;
        }

        const ctx = hittable.SortContext{ .items = items, .seed = self.rand.enumValue(hittable.SortContext.SortType) };
        std.sort.heapContext(0, len, ctx);

        const left = try self.fromSlice(items[0 .. len / 2]);
        const right = try self.fromSlice(items[len / 2 ..]);
        const node = try self.createNode(left, right);
        self.root = node;
        return node;
    }

    pub fn hit(self: BvhTree, ray_in: Ray, t_min: f64, t_max: f64) HitRecord {
        return self.root.?.hit(ray_in, t_min, t_max);
    }

    pub fn boundingBox(self: BvhTree) Aabb {
        return self.root.?.boundingBox();
    }
};

pub const BvhNode = struct {
    left: *Hittable,
    right: *Hittable,
    aabb: Aabb,

    pub fn init(left: *Hittable, right: *Hittable) BvhNode {
        return .{
            .left = left,
            .right = right,
            .aabb = Aabb.combine(left.boundingBox(), right.boundingBox()),
        };
    }

    pub fn hit(self: BvhNode, ray_in: Ray, t_min: f64, t_max: f64) HitRecord {
        if (!self.aabb.intersect(ray_in, t_min, t_max)) {
            return .{ .is_hit = false };
        }

        const hit_left = self.left.hit(ray_in, t_min, t_max);
        const hit_right = self.right.hit(ray_in, t_min, t_max);
        if (!hit_left.is_hit) {
            return hit_right;
        }
        if (!hit_right.is_hit) {
            return hit_left;
        }
        if (hit_left.time < hit_right.time) {
            return hit_left;
        }
        return hit_right;
    }

    pub fn boundingBox(self: BvhNode) Aabb {
        return self.aabb;
    }
};
