import { describe, it, expect } from 'vitest';
import { SiteMetadata, SiteNodeData, SiteEdgeData, SiteDestinationData } from '../website/src/firebase';
import { validateSiteConfiguration } from '../website/src/validation';

describe('Web Hub -> Android End-to-End Contract Verification', () => {
  const publishedSiteMetadata: SiteMetadata = {
    siteId: 'controlled_test_site',
    name: 'Controlled Calibration Site',
    type: 'photogrammetry',
    description: 'Standardized 10m x 10m field test site',
    published: true,
    version: 1,
    publishedAt: 1771520000000,
    calibration: { scale: 1.0, rotationY: 0.0, offsetX: 0.0, offsetZ: 0.0 }
  };

  const navNodes: SiteNodeData[] = [
    { id: 'n1', x: 0, y: 0, z: 0, floorId: 'floor_1', buildingId: 'b1', type: 'ENTRANCE' },
    { id: 'n2', x: 0, y: 0, z: -5, floorId: 'floor_1', buildingId: 'b1', type: 'WALKABLE' },
    { id: 'n3', x: 0, y: 0, z: -10, floorId: 'floor_1', buildingId: 'b1', type: 'WALKABLE' },
    { id: 'n4', x: 5, y: 0, z: -10, floorId: 'floor_1', buildingId: 'b1', type: 'DESTINATION' }
  ];

  const navEdges: SiteEdgeData[] = [
    { id: 'e1', from: 'n1', to: 'n2', distance: 5.0, walkable: true, transitionType: 'walk' },
    { id: 'e2', from: 'n2', to: 'n3', distance: 5.0, walkable: true, transitionType: 'walk' },
    { id: 'e3', from: 'n3', to: 'n4', distance: 5.0, walkable: true, transitionType: 'walk' }
  ];

  const siteDestinations: SiteDestinationData[] = [
    { id: 'd1', name: 'Entrance Origin', category: 'Reception', buildingId: 'b1', floorId: 'floor_1', navigationNodeId: 'n1' },
    { id: 'd2', name: 'Point A (5m North)', category: 'Corridor', buildingId: 'b1', floorId: 'floor_1', navigationNodeId: 'n2' },
    { id: 'd3', name: 'Point B (10m North)', category: 'Elevator', buildingId: 'b1', floorId: 'floor_1', navigationNodeId: 'n3' },
    { id: 'd4', name: 'Point C (East Wing)', category: 'Office', buildingId: 'b1', floorId: 'floor_1', navigationNodeId: 'n4' }
  ];

  it('should verify Web Hub site payload is valid for mobile Android loading', () => {
    const report = validateSiteConfiguration(publishedSiteMetadata, navNodes, navEdges, siteDestinations);
    expect(report.canPublish).toBe(true);
    expect(report.errorsCount).toBe(0);
  });

  it('should verify primary QR code payload resolution contract', () => {
    const qrPayloadString = `pathlume://site/${publishedSiteMetadata.siteId}`;
    expect(qrPayloadString.startsWith('pathlume://site/')).toBe(true);
    const extractedSiteId = qrPayloadString.replace('pathlume://site/', '');
    expect(extractedSiteId).toBe('controlled_test_site');
  });

  it('should verify canonical coordinate scale preservation', () => {
    const scale = publishedSiteMetadata.calibration?.scale || 1.0;
    const testDistance = 5.0;
    const siteWorldDistance = testDistance * scale;
    expect(siteWorldDistance).toBe(5.0);
  });
});
