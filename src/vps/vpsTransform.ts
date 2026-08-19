import { VPSPose, VPSTransformConfig } from './vpsTypes';

export const DEFAULT_TRANSFORM_CONFIG: VPSTransformConfig = {
    translation: { x: 0, y: 0, z: 0 },
    rotation: { x: 0, y: 0, z: 0 }, // Euler angles in degrees
    scale: 1.0,
};

/**
 * Converts raw VPS coordinates into GLB World Coordinates.
 * Applies scale, rotation, and translation offsets.
 */
export function vpsToWorldPose(
    rawPose: VPSPose,
    transformConfig: VPSTransformConfig = DEFAULT_TRANSFORM_CONFIG
): VPSPose {
    const { translation, rotation, scale } = transformConfig;

    // 1. Apply scale
    let x = rawPose.position.x * scale;
    let y = rawPose.position.y * scale;
    let z = rawPose.position.z * scale;

    // 2. Apply Euler rotation (around Y axis in degrees)
    if (rotation.y !== 0) {
        const radY = (rotation.y * Math.PI) / 180;
        const cosY = Math.cos(radY);
        const sinY = Math.sin(radY);
        const rx = x * cosY - z * sinY;
        const rz = x * sinY + z * cosY;
        x = rx;
        z = rz;
    }

    // 3. Apply Translation offset
    x += translation.x;
    y += translation.y;
    z += translation.z;

    // 4. Adjust heading with Y rotation offset
    let heading = (rawPose.heading + rotation.y) % 360;
    if (heading < 0) heading += 360;

    return {
        ...rawPose,
        position: { x, y, z },
        heading,
    };
}

/** Alias for phase 4 explicit requirement */
export const vpsToGLB = vpsToWorldPose;
