const vec = @import("vec.zig");

const Ray = @import("Ray.zig");

const HitList = @import("HitList.zig");

pub const HitRecord = struct {
    is_hit: bool = false,
    front_face: bool = false,
    point: vec.Point = undefined,
    normal: vec.Vec3 = undefined,
    time: f64 = 0.0,

    // Assumes outward_normal is of unit length.
    pub fn setFaceNormal(self: *HitRecord, ray: Ray, outward_normal: vec.Vec3) void {
        self.front_face = (vec.dot(ray.direction, outward_normal) < 0);
        self.normal = outward_normal;
        if (!self.front_face) {
            self.normal = -outward_normal;
        }
    }
};

pub const Hittable = union(enum) {
    // Basic types.
    sphere: Sphere,

    // Aggregate types.
    hit_list: HitList,

    const Self = @This();

    pub fn hit(self: Hittable, ray: Ray, t_min: f64, t_max: f64) HitRecord {
        return switch (self) {
            .sphere => |s| s.hit(ray, t_min, t_max),
            .hit_list => |hl| hl.hit(ray, t_min, t_max),
        };
    }
};

pub const Sphere = struct {
    center: vec.Point,
    radius: f64,

    pub fn hit(self: Sphere, ray: Ray, t_min: f64, t_max: f64) HitRecord {
        const oc = self.center - ray.origin;
        const a = vec.dot(ray.direction, ray.direction);
        const h = vec.dot(ray.direction, oc);
        const c = vec.dot(oc, oc) - self.radius * self.radius;

        const discriminant = h * h - a * c;
        if (discriminant < 0) {
            return .{ .is_hit = false };
        }

        const sqrtd = @sqrt(discriminant);
        var root = (h - sqrtd) / a;
        if (root <= t_min or root >= t_max) {
            root = (h + sqrtd) / a;
            if (root <= t_min or root >= t_max) {
                return .{ .is_hit = false };
            }
        }
        var hr: HitRecord = .{
            .is_hit = true,
            .point = ray.atTime(root),
            .time = root,
        };
        const outward_normal = vec.scale(ray.atTime(root) - self.center, 1 / self.radius);
        hr.setFaceNormal(ray, outward_normal);
        return hr;
    }
};
