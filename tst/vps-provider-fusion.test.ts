import { describe, it, expect } from 'vitest';

interface VpsPoseTest {
  x: number;
  y: number;
  z: number;
  confidence: number;
  timestampMs: number;
  mapId: string;
}

function evaluateVpsResultQuality(
  result: VpsPoseTest,
  activeMapId: string,
  minConfidence: number = 0.80,
  maxAgeMs: number = 2500
): { accepted: boolean; reason?: string } {
  if (result.mapId !== activeMapId) {
    return { accepted: false, reason: 'MAP_MISMATCH' };
  }
  if (result.confidence < minConfidence) {
    return { accepted: false, reason: 'LOW_CONFIDENCE' };
  }
  const age = Date.now() - result.timestampMs;
  if (age > maxAgeMs) {
    return { accepted: false, reason: 'STALE_TIMESTAMP' };
  }
  return { accepted: true };
}

describe('VPS Provider & Quality Control Engine', () => {
  const activeMapId = 'vps_controlled_mesh';

  it('should accept valid high-confidence VPS localization result', () => {
    const validPose: VpsPoseTest = {
      x: 0,
      y: 0,
      z: -5,
      confidence: 0.88,
      timestampMs: Date.now(),
      mapId: activeMapId
    };
    const evalResult = evaluateVpsResultQuality(validPose, activeMapId);
    expect(evalResult.accepted).toBe(true);
  });

  it('should reject VPS result with low confidence below 0.80 threshold', () => {
    const lowConfPose: VpsPoseTest = {
      x: 0,
      y: 0,
      z: -5,
      confidence: 0.65,
      timestampMs: Date.now(),
      mapId: activeMapId
    };
    const evalResult = evaluateVpsResultQuality(lowConfPose, activeMapId);
    expect(evalResult.accepted).toBe(false);
    expect(evalResult.reason).toBe('LOW_CONFIDENCE');
  });

  it('should reject VPS result from mismatched site map ID', () => {
    const wrongMapPose: VpsPoseTest = {
      x: 0,
      y: 0,
      z: -5,
      confidence: 0.90,
      timestampMs: Date.now(),
      mapId: 'different_map_id'
    };
    const evalResult = evaluateVpsResultQuality(wrongMapPose, activeMapId);
    expect(evalResult.accepted).toBe(false);
    expect(evalResult.reason).toBe('MAP_MISMATCH');
  });

  it('should reject VPS result with stale timestamp older than 2500ms', () => {
    const stalePose: VpsPoseTest = {
      x: 0,
      y: 0,
      z: -5,
      confidence: 0.92,
      timestampMs: Date.now() - 5000,
      mapId: activeMapId
    };
    const evalResult = evaluateVpsResultQuality(stalePose, activeMapId);
    expect(evalResult.accepted).toBe(false);
    expect(evalResult.reason).toBe('STALE_TIMESTAMP');
  });
});
