import { describe, expect, it } from 'vitest';
import { MapManager } from '../src/maps/mapManager';
import { vpsToGLB } from '../src/navigation/positioning/vpsTransform';
import { ARCoreTrackingProvider } from '../src/navigation/positioning/ARCoreTrackingProvider';
import { PoseFusion } from '../src/navigation/positioning/PoseFusion';
import { NavigationEngine } from '../src/navigation/navigationEngine';
import { VPSPose } from '../src/vps/vpsTypes';

describe('PathLume End-to-End User Flow Architecture', () => {
    it('Phase 1 & 2: Parse QR code payload and initialize College Block A map configuration', () => {
        const mapManager = new MapManager();

        // Test JSON payload format
        const jsonPayload = mapManager.parseQRPayload(JSON.stringify({
            mapId: 'college_block_a',
            anchorId: 'entrance_01',
            floor: 1,
        }));

        expect(jsonPayload).not.toBeNull();
        expect(jsonPayload?.mapId).toBe('college_block_a');
        expect(jsonPayload?.anchorId).toBe('entrance_01');

        // Test URI deep link format (navcat://map/college_block_a/entrance_01 or pathlume://site/demo_site)
        const uriPayload = mapManager.parseQRPayload('navcat://map/college_block_a/entrance_01');
        expect(uriPayload).not.toBeNull();
        expect(uriPayload?.mapId).toBe('college_block_a');
        expect(uriPayload?.anchorId).toBe('entrance_01');

        if (jsonPayload) {
            const { config, graph } = mapManager.loadMapFromQR(jsonPayload);
            expect(config.mapId).toBe('college_block_a');
            expect(config.destinations.length).toBeGreaterThan(0);
            expect(graph.getAllNodes().length).toBeGreaterThan(0);
        }
    });

    it('Phase 4: Transform VPS pose into GLB building world coordinates', () => {
        const rawVPSPose: VPSPose = {
            position: { x: 10, y: 0, z: -5 },
            rotation: { x: 0, y: 0, z: 0, w: 1 },
            heading: 90,
            floor: 1,
            accuracy: 0.35,
            timestamp: Date.now(),
        };

        const transformConfig = {
            translation: { x: -2, y: -1.9, z: 2 },
            rotation: { x: 0, y: 0, z: 0 },
            scale: 1.0,
        };

        const glbPose = vpsToGLB(rawVPSPose, transformConfig);

        expect(glbPose.position.x).toBe(8.0);
        expect(glbPose.position.y).toBe(-1.9);
        expect(glbPose.position.z).toBe(-3.0);
        expect(glbPose.heading).toBe(90);
    });

    it('Phase 9 & 10: Fuse ARCore continuous motion tracking with low-frequency VPS pose corrections', () => {
        const arCore = new ARCoreTrackingProvider();
        const poseFusion = new PoseFusion(arCore);

        arCore.start();

        // 1. Initial VPS localization update
        const initialVPSPose: VPSPose = {
            position: { x: 0, y: 0, z: 7.0 },
            rotation: { x: 0, y: 0, z: 0, w: 1 },
            heading: 0,
            floor: 1,
            accuracy: 0.3,
            timestamp: Date.now(),
        };

        poseFusion.applyVPSCorrection(initialVPSPose, 'VPS_LOCALIZED');
        let currentPos = poseFusion.getCurrentPosition();

        expect(currentPos.position.x).toBe(0);
        expect(currentPos.position.z).toBe(7.0);

        // 2. High-frequency ARCore relative movement tracking
        arCore.updateRelativeMotion(1.0, 0, -2.0);
        currentPos = poseFusion.getCurrentPosition();

        expect(currentPos.position.x).toBe(1.0);
        expect(currentPos.position.z).toBe(5.0);

        // 3. Periodic VPS drift correction update (VPS reports 1.1, 0, 4.9)
        const laterVPSPose: VPSPose = {
            position: { x: 1.1, y: 0, z: 4.9 },
            rotation: { x: 0, y: 0, z: 0, w: 1 },
            heading: 0,
            floor: 1,
            accuracy: 0.25,
            timestamp: Date.now(),
        };

        poseFusion.applyVPSCorrection(laterVPSPose, 'VPS_LOCALIZED');
        const fusedPose = poseFusion.getFusedPose();

        expect(fusedPose.status).toBe('ACTIVE');
        expect(fusedPose.driftMeters).toBeGreaterThan(0);
    });

    it('Phase 7, 13 & 14: Calculate A* route from localized user position, detect off-route rerouting, and detect arrival', () => {
        const mapManager = new MapManager();
        const payload = mapManager.parseQRPayload('navcat://map/college_block_a/entrance_01')!;
        const { graph } = mapManager.loadMapFromQR(payload);

        const arCore = new ARCoreTrackingProvider();
        const poseFusion = new PoseFusion(arCore);
        const engine = new NavigationEngine(graph);

        engine.setPositionProvider(poseFusion);

        // Initialize user at Main Entrance (0, 0, 7.0)
        poseFusion.applyVPSCorrection({
            position: { x: 0, y: 0, z: 7.0 },
            rotation: { x: 0, y: 0, z: 0, w: 1 },
            heading: 0,
            floor: 1,
            accuracy: 0.3,
            timestamp: Date.now(),
        });

        // User selects Room 101 as destination
        engine.setDestinationNode('room_101');

        let state = engine.getState();
        expect(state.status).toBe('navigating');
        expect(state.route.length).toBeGreaterThan(1);
        expect(state.destinationNode?.id).toBe('room_101');

        // Simulate user walking off route by > 2 meters
        engine.updateUserPosition({
            position: { x: 15.0, y: 0, z: 15.0 },
            floor: 1,
            heading: 0,
            accuracy: 0.5,
        });

        state = engine.getState();
        expect(state.status).toBe('navigating'); // Auto-rerouted
        expect(state.route.length).toBeGreaterThan(0);

        // Simulate user reaching destination (Room 101 at -1.8, 0, 6.0)
        engine.updateUserPosition({
            position: { x: -1.8, y: 0, z: 6.0 },
            floor: 1,
            heading: 0,
            accuracy: 0.2,
        });

        state = engine.getState();
        expect(state.status).toBe('arrived');
        expect(state.distanceRemaining).toBe(0);
    });
});
