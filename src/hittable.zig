const std = @import("std");

const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Point = vec.Point;

const Ray = @import("Ray.zig");

const HitList = @import("HitList.zig");

const mat_zig = @import("material.zig");
const Material = mat_zig.Material;

const Aabb = @import("Aabb.zig");

const bvh = @import("bvh.zig");
const BvhTree = bvh.BvhTree;
const BvhNode = bvh.BvhNode;

pub const HitRecord = struct {
    is_hit: bool = false,
    front_face: bool = false,
    point: Point = undefined,
    normal: Vec3 = undefined,
    time: f32 = 0.0,
    material: Material = undefined,
    u: f32 = 0.0,
    v: f32 = 0.0,

    pub fn init(ray: Ray, time: f32, outward_normal: Vec3, material: Material) HitRecord {
        const front_face = (vec.dot(ray.direction, outward_normal) < 0);
        const point = ray.atTime(time);
        return .{
            .is_hit = true,
            .front_face = front_face,
            .point = point,
            .normal = if (front_face) outward_normal else -outward_normal,
            .time = time,
            .material = material,
        };
    }
};

pub const Hittable = union(enum) {
    // Basic types.
    sphere: Sphere,

    // Aggregate types.
    hit_list: HitList,
    bvh_tree: BvhTree,
    bvh_node: BvhNode,

    pub fn hit(self: Hittable, ray: Ray, t_min: f32, t_max: f32) HitRecord {
        return switch (self) {
            .sphere => |s| s.hit(ray, t_min, t_max),
            .hit_list => |hl| hl.hit(ray, t_min, t_max),
            .bvh_tree => |b| b.hit(ray, t_min, t_max),
            .bvh_node => |b| b.hit(ray, t_min, t_max),
        };
    }

    pub fn boundingBox(self: Hittable) Aabb {
        return switch (self) {
            .sphere => |s| s.boundingBox(),
            .hit_list => |hl| hl.boundingBox(),
            .bvh_tree => |b| b.boundingBox(),
            .bvh_node => |b| b.boundingBox(),
        };
    }

};

pub const SortContext = struct {
    items: []Hittable,
    seed: SortType,
    // Which axis to sort by
    pub const SortType = enum {
        x,
        y,
        z,
    };

    pub fn lessThan(ctx: SortContext, a: usize, b: usize) bool {
        const a_box = ctx.items[a].boundingBox();
        const b_box = ctx.items[b].boundingBox();
        return switch (ctx.seed) {
            .x => a_box.x0 < b_box.x0,
            .y => a_box.y0 < b_box.y0,
            .z => a_box.z0 < b_box.z0,
        };
    }

    pub fn swap(ctx: SortContext, a: usize, b: usize) void {
        return std.mem.swap(Hittable, &ctx.items[a], &ctx.items[b]);
    }
};

pub const Sphere = struct {
    center: Ray,
    radius: f32,
    material: Material,
    aabb: Aabb,

    pub fn init(center: Ray, radius: f32, material: Material) Sphere {
        const radius_vec = vec.splat(radius);
        const box1 = Aabb.init(center.atTime(0.0) - radius_vec, center.atTime(0.0) + radius_vec);
        const box2 = Aabb.init(center.atTime(1.0) - radius_vec, center.atTime(1.0) + radius_vec);
        const aabb = Aabb.combine(box1, box2);
        return .{
            .center = center,
            .radius = radius,
            .material = material,
            .aabb = aabb,
        };
    }

    pub fn hit(self: Sphere, ray: Ray, t_min: f32, t_max: f32) HitRecord {
        const center = self.center.atTime(ray.time);
        const oc = center - ray.origin;
        const a = vec.dot(ray.direction, ray.direction);
        const h = vec.dot(ray.direction, oc);
        const c = vec.dot(oc, oc) - self.radius * self.radius;

        const discriminant = h * h - a * c;
        if (discriminant < 0) {
            return .{ .is_hit = false };
        }

        const sqrtd = @sqrt(discriminant);
        var root = (h - sqrtd) / a;
        if (root < t_min or root > t_max) {
            root = (h + sqrtd) / a;
            if (root < t_min or root > t_max) {
                return .{ .is_hit = false };
            }
        }
        const outward_normal = vec.scale(ray.atTime(root) - center, 1 / self.radius);
        var record: HitRecord = .init(ray, root, outward_normal, self.material);
        setUv(outward_normal, &record);
        return record;
    }

    pub fn boundingBox(self: Sphere) Aabb {
        return self.aabb;
    }

    pub fn setUv(point: Point, record: *HitRecord) void {
        // point: a given point on the sphere of radius one, centered at the origin.
        // record.u: returned value [0,1] of angle around the Y axis from X=-1.
        // record.v: returned value [0,1] of angle from Y=-1 to Y=+1.
        //     <1 0 0> yields <0.50 0.50>       <-1  0  0> yields <0.00 0.50>
        //     <0 1 0> yields <0.50 1.00>       < 0 -1  0> yields <0.50 0.00>
        //     <0 0 1> yields <0.25 0.50>       < 0  0 -1> yields <0.75 0.50>
        const theta = std.math.acos(-point[1]);
        const phi = std.math.atan2(-point[2], point[0]) + std.math.pi;

        record.*.u = phi / (2 * std.math.pi);
        record.*.v = theta / std.math.pi;
    }
};
