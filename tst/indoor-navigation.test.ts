import { describe, expect, it } from 'vitest';
import {
    NavigationGraph,
    findAStarPath,
    distance3D,
    distanceFromRoute,
    checkOffRoute,
    checkArrival,
    MockPositionProvider,
    NavigationEngine,
    SAMPLE_NODES,
    SAMPLE_EDGES,
} from '../src/navigation';

describe('Indoor Navigation System', () => {
    it('should build graph and find neighbors correctly', () => {
        const graph = new NavigationGraph(SAMPLE_NODES, SAMPLE_EDGES);
        const entrance = graph.getNode('entrance_main');
        expect(entrance).toBeDefined();
        expect(entrance?.name).toBe('Main Entrance');

        const neighbors = graph.getNeighbors('entrance_main');
        expect(neighbors.length).toBeGreaterThan(0);
        expect(neighbors[0].node.id).toBe('lobby_center');
    });

    it('should find valid A* path from Main Entrance to Room 101', () => {
        const graph = new NavigationGraph(SAMPLE_NODES, SAMPLE_EDGES);
        const result = findAStarPath(graph, 'entrance_main', 'room_101');

        expect(result.success).toBe(true);
        expect(result.path.length).toBeGreaterThan(1);
        expect(result.path[0].id).toBe('entrance_main');
        expect(result.path[result.path.length - 1].id).toBe('room_101');
        expect(result.totalDistance).toBeGreaterThan(0);
    });

    it('should calculate 3D Euclidean distance correctly', () => {
        const p1 = { x: 0, y: 0, z: 0 };
        const p2 = { x: 3, y: 4, z: 0 };
        expect(distance3D(p1, p2)).toBe(5);
    });

    it('should detect off-route displacement', () => {
        const graph = new NavigationGraph(SAMPLE_NODES, SAMPLE_EDGES);
        const result = findAStarPath(graph, 'entrance_main', 'room_101');
        expect(result.success).toBe(true);

        const onRoutePoint = { x: 0, y: 0, z: 6 };
        expect(checkOffRoute(onRoutePoint, result.path, 2.5)).toBe(false);

        const farOffRoutePoint = { x: 20, y: 0, z: 6 };
        expect(checkOffRoute(farOffRoutePoint, result.path, 2.5)).toBe(true);
    });

    it('should detect arrival at destination within threshold', () => {
        const destPos = { x: -8, y: 0, z: 8 };
        const closeUser = { x: -8.5, y: 0, z: 8.2 };
        const farUser = { x: 0, y: 0, z: 0 };

        expect(checkArrival(closeUser, destPos, 1.5)).toBe(true);
        expect(checkArrival(farUser, destPos, 1.5)).toBe(false);
    });

    it('should update MockPositionProvider along route', () => {
        const mock = new MockPositionProvider();
        const graph = new NavigationGraph(SAMPLE_NODES, SAMPLE_EDGES);
        const result = findAStarPath(graph, 'entrance_main', 'room_101');

        mock.setRoute(result.path);
        const pos = mock.getCurrentPosition();
        expect(pos.position.x).toBe(result.path[0].position.x);
        expect(pos.position.z).toBe(result.path[0].position.z);
    });

    it('should orchestrate state changes through NavigationEngine', () => {
        const graph = new NavigationGraph(SAMPLE_NODES, SAMPLE_EDGES);
        const engine = new NavigationEngine(graph);
        const mock = new MockPositionProvider();

        engine.setPositionProvider(mock);
        engine.setStartNode('entrance_main');
        engine.setDestinationNode('room_101');

        const state = engine.getState();
        expect(state.status).toBe('navigating');
        expect(state.route.length).toBeGreaterThan(0);
        expect(state.destinationNode?.id).toBe('room_101');
    });
});
