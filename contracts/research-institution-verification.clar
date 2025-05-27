;; Research Institution Verification Contract
;; Manages verification and registration of biomarker research entities

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Institution verification status
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_REJECTED u2)
(define-constant STATUS_SUSPENDED u3)

;; Data maps
(define-map institutions
  { institution-id: uint }
  {
    name: (string-ascii 100),
    contact-info: (string-ascii 200),
    verification-status: uint,
    verified-at: (optional uint),
    verifier: (optional principal)
  }
)

(define-map institution-principals
  { principal: principal }
  { institution-id: uint }
)

(define-data-var next-institution-id uint u1)

;; Register a new research institution
(define-public (register-institution (name (string-ascii 100)) (contact-info (string-ascii 200)))
  (let ((institution-id (var-get next-institution-id)))
    (asserts! (is-none (map-get? institution-principals { principal: tx-sender })) ERR_ALREADY_VERIFIED)
    (map-set institutions
      { institution-id: institution-id }
      {
        name: name,
        contact-info: contact-info,
        verification-status: STATUS_PENDING,
        verified-at: none,
        verifier: none
      }
    )
    (map-set institution-principals { principal: tx-sender } { institution-id: institution-id })
    (var-set next-institution-id (+ institution-id u1))
    (ok institution-id)
  )
)

;; Verify an institution (only contract owner)
(define-public (verify-institution (institution-id uint))
  (let ((institution (unwrap! (map-get? institutions { institution-id: institution-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get verification-status institution) STATUS_PENDING) ERR_INVALID_STATUS)
    (map-set institutions
      { institution-id: institution-id }
      (merge institution {
        verification-status: STATUS_VERIFIED,
        verified-at: (some block-height),
        verifier: (some tx-sender)
      })
    )
    (ok true)
  )
)

;; Get institution details
(define-read-only (get-institution (institution-id uint))
  (map-get? institutions { institution-id: institution-id })
)

;; Get institution ID by principal
(define-read-only (get-institution-by-principal (principal principal))
  (map-get? institution-principals { principal: principal })
)

;; Check if institution is verified
(define-read-only (is-verified-institution (institution-id uint))
  (match (map-get? institutions { institution-id: institution-id })
    institution (is-eq (get verification-status institution) STATUS_VERIFIED)
    false
  )
)
