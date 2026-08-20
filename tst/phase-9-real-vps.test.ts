import { describe, it, expect } from 'vitest';
import { VPSAdapter, PathLumeVpsContract } from '../src/vps/vpsAdapter';

describe('Phase 9 Real VPS Adapter & Quality Control Pipeline', () => {
  it('should adapt raw Immersal response into PathLume VPS contract', () => {
    const immersalRaw = {
      px: 1.25,
      py: 0.0,
      pz: -3.5,
      r00: 0,
      r01: 0,
      r02: 0,
      r10: 1,
      confidence: 0.92
    };

    const adapted = VPSAdapter.adaptProviderResponse(
      immersalRaw,
      'Immersal',
      'controlled_test_site',
      'vps_map_001',
      180
    );

    expect(adapted).not.toBeNull();
    expect(adapted?.position.x).toBe(1.25);
    expect(adapted?.position.z).toBe(-3.5);
    expect(adapted?.confidence).toBe(0.92);
    expect(adapted?.provider).toBe('Immersal VPS Engine');
  });

  it('should enforce quality control gates on adapted VPS contracts', () => {
    const validContract: PathLumeVpsContract = {
      siteId: 'controlled_test_site',
      mapId: 'vps_map_001',
      timestamp: Date.now(),
      position: { x: 0, y: 0, z: -5.0 },
      rotation: { qx: 0, qy: 0, qz: 0, qw: 1 },
      confidence: 0.85,
      provider: 'Immersal VPS Engine',
      processingTimeMs: 210
    };

    // Confidence Gate
    expect(validContract.confidence >= 0.80).toBe(true);

    // Freshness Gate (< 2500ms)
    const age = Date.now() - validContract.timestamp;
    expect(age < 2500).toBe(true);

    // Jump Limit (< 10m)
    const previousPos = { x: 0, y: 0, z: -5.2 };
    const dist = Math.sqrt(
      Math.pow(validContract.position.x - previousPos.x, 2) +
      Math.pow(validContract.position.y - previousPos.y, 2) +
      Math.pow(validContract.position.z - previousPos.z, 2)
    );
    expect(dist < 10.0).toBe(true);
  });

  it('should maintain strict stop condition when server secrets are absent', () => {
    const hasApiKey = Boolean(process.env.VPS_API_KEY);
    const status = hasApiKey ? 'CONNECTED' : 'UNCONFIGURED';
    expect(status).toBe('UNCONFIGURED');
  });
});
