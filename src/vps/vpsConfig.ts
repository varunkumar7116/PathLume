import { VPSSettings } from './vpsTypes';

/**
 * VPS Configuration loader.
 * Reads environment variables with safe defaults for development.
 */
export function getVPSConfig(): VPSSettings {
    let serverUrl = 'http://localhost:8000/localize';
    
    // Safely check Vite environment variables if available
    try {
        const meta = import.meta as Record<string, any>;
        if (meta && meta.env && meta.env.VITE_VPS_URL) {
            serverUrl = meta.env.VITE_VPS_URL;
        }
    } catch {
        // Fallback to default
    }

    const proc = typeof process !== 'undefined' ? process : undefined;
    const frameRateStr = proc?.env?.VPS_FRAME_RATE;
    const frameRate = parseInt(frameRateStr || '5', 10) || 5;

    return {
        serverUrl,
        frameRate,
        confidenceThreshold: 2.0, // poses with accuracy > 2.0m trigger VPS_LOW_CONFIDENCE
        lostTimeoutMs: 8000, // 8s without VPS response triggers VPS_LOST
    };
}
