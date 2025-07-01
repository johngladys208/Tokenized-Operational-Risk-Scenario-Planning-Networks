;; Scenario Planner Verification Contract
;; Validates and manages operational scenario planners

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_CREDENTIALS (err u103))

;; Data structures
(define-map verified-planners
  { planner: principal }
  {
    verified-at: uint,
    credentials-hash: (buff 32),
    specialization: (string-ascii 50),
    reputation-score: uint,
    active: bool
  }
)

(define-map planner-applications
  { applicant: principal }
  {
    applied-at: uint,
    credentials-hash: (buff 32),
    specialization: (string-ascii 50),
    status: (string-ascii 20)
  }
)

(define-data-var next-planner-id uint u1)
(define-data-var total-verified-planners uint u0)

;; Public functions
(define-public (apply-for-verification (credentials-hash (buff 32)) (specialization (string-ascii 50)))
  (let ((applicant tx-sender))
    (asserts! (is-none (map-get? planner-applications { applicant: applicant })) ERR_ALREADY_VERIFIED)
    (map-set planner-applications
      { applicant: applicant }
      {
        applied-at: block-height,
        credentials-hash: credentials-hash,
        specialization: specialization,
        status: "pending"
      }
    )
    (ok true)
  )
)

(define-public (verify-planner (planner principal) (credentials-hash (buff 32)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? verified-planners { planner: planner })) ERR_ALREADY_VERIFIED)

    (match (map-get? planner-applications { applicant: planner })
      application (begin
        (map-set verified-planners
          { planner: planner }
          {
            verified-at: block-height,
            credentials-hash: credentials-hash,
            specialization: (get specialization application),
            reputation-score: u100,
            active: true
          }
        )
        (map-set planner-applications
          { applicant: planner }
          (merge application { status: "approved" })
        )
        (var-set total-verified-planners (+ (var-get total-verified-planners) u1))
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (update-reputation (planner principal) (new-score uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? verified-planners { planner: planner })
      planner-data (begin
        (map-set verified-planners
          { planner: planner }
          (merge planner-data { reputation-score: new-score })
        )
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (deactivate-planner (planner principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? verified-planners { planner: planner })
      planner-data (begin
        (map-set verified-planners
          { planner: planner }
          (merge planner-data { active: false })
        )
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

;; Read-only functions
(define-read-only (is-verified-planner (planner principal))
  (match (map-get? verified-planners { planner: planner })
    planner-data (get active planner-data)
    false
  )
)

(define-read-only (get-planner-info (planner principal))
  (map-get? verified-planners { planner: planner })
)

(define-read-only (get-application-status (applicant principal))
  (map-get? planner-applications { applicant: applicant })
)

(define-read-only (get-total-verified-planners)
  (var-get total-verified-planners)
)
