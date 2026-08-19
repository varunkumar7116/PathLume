import { VPSSettings } from './vpsTypes';

/**
 * VPS Configuration loader.
 * Reads environment variables with safe defaults for development.
 */
export function getVPSConfig(): VPSSettings {
    let serverUrl = 'http://localhost:8000/localize';
    
    // Safely check Vite environment variables if available
    try {
        if (typeof import.meta !== 'undefined' && import.meta.env) {
            if (import.meta.env.VITE_VPS_URL) {
                serverUrl = import.meta.env.VITE_VPS_URL;
            }
        }
    } catch {
        // Fallback to default
    }

    const frameRateStr = typeof process !== 'undefined' && process.env ? process.env.VPS_FRAME_RATE : '5';
    const frameRate = parseInt(frameRateStr || '5', 10) || 5;

    return {
        serverUrl,
        frameRate,
        confidenceThreshold: 2.0, // poses with accuracy > 2.0m trigger VPS_LOW_CONFIDENCE
        lostTimeoutMs: 8000, // 8s without VPS response triggers VPS_LOST
    };
}
