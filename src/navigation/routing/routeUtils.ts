import { NavNode, Vector3D } from '../graph/nodes';

export function distance3D(p1: Vector3D, p2: Vector3D): number {
    return Math.hypot(p1.x - p2.x, p1.y - p2.y, p1.z - p2.z);
}

/**
 * Calculates the shortest distance from point P to line segment AB in 3D.
 */
export function distanceToSegment(p: Vector3D, a: Vector3D, b: Vector3D): number {
    const abx = b.x - a.x;
    const aby = b.y - a.y;
    const abz = b.z - a.z;

    const apx = p.x - a.x;
    const apy = p.y - a.y;
    const apz = p.z - a.z;

    const abSquare = abx * abx + aby * aby + abz * abz;
    if (abSquare === 0) {
        return distance3D(p, a);
    }

    // Projection factor t
    let t = (apx * abx + apy * aby + apz * abz) / abSquare;
    t = Math.max(0, Math.min(1, t));

    const projX = a.x + t * abx;
    const projY = a.y + t * aby;
    const projZ = a.z + t * abz;

    return distance3D(p, { x: projX, y: projY, z: projZ });
}

/**
 * Calculates the minimum distance from user position to a route formed by connected nodes.
 */
export function distanceFromRoute(userPos: Vector3D, route: NavNode[]): number {
    if (!route || route.length === 0) return Infinity;
    if (route.length === 1) return distance3D(userPos, route[0].position);

    let minDistance = Infinity;
    for (let i = 0; i < route.length - 1; i++) {
        const segDist = distanceToSegment(userPos, route[i].position, route[i + 1].position);
        if (segDist < minDistance) {
            minDistance = segDist;
        }
    }
    return minDistance;
}

/**
 * Calculates remaining route distance from user's current position to destination.
 */
export function calculateDistanceRemaining(userPos: Vector3D, route: NavNode[]): number {
    if (!route || route.length === 0) return 0;
    if (route.length === 1) return distance3D(userPos, route[0].position);

    // Find nearest line segment on route
    let minSegmentIndex = 0;
    let minDist = Infinity;
    let closestProjT = 0;

    for (let i = 0; i < route.length - 1; i++) {
        const a = route[i].position;
        const b = route[i + 1].position;
        const abx = b.x - a.x, aby = b.y - a.y, abz = b.z - a.z;
        const abSquare = abx * abx + aby * aby + abz * abz;
        if (abSquare === 0) continue;

        let t = ((userPos.x - a.x) * abx + (userPos.y - a.y) * aby + (userPos.z - a.z) * abz) / abSquare;
        t = Math.max(0, Math.min(1, t));

        const dist = distance3D(userPos, { x: a.x + t * abx, y: a.y + t * aby, z: a.z + t * abz });
        if (dist < minDist) {
            minDist = dist;
            minSegmentIndex = i;
            closestProjT = t;
        }
    }

    // Distance on current segment from projected point to segment end
    const segStart = route[minSegmentIndex].position;
    const segEnd = route[minSegmentIndex + 1].position;
    const segLength = distance3D(segStart, segEnd);
    let remaining = (1 - closestProjT) * segLength;

    // Add remaining full segments
    for (let i = minSegmentIndex + 1; i < route.length - 1; i++) {
        remaining += distance3D(route[i].position, route[i + 1].position);
    }

    return remaining;
}

/**
 * Checks if the user is off-route beyond threshold (default 2.5 meters).
 */
export function checkOffRoute(userPos: Vector3D, route: NavNode[], thresholdMeters = 2.5): boolean {
    const dist = distanceFromRoute(userPos, route);
    return dist > thresholdMeters;
}

/**
 * Checks if the user has arrived within destination threshold (default 1.5 meters).
 */
export function checkArrival(userPos: Vector3D, destPos: Vector3D, thresholdMeters = 1.5): boolean {
    return distance3D(userPos, destPos) <= thresholdMeters;
}
