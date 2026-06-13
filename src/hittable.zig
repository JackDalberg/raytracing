const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Point = vec.Point;

const Ray = @import("Ray.zig");

const HitList = @import("HitList.zig");

const mat_zig = @import("material.zig");
const Material = mat_zig.Material;

pub const HitRecord = struct {
    is_hit: bool = false,
    front_face: bool = false,
    point: Point = undefined,
    normal: Vec3 = undefined,
    time: f64 = 0.0,
    material: Material = undefined,

    pub fn init(ray: Ray, time: f64, outward_normal: Vec3, material: Material) HitRecord {
        const front_face = (vec.dot(ray.direction, outward_normal) < 0);
        const point = ray.atTime(time);
        return .{
            .is_hit = true,
            .front_face = front_face,
            .point = point,
            .normal =  if (front_face) outward_normal else -outward_normal,
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

    const Self = @This();

    pub fn hit(self: Hittable, ray: Ray, t_min: f64, t_max: f64) HitRecord {
        return switch (self) {
            .sphere => |s| s.hit(ray, t_min, t_max),
            .hit_list => |hl| hl.hit(ray, t_min, t_max),
        };
    }
};

pub const Sphere = struct {
    center: Point,
    radius: f64,
    material: Material,

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
        if (root < t_min or root > t_max) {
            root = (h + sqrtd) / a;
            if (root < t_min or root > t_max) {
                return .{ .is_hit = false };
            }
        }
        const outward_normal = vec.scale(ray.atTime(root) - self.center, 1 / self.radius);
        return .init(ray, root, outward_normal, self.material);
    }
};
