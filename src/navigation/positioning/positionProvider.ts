import { UserPositionState } from './userPosition';

export type PositionCallback = (position: UserPositionState) => void;
export type ProviderStatusCallback = (status: string, details?: any) => void;

/**
 * Generic PositionProvider Interface.
 * Implemented by MockPositionProvider, MobilePositionProvider, and VPSPositionProvider.
 */
export interface PositionProvider {
    /**
     * Subscribe to real-time user position updates.
     * Returns cleanup unsubscribe function.
     */
    onPositionUpdate(callback: PositionCallback): () => void;

    /**
     * Subscribe to provider status updates (e.g. VPS_SEARCHING, VPS_LOCALIZED, etc.).
     */
    onStatusUpdate?(callback: ProviderStatusCallback): () => void;

    /**
     * Start producing position updates.
     */
    start(): void;

    /**
     * Stop producing position updates.
     */
    stop(): void;

    /**
     * Get latest cached user position state.
     */
    getCurrentPosition(): UserPositionState;
}
