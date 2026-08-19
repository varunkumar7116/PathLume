export type VPSStatus = 
    | 'VPS_SEARCHING'
    | 'VPS_LOCALIZED'
    | 'VPS_LOW_CONFIDENCE'
    | 'VPS_LOST'
    | 'VPS_ERROR';

export interface Quaternion {
    x: number;
    y: number;
    z: number;
    w: number;
}

export interface Vector3D {
    x: number;
    y: number;
    z: number;
}

export interface VPSPose {
    position: Vector3D;
    rotation: Quaternion;
    heading: number; // degrees 0..360
    floor: number;
    accuracy: number; // meters
    timestamp: number;
}

export interface VPSTransformConfig {
    translation: Vector3D;
    rotation: Vector3D; // Euler angles in degrees or radians
    scale: number;
}

export interface VPSBackendResponse {
    localized: boolean;
    position?: Vector3D;
    rotation?: Quaternion;
    heading?: number;
    floor?: number;
    accuracy?: number;
    mapId?: string;
    message?: string;
}

export interface VPSSettings {
    serverUrl: string;
    frameRate: number; // default 5 FPS
    confidenceThreshold: number; // max accuracy in meters (e.g. 2.0)
    lostTimeoutMs: number; // duration before declaring VPS_LOST
}

export interface MapMetadata {
    mapId: string;
    mapName: string;
    glbUrl: string;
    floor: number;
    entryPoint: string;
    transformConfig: VPSTransformConfig;
}

export interface QRPayload {
    mapId: string;
    floor: number;
    entryPoint: string;
}
