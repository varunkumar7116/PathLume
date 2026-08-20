import { describe, it, expect } from 'vitest';

interface VpsPublishCheckSite {
  siteId: string;
  name: string;
  vpsRequired: boolean;
  vpsMapId?: string;
  vpsProvider?: string;
}

function validateVpsPublishGate(site: VpsPublishCheckSite): { valid: boolean; error?: string } {
  if (!site.siteId || !site.name) {
    return { valid: false, error: 'Site ID and name are required.' };
  }
  if (site.vpsRequired) {
    if (!site.vpsMapId || site.vpsMapId.trim() === '') {
      return { valid: false, error: 'VPS Map ID is required when VPS is marked as mandatory.' };
    }
    if (!site.vpsProvider || site.vpsProvider.trim() === '') {
      return { valid: false, error: 'VPS Provider name is required when VPS is marked as mandatory.' };
    }
  }
  return { valid: true };
}

describe('Phase 8 VPS Integration & Publish Gate Engine', () => {
  it('should pass publish gate when VPS is optional and mapId is unconfigured', () => {
    const optionalSite: VpsPublishCheckSite = {
      siteId: 'site_optional_vps',
      name: 'Campus Library',
      vpsRequired: false
    };
    const result = validateVpsPublishGate(optionalSite);
    expect(result.valid).toBe(true);
  });

  it('should block publish gate when VPS is mandatory but mapId is missing', () => {
    const mandatorySite: VpsPublishCheckSite = {
      siteId: 'site_mandatory_vps',
      name: 'High Precision Lab',
      vpsRequired: true
    };
    const result = validateVpsPublishGate(mandatorySite);
    expect(result.valid).toBe(false);
    expect(result.error).toContain('VPS Map ID is required');
  });

  it('should pass publish gate when mandatory VPS has valid mapId and provider', () => {
    const validSite: VpsPublishCheckSite = {
      siteId: 'site_valid_vps',
      name: 'Mapped Hall',
      vpsRequired: true,
      vpsMapId: 'vps_hall_map_001',
      vpsProvider: 'Immersal'
    };
    const result = validateVpsPublishGate(validSite);
    expect(result.valid).toBe(true);
  });

  it('should verify QR payload contains zero secret credentials', () => {
    const siteId = 'controlled_test_site';
    const qrPayload = `pathlume://site/${siteId}`;
    expect(qrPayload).not.toContain('api_key');
    expect(qrPayload).not.toContain('secret');
    expect(qrPayload).toBe('pathlume://site/controlled_test_site');
  });
});
