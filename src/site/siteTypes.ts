import { NavNode, Vector3D } from '../navigation/graph/nodes';
import { NavEdge } from '../navigation/graph/edges';
import { VPSTransformConfig } from '../vps/vpsTypes';

export interface SiteQRPayload {
    siteId: string;
}

export interface SiteFloor {
    floorId: string;
    name: string;
    floorNumber: number;
    modelUrl: string;
}

export interface SiteBuilding {
    buildingId: string;
    name: string;
    floors: SiteFloor[];
}

export interface SiteDestination {
    id: string;
    name: string;
    type?: string;
    buildingId?: string;
    floorId?: string | number;
    position: Vector3D;
    navigationNodeId: string;
}

export interface SiteVPSConfig {
    siteId: string;
    provider: string; // e.g. 'mock', 'arcore', 'custom'
    vpsMapId: string;
    transformConfig: VPSTransformConfig;
}

export interface SiteCoordinateSystem {
    canonicalUnit: 'meters';
    transformConfig: VPSTransformConfig;
}

export interface SiteConfig {
    siteId: string;
    name: string;
    type: string; // Freeform metadata: 'campus', 'hospital', 'mall', 'airport', 'office', 'hotel', 'warehouse', 'other', etc.
    description?: string;
    status: 'active' | 'draft' | 'archived';
    version: number;
    qrUrl: string; // Canonical URL: https://pathlume.app/s/{siteId}
    buildings: SiteBuilding[];
    destinations: SiteDestination[];
    navigationGraph?: {
        nodes: NavNode[];
        edges: NavEdge[];
    };
    vps: SiteVPSConfig;
    coordinateSystem: SiteCoordinateSystem;
}
