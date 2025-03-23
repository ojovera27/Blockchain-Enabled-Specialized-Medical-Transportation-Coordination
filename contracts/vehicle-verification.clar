;; Vehicle Verification Contract
;; Validates appropriate medical equipment on board

;; Define data variables
(define-data-var last-vehicle-id uint u0)
(define-data-var last-inspection-id uint u0)

;; Map to store vehicle details
(define-map vehicles
  { id: uint }
  {
    owner: principal,
    registration-number: (string-ascii 50),
    vehicle-type: (string-ascii 50),
    capacity: uint,
    wheelchair-accessible: bool,
    stretcher-capable: bool,
    oxygen-equipped: bool,
    medical-equipment: (string-ascii 200),
    last-inspection-date: uint,
    verification-status: (string-ascii 20),
    registration-date: uint
  }
)

;; Map to store inspection records
(define-map inspections
  { id: uint }
  {
    vehicle-id: uint,
    inspector: principal,
    inspection-date: uint,
    equipment-verified: (string-ascii 200),
    safety-status: (string-ascii 20),
    cleanliness-status: (string-ascii 20),
    notes: (string-ascii 200)
  }
)

;; Get the last assigned vehicle ID
(define-read-only (get-last-vehicle-id)
  (ok (var-get last-vehicle-id))
)

;; Get vehicle details by ID
(define-read-only (get-vehicle (id uint))
  (map-get? vehicles { id: id })
)

;; Register a new vehicle
(define-public (register-vehicle
    (registration-number (string-ascii 50))
    (vehicle-type (string-ascii 50))
    (capacity uint)
    (wheelchair-accessible bool)
    (stretcher-capable bool)
    (oxygen-equipped bool)
    (medical-equipment (string-ascii 200)))
  (let
    ((new-id (+ (var-get last-vehicle-id) u1)))
    (var-set last-vehicle-id new-id)
    (map-set vehicles { id: new-id } {
      owner: tx-sender,
      registration-number: registration-number,
      vehicle-type: vehicle-type,
      capacity: capacity,
      wheelchair-accessible: wheelchair-accessible,
      stretcher-capable: stretcher-capable,
      oxygen-equipped: oxygen-equipped,
      medical-equipment: medical-equipment,
      last-inspection-date: u0,
      verification-status: "pending",
      registration-date: block-height
    })
    (ok new-id)
  )
)

;; Update vehicle information
(define-public (update-vehicle
    (id uint)
    (registration-number (string-ascii 50))
    (vehicle-type (string-ascii 50))
    (capacity uint)
    (wheelchair-accessible bool)
    (stretcher-capable bool)
    (oxygen-equipped bool)
    (medical-equipment (string-ascii 200)))
  (let ((vehicle-data (map-get? vehicles { id: id })))
    (match vehicle-data
      vehicle (if (is-eq tx-sender (get owner vehicle))
        (begin
          (map-set vehicles { id: id } {
            owner: (get owner vehicle),
            registration-number: registration-number,
            vehicle-type: vehicle-type,
            capacity: capacity,
            wheelchair-accessible: wheelchair-accessible,
            stretcher-capable: stretcher-capable,
            oxygen-equipped: oxygen-equipped,
            medical-equipment: medical-equipment,
            last-inspection-date: (get last-inspection-date vehicle),
            verification-status: "pending",
            registration-date: (get registration-date vehicle)
          })
          (ok id)
        )
        (err u403))
      (err u404)
    )
  )
)

;; Record a vehicle inspection
(define-public (record-inspection
    (vehicle-id uint)
    (equipment-verified (string-ascii 200))
    (safety-status (string-ascii 20))
    (cleanliness-status (string-ascii 20))
    (notes (string-ascii 200)))
  (let ((vehicle-data (map-get? vehicles { id: vehicle-id })))
    (match vehicle-data
      vehicle (let ((new-id (+ (var-get last-inspection-id) u1)))
        (var-set last-inspection-id new-id)
        (map-set inspections { id: new-id } {
          vehicle-id: vehicle-id,
          inspector: tx-sender,
          inspection-date: block-height,
          equipment-verified: equipment-verified,
          safety-status: safety-status,
          cleanliness-status: cleanliness-status,
          notes: notes
        })

        ;; Update the vehicle's last inspection date
        (map-set vehicles { id: vehicle-id } {
          owner: (get owner vehicle),
          registration-number: (get registration-number vehicle),
          vehicle-type: (get vehicle-type vehicle),
          capacity: (get capacity vehicle),
          wheelchair-accessible: (get wheelchair-accessible vehicle),
          stretcher-capable: (get stretcher-capable vehicle),
          oxygen-equipped: (get oxygen-equipped vehicle),
          medical-equipment: (get medical-equipment vehicle),
          last-inspection-date: block-height,
          verification-status: safety-status,
          registration-date: (get registration-date vehicle)
        })

        (ok new-id)
      )
      (err u404)
    )
  )
)

;; Get inspection details
(define-read-only (get-inspection (id uint))
  (map-get? inspections { id: id })
)

;; Get all inspections for a vehicle - simplified version
(define-read-only (get-vehicle-inspections (vehicle-id uint))
  (ok vehicle-id)
)

;; Check if a vehicle meets specific equipment requirements
(define-read-only (check-vehicle-suitability
    (vehicle-id uint)
    (wheelchair-needed bool)
    (stretcher-needed bool)
    (oxygen-needed bool))
  (let ((vehicle-data (map-get? vehicles { id: vehicle-id })))
    (match vehicle-data
      vehicle (ok {
        suitable: (and
                    (or (not wheelchair-needed) (get wheelchair-accessible vehicle))
                    (or (not stretcher-needed) (get stretcher-capable vehicle))
                    (or (not oxygen-needed) (get oxygen-equipped vehicle))
                  ),
        verification-status: (get verification-status vehicle)
      })
      (err u404)
    )
  )
)
