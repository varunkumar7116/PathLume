export interface NavEdge {
    from: string;
    to: string;
    distance?: number;
    walkable: boolean;
    bidirectional?: boolean;
}

/**
 * Initial walkable navigation edges connecting SAMPLE_NODES.
 */
export const SAMPLE_EDGES: NavEdge[] = [
    // Entrance to lobby
    { from: 'entrance_main', to: 'lobby_center', walkable: true, bidirectional: true },

    // Lobby to West corridor & East corridor & North junction
    { from: 'lobby_center', to: 'corridor_west_01', walkable: true, bidirectional: true },
    { from: 'lobby_center', to: 'corridor_east_01', walkable: true, bidirectional: true },
    { from: 'lobby_center', to: 'junction_north', walkable: true, bidirectional: true },

    // West Wing
    { from: 'corridor_west_01', to: 'corridor_west_02', walkable: true, bidirectional: true },
    { from: 'corridor_west_02', to: 'room_101', walkable: true, bidirectional: true },
    { from: 'corridor_west_02', to: 'room_102', walkable: true, bidirectional: true },

    // East Wing
    { from: 'corridor_east_01', to: 'corridor_east_02', walkable: true, bidirectional: true },
    { from: 'corridor_east_02', to: 'room_103', walkable: true, bidirectional: true },
    { from: 'corridor_east_02', to: 'room_104', walkable: true, bidirectional: true },

    // North Wing & Services
    { from: 'junction_north', to: 'stairs_floor1', walkable: true, bidirectional: true },
    { from: 'junction_north', to: 'elevator_floor1', walkable: true, bidirectional: true },
    { from: 'junction_north', to: 'corridor_north_01', walkable: true, bidirectional: true },
    { from: 'corridor_north_01', to: 'room_105', walkable: true, bidirectional: true },
];
