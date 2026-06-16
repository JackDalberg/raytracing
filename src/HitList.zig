const std = @import("std");

const Ray = @import("Ray.zig");

const hittable = @import("hittable.zig");

const Aabb = @import("Aabb.zig");

pub const HitList = @This();

allocator: std.mem.Allocator,
list: std.ArrayList(hittable.Hittable),
aabb: ?Aabb,

pub fn init(allocator: std.mem.Allocator) !HitList {
    return .{
        .allocator = allocator,
        .list = try std.ArrayList(hittable.Hittable).initCapacity(allocator, 0),
        .aabb = null,
    };
}

pub fn deinit(self: *HitList) void {
    self.list.deinit(self.allocator);
}

pub fn append(self: *HitList, item: hittable.Hittable) !void {
    try self.list.append(self.allocator, item);
    if (self.aabb) |aabb| {
        self.aabb = Aabb.combine(aabb, item.boundingBox());
    } else {
        self.aabb = item.boundingBox();
    }
}

pub fn hit(self: HitList, ray: Ray, t_min: f64, t_max: f64) hittable.HitRecord {
    var hr: hittable.HitRecord = .{ .is_hit = false, .time = t_max };
    for (self.list.items) |candidate| {
        const possible_hr = candidate.hit(ray, t_min, hr.time);
        if (possible_hr.is_hit) {
            hr = possible_hr;
        }
    }
    return hr;
}

// Maybe shouldnt unwrap unsafely, but makes it easier to catch hit lists with not items.
pub fn boundingBox(self: HitList) Aabb {
    return self.aabb.?;
}
