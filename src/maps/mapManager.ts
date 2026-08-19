import { MapConfig, QRPayload } from './mapTypes';
import { DEFAULT_MAP_REGISTRY } from './mapRegistry';
import { SiteManager } from '../site/siteManager';
import { NavigationGraph } from '../navigation/graph/navigationGraph';
import { SAMPLE_NODES } from '../navigation/graph/nodes';
import { SAMPLE_EDGES } from '../navigation/graph/edges';

export class MapManager {
    private mapsRegistry: Map<string, MapConfig> = new Map();
    private activeMap: MapConfig | null = null;
    private siteManager: SiteManager;

    constructor() {
        this.siteManager = new SiteManager();

        // Populate default map registry for legacy compatibility
        for (const [key, config] of Object.entries(DEFAULT_MAP_REGISTRY)) {
            this.mapsRegistry.set(key, config);
        }
    }

    public getSiteManager(): SiteManager {
        return this.siteManager;
    }

    public registerMap(config: MapConfig): void {
        this.mapsRegistry.set(config.mapId, config);
    }

    public getMapConfig(mapId: string): MapConfig | null {
        // Try local map registry first, then fallback to siteManager
        if (this.mapsRegistry.has(mapId)) {
            return this.mapsRegistry.get(mapId) || null;
        }

        const siteConfig = this.siteManager.getSiteConfig(mapId);
        if (siteConfig) {
            return {
                mapId: siteConfig.siteId,
                name: siteConfig.name,
                model: siteConfig.buildings[0]?.floors[0]?.modelUrl || '/sample.glb',
                floor: siteConfig.buildings[0]?.floors[0]?.floorNumber ?? 1,
                vpsMapId: siteConfig.vps.vpsMapId,
                anchors: {
                    entrance_01: {
                        id: 'entrance_01',
                        name: 'Main Entrance',
                        floor: 1,
                        position: { x: 0, y: 0, z: 7.0 },
                    },
                },
                destinations: siteConfig.destinations.map((d) => ({
                    id: d.id,
                    name: d.name,
                    type: d.type,
                    floor: typeof d.floorId === 'number' ? d.floorId : 1,
                    position: d.position,
                    navigationNodeId: d.navigationNodeId,
                })),
                transformConfig: siteConfig.coordinateSystem.transformConfig,
            };
        }

        return null;
    }

    /**
     * Parse QR code input string or object.
     * Supports both Universal Site single QR payloads and legacy QR payloads.
     */
    public parseQRPayload(qrData: string | object): QRPayload | null {
        if (!qrData) return null;

        // Try SiteManager parsing first
        const sitePayload = this.siteManager.parseQRPayload(qrData);
        if (sitePayload) {
            let anchorId = 'entrance_01';
            let floor = 1;

            if (typeof qrData === 'object') {
                const obj = qrData as any;
                if (obj.anchorId || obj.entryPoint) anchorId = obj.anchorId || obj.entryPoint;
                if (typeof obj.floor === 'number') floor = obj.floor;
            } else if (typeof qrData === 'string' && qrData.includes('/map/')) {
                const parts = qrData.split('/map/')[1]?.split('/') || [];
                if (parts[1]) anchorId = parts[1];
            }

            return {
                mapId: sitePayload.siteId,
                anchorId,
                floor,
            };
        }

        return null;
    }

    public validateMapId(mapId: string): boolean {
        return this.mapsRegistry.has(mapId) || Boolean(this.siteManager.getSiteConfig(mapId));
    }

    public validateAnchorId(mapId: string, anchorId: string): boolean {
        const config = this.getMapConfig(mapId);
        if (!config) return false;
        if (config.anchors && config.anchors[anchorId]) return true;
        return true; // Dynamic anchor acceptance for universal site mode
    }

    public loadMapFromQR(qrPayload: QRPayload): {
        config: MapConfig;
        graph: NavigationGraph;
    } {
        let config = this.getMapConfig(qrPayload.mapId);

        if (!config) {
            config = {
                mapId: qrPayload.mapId,
                name: `Site ${qrPayload.mapId}`,
                model: '/sample.glb',
                floor: qrPayload.floor || 1,
                vpsMapId: qrPayload.mapId,
                anchors: {
                    [qrPayload.anchorId]: {
                        id: qrPayload.anchorId,
                        name: 'Main Entrance',
                        floor: qrPayload.floor || 1,
                        position: { x: 0, y: 0, z: 7.0 },
                    },
                },
                destinations: [],
                transformConfig: {
                    translation: { x: 0, y: -1.9, z: 0 },
                    rotation: { x: 0, y: 0, z: 0 },
                    scale: 1.0,
                },
            };
            this.registerMap(config);
        }

        this.activeMap = config;

        // Try getting graph from SiteManager
        const siteConfig = this.siteManager.getSiteConfig(qrPayload.mapId);
        let graph: NavigationGraph;

        if (siteConfig?.navigationGraph) {
            graph = new NavigationGraph(siteConfig.navigationGraph.nodes, siteConfig.navigationGraph.edges);
        } else {
            graph = new NavigationGraph(SAMPLE_NODES, SAMPLE_EDGES);
        }

        return { config, graph };
    }

    public getActiveMap(): MapConfig | null {
        return this.activeMap;
    }

    public getAllRegisteredMaps(): MapConfig[] {
        return Array.from(this.mapsRegistry.values());
    }
}
