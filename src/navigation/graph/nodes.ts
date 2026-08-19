export interface Vector3D {
    x: number;
    y: number;
    z: number;
}

export type NodeType = 
    | 'entrance'
    | 'corridor'
    | 'intersection'
    | 'stairs'
    | 'elevator'
    | 'room';

export interface NavNode {
    id: string;
    position: Vector3D;
    floor: number;
    type: NodeType;
    name: string;
}

/**
 * Initial manually created walkable navigation graph nodes for sample.glb and sample1.glb.
 * Coordinates are mapped to fit within building floor dimensions.
 */
export const SAMPLE_NODES: NavNode[] = [
    {
        id: 'entrance_main',
        name: 'Main Entrance',
        type: 'entrance',
        floor: 1,
        position: { x: 0, y: 0, z: 7.0 },
    },
    {
        id: 'lobby_center',
        name: 'Lobby Central Hub',
        type: 'intersection',
        floor: 1,
        position: { x: 0, y: 0, z: 3.5 },
    },
    {
        id: 'corridor_west_01',
        name: 'West Corridor 1',
        type: 'corridor',
        floor: 1,
        position: { x: -1.2, y: 0, z: 3.5 },
    },
    {
        id: 'corridor_west_02',
        name: 'West Corridor 2',
        type: 'corridor',
        floor: 1,
        position: { x: -1.8, y: 0, z: 1.5 },
    },
    {
        id: 'room_101',
        name: 'Room 101 (Conference A)',
        type: 'room',
        floor: 1,
        position: { x: -1.8, y: 0, z: 6.0 },
    },
    {
        id: 'room_102',
        name: 'Room 102 (Lab)',
        type: 'room',
        floor: 1,
        position: { x: -1.8, y: 0, z: -1.0 },
    },
    {
        id: 'corridor_east_01',
        name: 'East Corridor 1',
        type: 'corridor',
        floor: 1,
        position: { x: 1.2, y: 0, z: 3.5 },
    },
    {
        id: 'corridor_east_02',
        name: 'East Corridor 2',
        type: 'corridor',
        floor: 1,
        position: { x: 1.8, y: 0, z: 1.5 },
    },
    {
        id: 'room_103',
        name: 'Room 103 (Office B)',
        type: 'room',
        floor: 1,
        position: { x: 1.8, y: 0, z: 6.0 },
    },
    {
        id: 'room_104',
        name: 'Room 104 (Auditorium)',
        type: 'room',
        floor: 1,
        position: { x: 1.8, y: 0, z: -1.0 },
    },
    {
        id: 'junction_north',
        name: 'North Junction',
        type: 'intersection',
        floor: 1,
        position: { x: 0, y: 0, z: -2.0 },
    },
    {
        id: 'stairs_floor1',
        name: 'Stairwell Floor 1',
        type: 'stairs',
        floor: 1,
        position: { x: -1.2, y: 0, z: -3.5 },
    },
    {
        id: 'elevator_floor1',
        name: 'Elevator Floor 1',
        type: 'elevator',
        floor: 1,
        position: { x: 1.2, y: 0, z: -3.5 },
    },
    {
        id: 'corridor_north_01',
        name: 'North Corridor',
        type: 'corridor',
        floor: 1,
        position: { x: 0, y: 0, z: -5.0 },
    },
    {
        id: 'room_105',
        name: 'Room 105 (Cafeteria)',
        type: 'room',
        floor: 1,
        position: { x: 0, y: 0, z: -7.0 },
    },
];
