import { SiteConfig, SiteQRPayload, SiteBuilding, SiteDestination, SiteVPSConfig } from './siteTypes';
import { DEFAULT_SITE_REGISTRY } from './siteRegistry';
import { NavigationGraph } from '../navigation/graph/navigationGraph';
import { SAMPLE_NODES } from '../navigation/graph/nodes';
import { SAMPLE_EDGES } from '../navigation/graph/edges';

export class SiteManager {
    private sitesRegistry: Map<string, SiteConfig> = new Map();
    private activeSite: SiteConfig | null = null;

    constructor() {
        for (const [key, config] of Object.entries(DEFAULT_SITE_REGISTRY)) {
            this.sitesRegistry.set(key, config);
        }
    }

    public registerSite(config: SiteConfig): void {
        this.sitesRegistry.set(config.siteId, config);
    }

    public getSiteConfig(siteId: string): SiteConfig | null {
        return this.sitesRegistry.get(siteId) || null;
    }

    /**
     * Parse single QR code input.
     * The QR contains ONLY the site identifier.
     * Supports:
     * 1. URL: https://pathlume.app/s/site_001
     * 2. Deep link URI: pathlume://site/site_001
     * 3. JSON: { "siteId": "site_001" }
     * 4. Legacy format backward compatibility: navcat://map/college_block_a/entrance_01 or { "mapId": "college_block_a" }
     */
    public parseQRPayload(qrData: string | object): SiteQRPayload | null {
        if (!qrData) return null;

        if (typeof qrData === 'object') {
            const obj = qrData as any;
            if (obj.siteId) {
                return { siteId: String(obj.siteId) };
            }
            if (obj.mapId) {
                return { siteId: String(obj.mapId) };
            }
            return null;
        }

        const raw = qrData.trim();

        // 1. JSON
        if (raw.startsWith('{')) {
            try {
                const parsed = JSON.parse(raw);
                if (parsed?.siteId) return { siteId: String(parsed.siteId) };
                if (parsed?.mapId) return { siteId: String(parsed.mapId) };
            } catch {
                // Ignore parse errors and fall through
            }
        }

        // 2. URL / Deep link containing /s/ or /site/
        if (raw.includes('/s/')) {
            const siteId = raw.split('/s/')[1]?.split('/')[0]?.split('?')[0];
            if (siteId) return { siteId };
        }
        if (raw.includes('/site/')) {
            const siteId = raw.split('/site/')[1]?.split('/')[0]?.split('?')[0];
            if (siteId) return { siteId };
        }

        // 3. Legacy deep link / URL with /map/
        if (raw.includes('/map/')) {
            const mapId = raw.split('/map/')[1]?.split('/')[0]?.split('?')[0];
            if (mapId) return { siteId: mapId };
        }

        // 4. Raw string ID
        if (raw.length > 0 && !raw.includes(' ')) {
            return { siteId: raw };
        }

        return null;
    }

    /**
     * Create a new Universal Site with generic non-hardcoded type metadata
     * and automatically generate its ONE single QR URL.
     */
    public createSite(params: {
        name: string;
        type: string; // Freeform metadata (e.g. 'campus', 'hospital', 'mall', 'airport', 'office', 'hotel', 'warehouse', 'other')
        description?: string;
        buildings?: SiteBuilding[];
        destinations?: SiteDestination[];
        navigationGraph?: { nodes: any[]; edges: any[] };
        vps?: Partial<SiteVPSConfig>;
    }): SiteConfig {
        const idSuffix = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
        const siteId = `site_${Date.now()}_${idSuffix}`;
        const qrUrl = `https://pathlume.app/s/${siteId}`;

        const siteConfig: SiteConfig = {
            siteId,
            name: params.name,
            type: params.type || 'other',
            description: params.description || '',
            status: 'active',
            version: 1,
            qrUrl,
            buildings: params.buildings || [
                {
                    buildingId: 'building_main',
                    name: `${params.name} Main Building`,
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
            destinations: params.destinations || [],
            navigationGraph: params.navigationGraph || {
                nodes: SAMPLE_NODES,
                edges: SAMPLE_EDGES,
            },
            vps: {
                siteId,
                provider: params.vps?.provider || 'mock',
                vpsMapId: params.vps?.vpsMapId || `vps_${siteId}`,
                transformConfig: params.vps?.transformConfig || {
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
        };

        this.registerSite(siteConfig);
        return siteConfig;
    }

    public loadSiteFromQR(qrPayload: SiteQRPayload): {
        config: SiteConfig;
        graph: NavigationGraph;
    } {
        let config = this.getSiteConfig(qrPayload.siteId);

        if (!config) {
            // Dynamic fallback for unknown siteId
            config = {
                siteId: qrPayload.siteId,
                name: `Site ${qrPayload.siteId}`,
                type: 'other',
                description: 'Dynamically initialized indoor site',
                status: 'active',
                version: 1,
                qrUrl: `https://pathlume.app/s/${qrPayload.siteId}`,
                buildings: [
                    {
                        buildingId: 'building_main',
                        name: 'Main Building',
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
                destinations: [],
                navigationGraph: {
                    nodes: SAMPLE_NODES,
                    edges: SAMPLE_EDGES,
                },
                vps: {
                    siteId: qrPayload.siteId,
                    provider: 'mock',
                    vpsMapId: `vps_${qrPayload.siteId}`,
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
            };
            this.registerSite(config);
        }

        this.activeSite = config;
        const nodes = config.navigationGraph?.nodes || SAMPLE_NODES;
        const edges = config.navigationGraph?.edges || SAMPLE_EDGES;
        const graph = new NavigationGraph(nodes, edges);

        return { config, graph };
    }

    public getActiveSite(): SiteConfig | null {
        return this.activeSite;
    }

    public getAllRegisteredSites(): SiteConfig[] {
        return Array.from(this.sitesRegistry.values());
    }
}
