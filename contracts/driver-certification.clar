;; Driver Certification Contract
;; Confirms training for medical transport

;; Define data variables
(define-data-var last-driver-id uint u0)
(define-data-var last-certification-id uint u0)

;; Map to store driver details
(define-map drivers
  { id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    license-expiry: uint,
    medical-training: (string-ascii 200),
    cpr-certified: bool,
    first-aid-certified: bool,
    special-training: (string-ascii 200),
    certification-status: (string-ascii 20),
    registration-date: uint
  }
)

;; Map to store certification records
(define-map certifications
  { id: uint }
  {
    driver-id: uint,
    certifier: principal,
    certification-type: (string-ascii 50),
    issue-date: uint,
    expiry-date: uint,
    certification-details: (string-ascii 200)
  }
)

;; Get the last assigned driver ID
(define-read-only (get-last-driver-id)
  (ok (var-get last-driver-id))
)

;; Get driver details by ID
(define-read-only (get-driver (id uint))
  (map-get? drivers { id: id })
)

;; Register a new driver
(define-public (register-driver
    (name (string-ascii 100))
    (license-number (string-ascii 50))
    (license-expiry uint)
    (medical-training (string-ascii 200))
    (cpr-certified bool)
    (first-aid-certified bool)
    (special-training (string-ascii 200)))
  (let
    ((new-id (+ (var-get last-driver-id) u1)))
    (var-set last-driver-id new-id)
    (map-set drivers { id: new-id } {
      owner: tx-sender,
      name: name,
      license-number: license-number,
      license-expiry: license-expiry,
      medical-training: medical-training,
      cpr-certified: cpr-certified,
      first-aid-certified: first-aid-certified,
      special-training: special-training,
      certification-status: "pending",
      registration-date: block-height
    })
    (ok new-id)
  )
)

;; Update driver information
(define-public (update-driver
    (id uint)
    (license-number (string-ascii 50))
    (license-expiry uint)
    (medical-training (string-ascii 200))
    (cpr-certified bool)
    (first-aid-certified bool)
    (special-training (string-ascii 200)))
  (let ((driver-data (map-get? drivers { id: id })))
    (match driver-data
      driver (if (is-eq tx-sender (get owner driver))
        (begin
          (map-set drivers { id: id } {
            owner: (get owner driver),
            name: (get name driver),
            license-number: license-number,
            license-expiry: license-expiry,
            medical-training: medical-training,
            cpr-certified: cpr-certified,
            first-aid-certified: first-aid-certified,
            special-training: special-training,
            certification-status: "pending",
            registration-date: (get registration-date driver)
          })
          (ok id)
        )
        (err u403))
      (err u404)
    )
  )
)

;; Add a certification for a driver
(define-public (add-certification
    (driver-id uint)
    (certification-type (string-ascii 50))
    (expiry-date uint)
    (certification-details (string-ascii 200)))
  (let ((driver-data (map-get? drivers { id: driver-id })))
    (match driver-data
      driver (let ((new-id (+ (var-get last-certification-id) u1)))
        (var-set last-certification-id new-id)
        (map-set certifications { id: new-id } {
          driver-id: driver-id,
          certifier: tx-sender,
          certification-type: certification-type,
          issue-date: block-height,
          expiry-date: expiry-date,
          certification-details: certification-details
        })

        ;; Update the driver's certification status
        (map-set drivers { id: driver-id } {
          owner: (get owner driver),
          name: (get name driver),
          license-number: (get license-number driver),
          license-expiry: (get license-expiry driver),
          medical-training: (get medical-training driver),
          cpr-certified: (get cpr-certified driver),
          first-aid-certified: (get first-aid-certified driver),
          special-training: (get special-training driver),
          certification-status: "certified",
          registration-date: (get registration-date driver)
        })

        (ok new-id)
      )
      (err u404)
    )
  )
)

;; Get certification details
(define-read-only (get-certification (id uint))
  (map-get? certifications { id: id })
)

;; Check if a driver is certified and has required training
(define-read-only (check-driver-eligibility
    (driver-id uint)
    (require-cpr bool)
    (require-first-aid bool))
  (let ((driver-data (map-get? drivers { id: driver-id })))
    (match driver-data
      driver (ok {
        eligible: (and
                    (is-eq (get certification-status driver) "certified")
                    (or (not require-cpr) (get cpr-certified driver))
                    (or (not require-first-aid) (get first-aid-certified driver))
                    (> (get license-expiry driver) block-height)
                  ),
        certification-status: (get certification-status driver)
      })
      (err u404)
    )
  )
)
