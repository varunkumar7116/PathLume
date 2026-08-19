import { MapMetadata, QRPayload } from './vpsTypes';
import { SAMPLE_NODES } from '../navigation/graph/nodes';
import { SAMPLE_EDGES } from '../navigation/graph/edges';
import { NavigationGraph } from '../navigation/graph/navigationGraph';

export class MapManager {
    private activeMap: MapMetadata | null = null;
    private mapsRegistry: Map<string, MapMetadata> = new Map();

    constructor() {
        // Register default building_01 metadata
        this.registerMap({
            mapId: 'building_01',
            mapName: 'Main Campus Building 1',
            glbUrl: './models/sample1.glb',
            floor: 1,
            entryPoint: 'main_entrance',
            transformConfig: {
                translation: { x: 0, y: -1.9, z: 0 },
                rotation: { x: 0, y: 0, z: 0 },
                scale: 1.0,
            },
        });
    }

    public registerMap(metadata: MapMetadata): void {
        this.mapsRegistry.set(metadata.mapId, metadata);
    }

    public parseQRPayload(qrData: string | object): QRPayload | null {
        try {
            const data = typeof qrData === 'string' ? JSON.parse(qrData) : qrData;
            if (data && data.mapId) {
                return {
                    mapId: data.mapId,
                    floor: data.floor ?? 1,
                    entryPoint: data.entryPoint || 'main_entrance',
                };
            }
        } catch {
            // Not a valid JSON payload
        }
        return null;
    }

    public loadMapFromQR(qrPayload: QRPayload): {
        metadata: MapMetadata;
        graph: NavigationGraph;
    } {
        const metadata = this.mapsRegistry.get(qrPayload.mapId) ?? {
            mapId: qrPayload.mapId,
            mapName: `Building ${qrPayload.mapId}`,
            glbUrl: './models/sample1.glb',
            floor: qrPayload.floor,
            entryPoint: qrPayload.entryPoint,
            transformConfig: {
                translation: { x: 0, y: -1.9, z: 0 },
                rotation: { x: 0, y: 0, z: 0 },
                scale: 1.0,
            },
        };

        this.activeMap = metadata;

        // Load graph for active map
        const graph = new NavigationGraph(SAMPLE_NODES, SAMPLE_EDGES);

        return { metadata, graph };
    }

    public getActiveMap(): MapMetadata | null {
        return this.activeMap;
    }

    public getAllRegisteredMaps(): MapMetadata[] {
        return Array.from(this.mapsRegistry.values());
    }
}
