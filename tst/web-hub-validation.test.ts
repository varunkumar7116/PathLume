import { describe, it, expect } from 'vitest';
import { validateSiteConfiguration } from '../website/src/validation';
import { SiteMetadata, SiteNodeData, SiteEdgeData, SiteDestinationData } from '../website/src/firebase';

describe('Web Hub Site Validation Engine', () => {
  const mockMetadata: SiteMetadata = {
    siteId: 'controlled_test_site',
    name: 'Controlled Test Site',
    type: 'photogrammetry',
    description: '10m x 10m Test Site',
    published: true,
    version: 1,
    calibration: { scale: 1.0, rotationY: 0.0, offsetX: 0.0, offsetZ: 0.0 }
  };

  const mockNodes: SiteNodeData[] = [
    { id: 'n1', x: 0, y: 0, z: 0, floorId: 'floor_1', buildingId: 'b1', type: 'ENTRANCE' },
    { id: 'n2', x: 0, y: 0, z: -5, floorId: 'floor_1', buildingId: 'b1', type: 'WALKABLE' }
  ];

  const mockEdges: SiteEdgeData[] = [
    { id: 'e1', from: 'n1', to: 'n2', distance: 5.0, walkable: true, transitionType: 'walk' }
  ];

  const mockDestinations: SiteDestinationData[] = [
    { id: 'd1', name: 'Reception Desk', category: 'Reception', buildingId: 'b1', floorId: 'floor_1', navigationNodeId: 'n1' }
  ];

  it('should pass validation for a fully valid site configuration', () => {
    const report = validateSiteConfiguration(mockMetadata, mockNodes, mockEdges, mockDestinations);
    expect(report.isValid).toBe(true);
    expect(report.canPublish).toBe(true);
    expect(report.errorsCount).toBe(0);
  });

  it('should fail validation when navigation graph has zero nodes', () => {
    const report = validateSiteConfiguration(mockMetadata, [], [], []);
    expect(report.isValid).toBe(false);
    expect(report.canPublish).toBe(false);
    expect(report.errorsCount).toBeGreaterThan(0);
  });

  it('should fail validation if a destination references a non-existent node', () => {
    const invalidDests: SiteDestinationData[] = [
      { id: 'd1', name: 'Ghost Desk', category: 'Office', navigationNodeId: 'non_existent_node' }
    ];
    const report = validateSiteConfiguration(mockMetadata, mockNodes, mockEdges, invalidDests);
    expect(report.isValid).toBe(false);
    expect(report.canPublish).toBe(false);
    expect(report.issues.some(i => i.severity === 'ERROR' && i.category === 'DESTINATION')).toBe(true);
  });

  it('should fail validation if calibration scale is zero', () => {
    const invalidMeta: SiteMetadata = {
      ...mockMetadata,
      calibration: { scale: 0, rotationY: 0, offsetX: 0, offsetZ: 0 }
    };
    const report = validateSiteConfiguration(invalidMeta, mockNodes, mockEdges, mockDestinations);
    expect(report.isValid).toBe(false);
    expect(report.issues.some(i => i.severity === 'ERROR' && i.category === 'CALIBRATION')).toBe(true);
  });
});
