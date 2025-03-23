import { describe, it, expect, beforeEach } from 'vitest';

// Mock implementation for testing Clarity contracts
const mockPrincipal = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
const mockCertifierPrincipal = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
const mockBlockHeight = 100;

// Mock state
let lastDriverId = 0;
let lastCertificationId = 0;
const drivers = new Map();
const certifications = new Map();

// Mock contract functions
const registerDriver = (name, licenseNumber, licenseExpiry, medicalTraining, cprCertified, firstAidCertified, specialTraining) => {
  const newId = lastDriverId + 1;
  lastDriverId = newId;
  
  drivers.set(newId, {
    owner: mockPrincipal,
    name,
    licenseNumber,
    licenseExpiry,
    medicalTraining,
    cprCertified,
    firstAidCertified,
    specialTraining,
    certificationStatus: 'pending',
    registrationDate: mockBlockHeight
  });
  
  return { value: newId };
};

const getDriver = (id) => {
  const driver = drivers.get(id);
  return driver ? driver : null;
};

const updateDriver = (id, licenseNumber, licenseExpiry, medicalTraining, cprCertified, firstAidCertified, specialTraining) => {
  const driver = drivers.get(id);
  if (!driver) return { error: 404 };
  if (driver.owner !== mockPrincipal) return { error: 403 };
  
  drivers.set(id, {
    ...driver,
    licenseNumber,
    licenseExpiry,
    medicalTraining,
    cprCertified,
    firstAidCertified,
    specialTraining,
    certificationStatus: 'pending' // Status reverts to pending after update
  });
  
  return { value: id };
};

const addCertification = (driverId, certificationType, expiryDate, certificationDetails, certifier = mockCertifierPrincipal) => {
  const driver = drivers.get(driverId);
  if (!driver) return { error: 404 };
  
  const newId = lastCertificationId + 1;
  lastCertificationId = newId;
  
  certifications.set(newId, {
    driverId,
    certifier,
    certificationType,
    issueDate: mockBlockHeight,
    expiryDate,
    certificationDetails
  });
  
  // Update the driver's certification status
  drivers.set(driverId, {
    ...driver,
    certificationStatus: 'certified'
  });
  
  return { value: newId };
};

const getCertification = (id) => {
  const certification = certifications.get(id);
  return certification ? certification : null;
};

const checkDriverEligibility = (driverId, requireCpr, requireFirstAid) => {
  const driver = drivers.get(driverId);
  if (!driver) return { error: 404 };
  
  return {
    value: {
      eligible: (
          driver.certificationStatus === 'certified' &&
          (!requireCpr || driver.cprCertified) &&
          (!requireFirstAid || driver.firstAidCertified) &&
          driver.licenseExpiry > mockBlockHeight
      ),
      certificationStatus: driver.certificationStatus
    }
  };
};

describe('Driver Certification Contract', () => {
  beforeEach(() => {
    // Reset state before each test
    lastDriverId = 0;
    lastCertificationId = 0;
    drivers.clear();
    certifications.clear();
  });
  
  it('should register a new driver', () => {
    const result = registerDriver(
        'Jane Smith',
        'DL12345678',
        mockBlockHeight + 10000, // Future expiry date
        'EMT Basic',
        true,
        true,
        'Elderly care, wheelchair handling'
    );
    
    expect(result.value).toBe(1);
    expect(drivers.size).toBe(1);
    
    const driver = getDriver(1);
    expect(driver).not.toBeNull();
    expect(driver.name).toBe('Jane Smith');
    expect(driver.licenseNumber).toBe('DL12345678');
    expect(driver.medicalTraining).toBe('EMT Basic');
    expect(driver.cprCertified).toBe(true);
    expect(driver.firstAidCertified).toBe(true);
    expect(driver.specialTraining).toBe('Elderly care, wheelchair handling');
    expect(driver.certificationStatus).toBe('pending');
  });
  
  it('should update driver information', () => {
    // First register a driver
    registerDriver(
        'Jane Smith',
        'DL12345678',
        mockBlockHeight + 10000,
        'EMT Basic',
        true,
        true,
        'Elderly care, wheelchair handling'
    );
    
    // Then update it
    const updateResult = updateDriver(
        1,
        'DL12345678',
        mockBlockHeight + 20000, // Extended expiry
        'EMT Intermediate',
        true,
        true,
        'Elderly care, wheelchair handling, oxygen therapy'
    );
    
    expect(updateResult.value).toBe(1);
    
    const driver = getDriver(1);
    expect(driver.licenseExpiry).toBe(mockBlockHeight + 20000);
    expect(driver.medicalTraining).toBe('EMT Intermediate');
    expect(driver.specialTraining).toBe('Elderly care, wheelchair handling, oxygen therapy');
    expect(driver.certificationStatus).toBe('pending');
  });
  
  it('should add a certification for a driver', () => {
    // First register a driver
    registerDriver(
        'Jane Smith',
        'DL12345678',
        mockBlockHeight + 10000,
        'EMT Basic',
        true,
        true,
        'Elderly care, wheelchair handling'
    );
    
    // Then add a certification
    const certificationResult = addCertification(
        1,
        'Medical Transport',
        mockBlockHeight + 5000,
        'Certified for non-emergency medical transport'
    );
    
    expect(certificationResult.value).toBe(1);
    expect(certifications.size).toBe(1);
    
    const certification = getCertification(1);
    expect(certification).not.toBeNull();
    expect(certification.driverId).toBe(1);
    expect(certification.certificationType).toBe('Medical Transport');
    expect(certification.certificationDetails).toBe('Certified for non-emergency medical transport');
    
    // Check that the driver status was updated
    const driver = getDriver(1);
    expect(driver.certificationStatus).toBe('certified');
  });
  
  it('should check driver eligibility', () => {
    // Register a driver with CPR but no first aid
    registerDriver(
        'Jane Smith',
        'DL12345678',
        mockBlockHeight + 10000,
        'EMT Basic',
        true,
        false,
        'Elderly care, wheelchair handling'
    );
    
    // Add certification
    addCertification(
        1,
        'Medical Transport',
        mockBlockHeight + 5000,
        'Certified for non-emergency medical transport'
    );
    
    // Check eligibility for CPR only
    const result1 = checkDriverEligibility(1, true, false);
    expect(result1.value.eligible).toBe(true);
    
    // Check eligibility for first aid (should fail)
    const result2 = checkDriverEligibility(1, false, true);
    expect(result2.value.eligible).toBe(false);
  });
});
