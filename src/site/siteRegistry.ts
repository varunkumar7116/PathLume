import { SiteConfig } from './siteTypes';
import { SAMPLE_NODES } from '../navigation/graph/nodes';
import { SAMPLE_EDGES } from '../navigation/graph/edges';

export const DEFAULT_SITE_REGISTRY: Record<string, SiteConfig> = {
    demo_site: {
        siteId: 'demo_site',
        name: 'Demo Indoor Site',
        type: 'demo',
        description: 'Universal indoor navigation demo with multi-building & multi-floor support',
        status: 'active',
        version: 1,
        qrUrl: 'https://pathlume.app/s/demo_site',
        buildings: [
            {
                buildingId: 'building_a',
                name: 'Building A (Main Hub)',
                floors: [
                    {
                        floorId: 'floor_0',
                        name: 'Ground Floor',
                        floorNumber: 0,
                        modelUrl: '/sample.glb',
                    },
                    {
                        floorId: 'floor_1',
                        name: 'First Floor',
                        floorNumber: 1,
                        modelUrl: '/sample.glb',
                    },
                ],
            },
            {
                buildingId: 'building_b',
                name: 'Building B (Annex)',
                floors: [
                    {
                        floorId: 'floor_0',
                        name: 'Ground Floor',
                        floorNumber: 0,
                        modelUrl: '/sample.glb',
                    },
                ],
            },
        ],
        destinations: [
            {
                id: 'reception',
                name: 'Reception',
                type: 'Reception',
                buildingId: 'building_a',
                floorId: 'floor_0',
                position: { x: 0, y: 0, z: 3.5 },
                navigationNodeId: 'lobby_center',
            },
            {
                id: 'room_101',
                name: 'Room 101',
                type: 'Room',
                buildingId: 'building_a',
                floorId: 'floor_0',
                position: { x: -1.8, y: 0, z: 6.0 },
                navigationNodeId: 'room_101',
            },
            {
                id: 'room_102',
                name: 'Room 102',
                type: 'Room',
                buildingId: 'building_a',
                floorId: 'floor_0',
                position: { x: -1.8, y: 0, z: -1.0 },
                navigationNodeId: 'room_102',
            },
            {
                id: 'library',
                name: 'Library',
                type: 'Library',
                buildingId: 'building_a',
                floorId: 'floor_1',
                position: { x: 1.8, y: 0, z: -1.0 },
                navigationNodeId: 'room_104',
            },
            {
                id: 'room_201',
                name: 'Room 201 (Executive)',
                type: 'Office',
                buildingId: 'building_b',
                floorId: 'floor_0',
                position: { x: 1.8, y: 0, z: 6.0 },
                navigationNodeId: 'room_103',
            },
            {
                id: 'cafeteria',
                name: 'Cafeteria',
                type: 'Cafeteria',
                buildingId: 'building_b',
                floorId: 'floor_0',
                position: { x: 0, y: 0, z: -7.0 },
                navigationNodeId: 'room_105',
            },
        ],
        navigationGraph: {
            nodes: SAMPLE_NODES,
            edges: SAMPLE_EDGES,
        },
        vps: {
            siteId: 'demo_site',
            provider: 'mock',
            vpsMapId: 'vps_demo_site',
            transformConfig: {
                translation: { x: 0, y: -1.9, z: 0 },
                rotation: { x: 0, y: 0, z: 0 },
                scale: 1.0,
            },
        },
        coordinateSystem: {
            canonicalUnit: 'meters',
            transformConfig: {
                translation: { x: 0, y: -1.9, z: 0 },
                rotation: { x: 0, y: 0, z: 0 },
                scale: 1.0,
            },
        },
    },
};
