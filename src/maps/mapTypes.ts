import { Vector3D } from '../navigation/graph/nodes';
import { VPSTransformConfig } from '../vps/vpsTypes';

export interface QRPayload {
    mapId: string;
    anchorId: string;
    floor: number;
}

export interface BuildingAnchor {
    id: string;
    name: string;
    floor: number;
    position: Vector3D;
}

export interface MapDestination {
    id: string;
    name: string;
    type?: string;
    floor: number;
    position: Vector3D;
    navigationNodeId: string;
}

export interface MapConfig {
    mapId: string;
    name: string;
    model: string;
    floor: number;
    vpsMapId: string;
    anchors: Record<string, BuildingAnchor>;
    destinations: MapDestination[];
    transformConfig: VPSTransformConfig;
}
