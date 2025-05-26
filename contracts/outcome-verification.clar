;; Outcome Verification Contract
;; Validates final restoration project success and distributes rewards

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_PROJECT_NOT_FOUND (err u501))
(define-constant ERR_VERIFICATION_EXISTS (err u502))
(define-constant ERR_INSUFFICIENT_EVIDENCE (err u503))

(define-map project-outcomes
  { project-id: uint }
  {
    success-rating: uint,
    environmental-impact: uint,
    community-benefit: uint,
    long-term-sustainability: uint,
    total-score: uint,
    verified: bool,
    verification-date: uint,
    verifier: principal,
    reward-distributed: bool
  }
)

(define-map verification-evidence
  { project-id: uint, evidence-id: uint }
  {
    evidence-type: (string-ascii 50),
    evidence-hash: (buff 32),
    description: (string-ascii 200),
    submitted-by: principal,
    timestamp: uint
  }
)

(define-map project-rewards
  { project-id: uint }
  {
    base-reward: uint,
    performance-bonus: uint,
    total-reward: uint,
    distributed: bool
  }
)

(define-data-var evidence-counter uint u0)

(define-public (submit-verification-evidence
  (project-id uint)
  (evidence-type (string-ascii 50))
  (evidence-hash (buff 32))
  (description (string-ascii 200)))
  (let ((evidence-id (+ (var-get evidence-counter) u1)))
    (map-set verification-evidence
      { project-id: project-id, evidence-id: evidence-id }
      {
        evidence-type: evidence-type,
        evidence-hash: evidence-hash,
        description: description,
        submitted-by: tx-sender,
        timestamp: block-height
      }
    )
    (var-set evidence-counter evidence-id)
    (ok evidence-id)
  )
)

(define-public (verify-project-outcome
  (project-id uint)
  (success-rating uint)
  (environmental-impact uint)
  (community-benefit uint)
  (long-term-sustainability uint))
  (let ((total-score (+ success-rating environmental-impact community-benefit long-term-sustainability)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= success-rating u100) ERR_INSUFFICIENT_EVIDENCE)
    (asserts! (<= environmental-impact u100) ERR_INSUFFICIENT_EVIDENCE)
    (asserts! (<= community-benefit u100) ERR_INSUFFICIENT_EVIDENCE)
    (asserts! (<= long-term-sustainability u100) ERR_INSUFFICIENT_EVIDENCE)

    (map-set project-outcomes
      { project-id: project-id }
      {
        success-rating: success-rating,
        environmental-impact: environmental-impact,
        community-benefit: community-benefit,
        long-term-sustainability: long-term-sustainability,
        total-score: total-score,
        verified: true,
        verification-date: block-height,
        verifier: tx-sender,
        reward-distributed: false
      }
    )
    (ok total-score)
  )
)

(define-public (calculate-and-distribute-rewards (project-id uint))
  (let (
    (outcome (unwrap! (map-get? project-outcomes { project-id: project-id }) ERR_PROJECT_NOT_FOUND))
    (base-reward u1000)
    (performance-bonus (/ (* (get total-score outcome) u10) u100))
    (total-reward (+ base-reward performance-bonus))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (get verified outcome) ERR_PROJECT_NOT_FOUND)

    (map-set project-rewards
      { project-id: project-id }
      {
        base-reward: base-reward,
        performance-bonus: performance-bonus,
        total-reward: total-reward,
        distributed: true
      }
    )

    (map-set project-outcomes
      { project-id: project-id }
      (merge outcome { reward-distributed: true })
    )

    (ok total-reward)
  )
)

(define-read-only (get-project-outcome (project-id uint))
  (map-get? project-outcomes { project-id: project-id })
)

(define-read-only (get-project-rewards (project-id uint))
  (map-get? project-rewards { project-id: project-id })
)

(define-read-only (get-verification-evidence (project-id uint) (evidence-id uint))
  (map-get? verification-evidence { project-id: project-id, evidence-id: evidence-id })
)
