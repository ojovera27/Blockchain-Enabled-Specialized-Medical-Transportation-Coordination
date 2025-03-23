;; Patient Registration Contract
;; Records transportation needs and requirements

;; Define data variables
(define-data-var last-patient-id uint u0)
(define-data-var last-request-id uint u0)

;; Map to store patient details
(define-map patients
  { id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    address: (string-ascii 200),
    contact: (string-ascii 50),
    medical-condition: (string-ascii 200),
    mobility-status: (string-ascii 50),
    equipment-needs: (string-ascii 200),
    recurring-schedule: bool,
    registration-date: uint
  }
)

;; Map to store transportation requests
(define-map transport-requests
  { id: uint }
  {
    patient-id: uint,
    pickup-location: (string-ascii 200),
    destination: (string-ascii 200),
    appointment-time: uint,
    return-trip: bool,
    special-instructions: (string-ascii 200),
    status: (string-ascii 20),
    request-date: uint
  }
)

;; Get the last assigned patient ID
(define-read-only (get-last-patient-id)
  (ok (var-get last-patient-id))
)

;; Get patient details by ID
(define-read-only (get-patient (id uint))
  (map-get? patients { id: id })
)

;; Register a new patient
(define-public (register-patient
    (name (string-ascii 100))
    (address (string-ascii 200))
    (contact (string-ascii 50))
    (medical-condition (string-ascii 200))
    (mobility-status (string-ascii 50))
    (equipment-needs (string-ascii 200))
    (recurring-schedule bool))
  (let
    ((new-id (+ (var-get last-patient-id) u1)))
    (var-set last-patient-id new-id)
    (map-set patients { id: new-id } {
      owner: tx-sender,
      name: name,
      address: address,
      contact: contact,
      medical-condition: medical-condition,
      mobility-status: mobility-status,
      equipment-needs: equipment-needs,
      recurring-schedule: recurring-schedule,
      registration-date: block-height
    })
    (ok new-id)
  )
)

;; Update patient information
(define-public (update-patient
    (id uint)
    (address (string-ascii 200))
    (contact (string-ascii 50))
    (medical-condition (string-ascii 200))
    (mobility-status (string-ascii 50))
    (equipment-needs (string-ascii 200))
    (recurring-schedule bool))
  (let ((patient-data (map-get? patients { id: id })))
    (match patient-data
      patient (if (is-eq tx-sender (get owner patient))
        (begin
          (map-set patients { id: id } {
            owner: (get owner patient),
            name: (get name patient),
            address: address,
            contact: contact,
            medical-condition: medical-condition,
            mobility-status: mobility-status,
            equipment-needs: equipment-needs,
            recurring-schedule: recurring-schedule,
            registration-date: (get registration-date patient)
          })
          (ok id)
        )
        (err u403))
      (err u404)
    )
  )
)

;; Create a transportation request
(define-public (create-transport-request
    (patient-id uint)
    (pickup-location (string-ascii 200))
    (destination (string-ascii 200))
    (appointment-time uint)
    (return-trip bool)
    (special-instructions (string-ascii 200)))
  (let ((patient-data (map-get? patients { id: patient-id })))
    (match patient-data
      patient (if (is-eq tx-sender (get owner patient))
        (let ((new-id (+ (var-get last-request-id) u1)))
          (var-set last-request-id new-id)
          (map-set transport-requests { id: new-id } {
            patient-id: patient-id,
            pickup-location: pickup-location,
            destination: destination,
            appointment-time: appointment-time,
            return-trip: return-trip,
            special-instructions: special-instructions,
            status: "pending",
            request-date: block-height
          })
          (ok new-id)
        )
        (err u403))
      (err u404)
    )
  )
)

;; Get transport request details
(define-read-only (get-transport-request (id uint))
  (map-get? transport-requests { id: id })
)

;; Update transport request status
(define-public (update-request-status
    (request-id uint)
    (status (string-ascii 20)))
  (let ((request-data (map-get? transport-requests { id: request-id })))
    (match request-data
      request (let ((patient-data (map-get? patients { id: (get patient-id request) })))
        (match patient-data
          patient (if (is-eq tx-sender (get owner patient))
            (begin
              (map-set transport-requests { id: request-id } {
                patient-id: (get patient-id request),
                pickup-location: (get pickup-location request),
                destination: (get destination request),
                appointment-time: (get appointment-time request),
                return-trip: (get return-trip request),
                special-instructions: (get special-instructions request),
                status: status,
                request-date: (get request-date request)
              })
              (ok request-id)
            )
            (err u403))
          (err u404)
        )
      )
      (err u404)
    )
  )
)
