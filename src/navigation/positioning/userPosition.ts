import { Vector3D } from '../graph/nodes';

export interface UserPositionState {
    position: Vector3D;
    floor: number;
    heading: number; // angle in degrees 0..360
    accuracy: number; // meters uncertainty
}

export const DEFAULT_USER_POSITION: UserPositionState = {
    position: { x: 0, y: 0, z: 8 },
    floor: 1,
    heading: 0,
    accuracy: 1.0,
};
