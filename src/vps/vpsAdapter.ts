import { Vector3D, VPSPose, VPSStatus } from './vpsTypes';
import { VPSClient } from './vpsClient';

export interface PathLumeVpsContract {
    siteId: string;
    mapId: string;
    timestamp: number;
    position: Vector3D;
    rotation: { qx: number; qy: number; qz: number; qw: number };
    confidence: number;
    provider: string;
    processingTimeMs: number;
}

export type VpsStatusCallback = (status: VPSStatus, pose?: VPSPose | null, latencyMs?: number) => void;

export class VPSAdapter {
    private client: VPSClient;
    private statusListeners: Array<VpsStatusCallback> = [];

    constructor(client: VPSClient) {
        this.client = client;
    }

    public onStatusUpdate(callback: VpsStatusCallback): void {
        this.statusListeners.push(callback);
    }

    public async localize(frame: string, mapId = 'building_01'): Promise<VPSPose | null> {
        this.statusListeners.forEach(cb => cb('VPS_SEARCHING'));
        const response = await this.client.localizeFrame(frame, mapId);

        if (response.localized && response.position && response.rotation) {
            const pose: VPSPose = {
                position: response.position,
                rotation: response.rotation,
                heading: response.heading || 0,
                floor: response.floor || 1,
                accuracy: response.accuracy || 1.0,
                timestamp: Date.now()
            };
            this.statusListeners.forEach(cb => cb('VPS_LOCALIZED', pose, this.client.getLastLatencyMs()));
            return pose;
        } else {
            this.statusListeners.forEach(cb => cb('VPS_SEARCHING', null, this.client.getLastLatencyMs()));
            return null;
        }
    }

    /**
     * Adapts raw provider responses (Immersal, Google Geospatial, etc.) into the PathLume internal VPS contract.
     */
    public static adaptProviderResponse(
        rawResponse: any,
        providerName: string,
        siteId: string,
        mapId: string,
        processingTimeMs: number
    ): PathLumeVpsContract | null {
        if (!rawResponse || typeof rawResponse !== 'object') {
            return null;
        }

        // 1. Immersal Format Adapter
        if (providerName.toLowerCase().includes('immersal') || rawResponse.px !== undefined) {
            const posX = Number(rawResponse.px ?? rawResponse.position?.x ?? 0);
            const posY = Number(rawResponse.py ?? rawResponse.position?.y ?? 0);
            const posZ = Number(rawResponse.pz ?? rawResponse.position?.z ?? 0);
            const qx = Number(rawResponse.r00 ?? rawResponse.rotation?.qx ?? 0);
            const qy = Number(rawResponse.r01 ?? rawResponse.rotation?.qy ?? 0);
            const qz = Number(rawResponse.r02 ?? rawResponse.rotation?.qz ?? 0);
            const qw = Number(rawResponse.r10 ?? rawResponse.rotation?.qw ?? 1);
            const confidence = Number(rawResponse.confidence ?? (rawResponse.success ? 0.88 : 0.0));

            return {
                siteId,
                mapId,
                timestamp: Date.now(),
                position: { x: posX, y: posY, z: posZ },
                rotation: { qx, qy, qz, qw },
                confidence,
                provider: 'Immersal VPS Engine',
                processingTimeMs
            };
        }

        // 2. Standard PathLume Contract Adapter
        if (rawResponse.position && rawResponse.confidence !== undefined) {
            return {
                siteId: rawResponse.siteId || siteId,
                mapId: rawResponse.mapId || mapId,
                timestamp: rawResponse.timestamp || Date.now(),
                position: {
                    x: Number(rawResponse.position.x || 0),
                    y: Number(rawResponse.position.y || 0),
                    z: Number(rawResponse.position.z || 0)
                },
                rotation: {
                    qx: Number(rawResponse.rotation?.qx || rawResponse.rotation?.x || 0),
                    qy: Number(rawResponse.rotation?.qy || rawResponse.rotation?.y || 0),
                    qz: Number(rawResponse.rotation?.qz || rawResponse.rotation?.z || 0),
                    qw: Number(rawResponse.rotation?.qw || rawResponse.rotation?.w || 1)
                },
                confidence: Number(rawResponse.confidence || 0),
                provider: providerName,
                processingTimeMs
            };
        }

        return null;
    }
}
