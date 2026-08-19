import { describe, expect, it } from 'vitest';
import { SiteManager } from '../src/site/siteManager';
import { MapManager } from '../src/maps/mapManager';
import { ARCoreTrackingProvider } from '../src/navigation/positioning/ARCoreTrackingProvider';
import { PoseFusion } from '../src/navigation/positioning/PoseFusion';
import { NavigationEngine } from '../src/navigation/navigationEngine';
import { VPSPose } from '../src/vps/vpsTypes';
import { vpsToGLB } from '../src/navigation/positioning/vpsTransform';

describe('Universal Site & One-QR Architecture', () => {
    it('1. Should create sites with generic non-hardcoded type metadata', () => {
        const siteManager = new SiteManager();

        const hospitalSite = siteManager.createSite({
            name: 'St. Jude General Hospital',
            type: 'hospital',
            description: 'Main medical facility campus',
        });

        const mallSite = siteManager.createSite({
            name: 'Grand Galleria Mall',
            type: 'shopping_mall_custom',
            description: '3-story indoor shopping mall',
        });

        expect(hospitalSite.type).toBe('hospital');
        expect(mallSite.type).toBe('shopping_mall_custom');

        // Navigation engine and SiteManager treat all site types generically
        expect(siteManager.getSiteConfig(hospitalSite.siteId)).not.toBeNull();
        expect(siteManager.getSiteConfig(mallSite.siteId)).not.toBeNull();
    });

    it('2. Should support exactly ONE primary QR code per site with siteId payload', () => {
        const siteManager = new SiteManager();

        // 1. Canonical HTTP URL format
        const urlPayload = siteManager.parseQRPayload('https://pathlume.app/s/site_001');
        expect(urlPayload).not.toBeNull();
        expect(urlPayload?.siteId).toBe('site_001');

        // 2. Deep link URI format
        const uriPayload = siteManager.parseQRPayload('pathlume://site/site_001');
        expect(uriPayload).not.toBeNull();
        expect(uriPayload?.siteId).toBe('site_001');

        // 3. JSON format containing only siteId
        const jsonPayload = siteManager.parseQRPayload(JSON.stringify({ siteId: 'site_001' }));
        expect(jsonPayload).not.toBeNull();
        expect(jsonPayload?.siteId).toBe('site_001');

        // 4. Legacy format backward compatibility
        const legacyPayload = siteManager.parseQRPayload('navcat://map/college_block_a/entrance_01');
        expect(legacyPayload).not.toBeNull();
        expect(legacyPayload?.siteId).toBe('college_block_a');
    });

    it('3. Should support multi-building and multi-floor site configurations', () => {
        const siteManager = new SiteManager();
        const demoSite = siteManager.getSiteConfig('demo_site');

        expect(demoSite).not.toBeNull();
        expect(demoSite?.buildings.length).toBeGreaterThanOrEqual(2);

        const buildingA = demoSite?.buildings.find((b) => b.buildingId === 'building_a');
        const buildingB = demoSite?.buildings.find((b) => b.buildingId === 'building_b');

        expect(buildingA).toBeDefined();
        expect(buildingB).toBeDefined();
        expect(buildingA?.floors.length).toBe(2);

        // Check destinations belong to specific buildings and floors within the site
        const libraryDest = demoSite?.destinations.find((d) => d.id === 'library');
        const execRoomDest = demoSite?.destinations.find((d) => d.id === 'room_201');

        expect(libraryDest?.buildingId).toBe('building_a');
        expect(libraryDest?.floorId).toBe('floor_1');

        expect(execRoomDest?.buildingId).toBe('building_b');
        expect(execRoomDest?.floorId).toBe('floor_0');
    });

    it('4. End-to-End User Flow: Scan 1 Site QR -> VPS Pose in Site World -> A* Multi-Building AR Navigation', () => {
        const mapManager = new MapManager();
        const siteManager = mapManager.getSiteManager();

        // Step 1: User scans ONE primary site QR URL at site entrance
        const qrPayload = siteManager.parseQRPayload('https://pathlume.app/s/demo_site')!;
        expect(qrPayload).not.toBeNull();
        expect(qrPayload.siteId).toBe('demo_site');

        // Step 2: SiteManager loads complete site configuration and navigation graph
        const { config, graph } = siteManager.loadSiteFromQR(qrPayload);
        expect(config.name).toBe('Demo Indoor Site');
        expect(graph.getAllNodes().length).toBeGreaterThan(0);

        // Step 3: VPS localizes user's initial camera frame into canonical Site World coordinates
        const rawVPSPose: VPSPose = {
            position: { x: 0, y: 0, z: 7.0 },
            rotation: { x: 0, y: 0, z: 0, w: 1 },
            heading: 0,
            floor: 1,
            accuracy: 0.3,
            timestamp: Date.now(),
        };

        const siteWorldPose = vpsToGLB(rawVPSPose, config.coordinateSystem.transformConfig);

        const arCore = new ARCoreTrackingProvider();
        const poseFusion = new PoseFusion(arCore);
        arCore.start();

        // Apply VPS correction into PoseFusion
        poseFusion.applyVPSCorrection(siteWorldPose, 'VPS_LOCALIZED');
        const initialUserPos = poseFusion.getCurrentPosition();

        expect(initialUserPos.position.x).toBe(0);
        expect(initialUserPos.position.z).toBe(7.0);

        // Step 4: Initialize engine with user position and select destination
        const engine = new NavigationEngine(graph);
        engine.setPositionProvider(poseFusion);
        engine.updateUserPosition(initialUserPos);
        engine.setDestinationNode('room_101');

        let state = engine.getState();
        expect(state.status).toBe('navigating');
        expect(state.route.length).toBeGreaterThan(1);
        expect(state.destinationNode?.id).toBe('room_101');

        // Step 5: High-frequency ARCore motion tracking updates user position
        arCore.updateRelativeMotion(-1.8, 0, -1.0);

        // Step 6: User arrives at target destination (Room 101 at -1.8, 0, 6.0)
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
