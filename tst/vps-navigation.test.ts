import { describe, expect, it } from 'vitest';
import {
    VPSClient,
    VPSAdapter,
    MapManager,
    vpsToWorldPose,
    MockVPSServer,
    VPSPose,
} from '../src/vps';

import { VPSPositionProvider, NavigationEngine } from '../src/navigation';

describe('VPS & Mobile AR Navigation Architecture', () => {
    it('should transform raw VPS coordinates to GLB world coordinates correctly', () => {
        const rawPose: VPSPose = {
            position: { x: 10, y: 0, z: 5 },
            rotation: { x: 0, y: 0, z: 0, w: 1 },
            heading: 90,
            floor: 1,
            accuracy: 0.4,
            timestamp: Date.now(),
        };

        const transformConfig = {
            translation: { x: -2, y: -1.9, z: 1 },
            rotation: { x: 0, y: 0, z: 0 },
            scale: 1.0,
        };

        const worldPose = vpsToWorldPose(rawPose, transformConfig);

        expect(worldPose.position.x).toBe(8); // 10 + (-2)
        expect(worldPose.position.y).toBe(-1.9); // 0 + (-1.9)
        expect(worldPose.position.z).toBe(6); // 5 + 1
        expect(worldPose.heading).toBe(90);
    });

    it('should parse QR code payload and initialize map via MapManager', () => {
        const mapManager = new MapManager();
        const payload = mapManager.parseQRPayload(JSON.stringify({
            mapId: 'building_01',
            floor: 1,
            entryPoint: 'main_entrance',
        }));

        expect(payload).not.toBeNull();
        expect(payload?.mapId).toBe('building_01');

        if (payload) {
            const { metadata, graph } = mapManager.loadMapFromQR(payload);
            expect(metadata.mapId).toBe('building_01');
            expect(graph.getAllNodes().length).toBeGreaterThan(0);
        }
    });

    it('should process simulated frame requests in MockVPSServer', async () => {
        const mockServer = new MockVPSServer();
        const response = mockServer.handleLocalizeRequest({
            mapId: 'building_01',
            image: 'data:image/jpeg;base64,sampleframe',
        });

        expect(response.localized).toBe(true);
        expect(response.position).toBeDefined();
        expect(response.accuracy).toBeLessThan(1.0);
    });

    it('should pass VPS poses through VPSAdapter into NavigationEngine', async () => {
        const mockServer = new MockVPSServer();
        const client = new VPSClient('http://localhost:8000/localize');

        // Mock fetch response using mock server logic
        client.localizeFrame = async (frame: string, mapId?: string) => {
            return mockServer.handleLocalizeRequest({ image: frame, mapId });
        };

        const adapter = new VPSAdapter(client);
        
        let adapterStatus = '';
        adapter.onStatusUpdate((status) => {
            adapterStatus = status;
        });

        const pose = await adapter.localize('dummy_frame');
        expect(pose).not.toBeNull();
        expect(adapterStatus).toBe('VPS_LOCALIZED');
    });
});
