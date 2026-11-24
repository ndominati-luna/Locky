import SwiftUI

/// The camera that sees a Mac on its desk, as its picture shows it: face on, from a little above,
/// far enough for the device to look flat, close enough for the desk in front of it to recede. What
/// lies on the desk (a keyboard, a trackpad) is drawn from above and laid down on it; what turns on
/// a hinge (the display of an iMac) turns toward or away from it. Measures in centimetres; the
/// picture sets the scale, the middle and the desk.
struct DeskCamera {
    /// Points per centimetre, at the front of the device.
    let scale: CGFloat
    /// The middle of the device, in points from the left.
    let center: CGFloat
    /// The desk under the front of the device, in points from the top.
    let desk: CGFloat
    /// From the front of the device to the camera, and the camera above the desk.
    var distance: CGFloat = 160
    var eyeHeight: CGFloat = 27

    /// The line of the eye, which the desk recedes toward, in points from the top.
    private var horizon: CGFloat {
        desk - scale * eyeHeight
    }

    /// How much bigger than at the front of the device something `depth` centimetres closer looks.
    func magnification(atDepth depth: CGFloat) -> CGFloat {
        distance / (distance - depth)
    }

    /// Where the camera sees a point `x` centimetres right of the middle, `height` above the desk
    /// and `depth` in front of the device.
    func point(x: CGFloat, height: CGFloat, depth: CGFloat) -> CGPoint {
        let magnification: CGFloat = magnification(atDepth: depth)
        return .init(x: center + scale * x * magnification, y: horizon + scale * (eyeHeight - height) * magnification)
    }

    /// Lays a drawing of `size` points, seen from above, on a flat face of something on the desk:
    /// `width` centimetres wide from `left` right of the middle, `depth` deep from `back` in front of
    /// the device, its back edge `backHeight` above the desk and its front edge `frontHeight` (the top
    /// of a keyboard slopes down toward the hands). The drawing must be laid out at the origin of the
    /// space the camera measures.
    func surface(
        size: CGSize,
        left: CGFloat,
        width: CGFloat,
        back: CGFloat,
        depth: CGFloat,
        backHeight: CGFloat,
        frontHeight: CGFloat
    ) -> ProjectionTransform {
        // A point of the drawing, `u` across and `v` down, is `left + u·width/W` right of the middle,
        // `back + v·depth/H` in front, `backHeight + v·(frontHeight - backHeight)/H` high: everything
        // is linear in `u` and `v`, the perspective divides by the distance to the camera.
        let closer: CGFloat = depth / max(size.height, 1)
        let lower: CGFloat = (frontHeight - backHeight) / max(size.height, 1)
        var transform: ProjectionTransform = .init()
        transform.m13 = 0
        transform.m23 = -closer / distance
        transform.m33 = (distance - back) / distance
        transform.m11 = scale * width / max(size.width, 1)
        transform.m21 = center * transform.m23
        transform.m31 = center * transform.m33 + scale * left
        transform.m12 = 0
        transform.m22 = horizon * transform.m23 - scale * lower
        transform.m32 = horizon * transform.m33 + scale * (eyeHeight - backHeight)
        return transform
    }

    /// Tilts the front of the device, drawn face on where the camera sees it, back by `angle` (its
    /// top away from the camera, forward if negative), around a hinge `axisHeight` centimetres above
    /// the desk and `axisDepth` behind the front. The drawing must be laid out at the origin of the
    /// space the camera measures.
    func tilt(_ angle: Angle, axisHeight: CGFloat, axisDepth: CGFloat) -> ProjectionTransform {
        // A point of the front, `r` above the hinge and `axisDepth` in front of it, turns to
        // `r·cos + axisDepth·sin` above it and `-r·sin - axisDepth·(1 - cos)` in front of the device;
        // `r` is linear in `v`, the height of the point in the drawing.
        let sine: CGFloat = CGFloat(sin(angle.radians))
        let cosine: CGFloat = CGFloat(cos(angle.radians))
        let hingeFromTop: CGFloat = desk / scale - axisHeight
        let farther: CGFloat = -sine / (distance * scale)
        let farthest: CGFloat = 1 + (sine * hingeFromTop + axisDepth * (1 - cosine)) / distance
        var transform: ProjectionTransform = .init()
        transform.m11 = 1
        transform.m12 = 0
        transform.m13 = 0
        transform.m21 = center * farther
        transform.m22 = horizon * farther + cosine
        transform.m23 = farther
        transform.m31 = center * (farthest - 1)
        transform.m32 = horizon * farthest + scale * (eyeHeight - axisHeight - axisDepth * sine - cosine * hingeFromTop)
        transform.m33 = farthest
        return transform
    }
}
