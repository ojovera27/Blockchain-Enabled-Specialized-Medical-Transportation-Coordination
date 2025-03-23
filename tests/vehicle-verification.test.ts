import { describe, it, expect, beforeEach } from 'vitest';

// Mock implementation for testing Clarity contracts
const mockPrincipal = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
const mockInspectorPrincipal = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
const mockBlockHeight = 100;

// Mock state
let lastVehicleId = 0;
let lastInspectionId = 0;
const vehicles = new Map();
const inspections = new Map();

// Mock contract functions
const registerVehicle = (registrationNumber, vehicleType, capacity, wheelchairAccessible, stretcherCapable, oxygenEquipped, medicalEquipment) => {
  const newId = lastVehicleId + 1;
  lastVehicleId = newId;
  
  vehicles.set(newId, {
    owner: mockPrincipal,
    registrationNumber,
    vehicleType,
    capacity,
    wheelchairAccessible,
    stretcherCapable,
    oxygenEquipped,
    medicalEquipment,
    lastInspectionDate: 0,
    verificationStatus: 'pending',
    registrationDate: mockBlockHeight
  });
  
  return { value: newId };
};

const getVehicle = (id) => {
  const vehicle = vehicles.get(id);
  return vehicle ? vehicle : null;
};

const updateVehicle = (id, registrationNumber, vehicleType, capacity, wheelchairAccessible, stretcherCapable, oxygenEquipped, medicalEquipment) => {
  const vehicle = vehicles.get(id);
  if (!vehicle) return { error: 404 };
  if (vehicle.owner !== mockPrincipal) return { error: 403 };
  
  vehicles.set(id, {
    ...vehicle,
    registrationNumber,
    vehicleType,
    capacity,
    wheelchairAccessible,
    stretcherCapable,
    oxygenEquipped,
    medicalEquipment,
    verificationStatus: 'pending' // Status reverts to pending after update
  });
  
  return { value: id };
};

const recordInspection = (vehicleId, equipmentVerified, safetyStatus, cleanlinessStatus, notes, inspector = mockInspectorPrincipal) => {
  const vehicle = vehicles.get(vehicleId);
  if (!vehicle) return { error: 404 };
  
  const newId = lastInspectionId + 1;
  lastInspectionId = newId;
  
  inspections.set(newId, {
    vehicleId,
    inspector,
    inspectionDate: mockBlockHeight,
    equipmentVerified,
    safetyStatus,
    cleanlinessStatus,
    notes
  });
  
  // Update the vehicle's last inspection date and status
  vehicles.set(vehicleId, {
    ...vehicle,
    lastInspectionDate: mockBlockHeight,
    verificationStatus: safetyStatus
  });
  
  return { value: newId };
};

const getInspection = (id) => {
  const inspection = inspections.get(id);
  return inspection ? inspection : null;
};

const checkVehicleSuitability = (vehicleId, wheelchairNeeded, stretcherNeeded, oxygenNeeded) => {
  const vehicle = vehicles.get(vehicleId);
  if (!vehicle) return { error: 404 };
  
  return {
    value: {
      suitable: (
          (!wheelchairNeeded || vehicle.wheelchairAccessible) &&
          (!stretcherNeeded || vehicle.stretcherCapable) &&
          (!oxygenNeeded || vehicle.oxygenEquipped)
      ),
      verificationStatus: vehicle.verificationStatus
    }
  };
};

describe('Vehicle Verification Contract', () => {
  beforeEach(() => {
    // Reset state before each test
    lastVehicleId = 0;
    lastInspectionId = 0;
    vehicles.clear();
    inspections.clear();
  });
  
  it('should register a new vehicle', () => {
    const result = registerVehicle(
        'ABC123',
        'Van',
        4,
        true,
        true,
        true,
        'Wheelchair lift, oxygen tanks, first aid kit'
    );
    
    expect(result.value).toBe(1);
    expect(vehicles.size).toBe(1);
    
    const vehicle = getVehicle(1);
    expect(vehicle).not.toBeNull();
    expect(vehicle.registrationNumber).toBe('ABC123');
    expect(vehicle.vehicleType).toBe('Van');
    expect(vehicle.capacity).toBe(4);
    expect(vehicle.wheelchairAccessible).toBe(true);
    expect(vehicle.stretcherCapable).toBe(true);
    expect(vehicle.oxygenEquipped).toBe(true);
    expect(vehicle.medicalEquipment).toBe('Wheelchair lift, oxygen tanks, first aid kit');
    expect(vehicle.verificationStatus).toBe('pending');
  });
  
  it('should update vehicle information', () => {
    // First register a vehicle
    registerVehicle(
        'ABC123',
        'Van',
        4,
        true,
        true,
        true,
        'Wheelchair lift, oxygen tanks, first aid kit'
    );
    
    // Then update it
    const updateResult = updateVehicle(
        1,
        'ABC123',
        'Van',
        6,
        true,
        true,
        true,
        'Wheelchair lift, oxygen tanks, first aid kit, AED'
    );
    
    expect(updateResult.value).toBe(1);
    
    const vehicle = getVehicle(1);
    expect(vehicle.capacity).toBe(6);
    expect(vehicle.medicalEquipment).toBe('Wheelchair lift, oxygen tanks, first aid kit, AED');
    expect(vehicle.verificationStatus).toBe('pending');
  });
  
  it('should record a vehicle inspection', () => {
    // First register a vehicle
    registerVehicle(
        'ABC123',
        'Van',
        4,
        true,
        true,
        true,
        'Wheelchair lift, oxygen tanks, first aid kit'
    );
    
    // Then record an inspection
    const inspectionResult = recordInspection(
        1,
        'Wheelchair lift, oxygen tanks, first aid kit',
        'passed',
        'passed',
        'All equipment in good working order'
    );
    
    expect(inspectionResult.value).toBe(1);
    expect(inspections.size).toBe(1);
    
    const inspection = getInspection(1);
    expect(inspection).not.toBeNull();
    expect(inspection.vehicleId).toBe(1);
    expect(inspection.equipmentVerified).toBe('Wheelchair lift, oxygen tanks, first aid kit');
    expect(inspection.safetyStatus).toBe('passed');
    
    // Check that the vehicle status was updated
    const vehicle = getVehicle(1);
    expect(vehicle.lastInspectionDate).toBe(mockBlockHeight);
    expect(vehicle.verificationStatus).toBe('passed');
  });
  
  it('should check vehicle suitability', () => {
    // Register a vehicle with wheelchair access but no stretcher
    registerVehicle(
        'ABC123',
        'Van',
        4,
        true,
        false,
        true,
        'Wheelchair lift, oxygen tanks, first aid kit'
    );
    
    // Check suitability for wheelchair only
    const result1 = checkVehicleSuitability(1, true, false, true);
    expect(result1.value.suitable).toBe(true);
    
    // Check suitability for stretcher (should fail)
    const result2 = checkVehicleSuitability(1, false, true, false);
    expect(result2.value.suitable).toBe(false);
  });
});
