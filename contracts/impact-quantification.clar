;; Impact Quantification Contract
;; Measures and tracks environmental restoration benefits

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_IMPACT_NOT_FOUND (err u201))
(define-constant ERR_INVALID_METRICS (err u202))

(define-map impact-metrics
  { project-id: uint }
  {
    carbon-sequestered: uint,
    biodiversity-score: uint,
    water-quality-improvement: uint,
    soil-health-score: uint,
    area-restored: uint,
    last-updated: uint,
    verified: bool
  }
)

(define-map impact-history
  { project-id: uint, timestamp: uint }
  {
    carbon-sequestered: uint,
    biodiversity-score: uint,
    water-quality-improvement: uint,
    soil-health-score: uint,
    area-restored: uint,
    reporter: principal
  }
)

(define-public (record-impact
  (project-id uint)
  (carbon-sequestered uint)
  (biodiversity-score uint)
  (water-quality-improvement uint)
  (soil-health-score uint)
  (area-restored uint))
  (begin
    (asserts! (> carbon-sequestered u0) ERR_INVALID_METRICS)
    (asserts! (<= biodiversity-score u100) ERR_INVALID_METRICS)
    (asserts! (<= water-quality-improvement u100) ERR_INVALID_METRICS)
    (asserts! (<= soil-health-score u100) ERR_INVALID_METRICS)

    (map-set impact-metrics
      { project-id: project-id }
      {
        carbon-sequestered: carbon-sequestered,
        biodiversity-score: biodiversity-score,
        water-quality-improvement: water-quality-improvement,
        soil-health-score: soil-health-score,
        area-restored: area-restored,
        last-updated: block-height,
        verified: false
      }
    )

    (map-set impact-history
      { project-id: project-id, timestamp: block-height }
      {
        carbon-sequestered: carbon-sequestered,
        biodiversity-score: biodiversity-score,
        water-quality-improvement: water-quality-improvement,
        soil-health-score: soil-health-score,
        area-restored: area-restored,
        reporter: tx-sender
      }
    )
    (ok true)
  )
)

(define-public (verify-impact (project-id uint))
  (let ((metrics (unwrap! (map-get? impact-metrics { project-id: project-id }) ERR_IMPACT_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set impact-metrics
      { project-id: project-id }
      (merge metrics { verified: true })
    )
    (ok true)
  )
)

(define-read-only (get-impact-metrics (project-id uint))
  (map-get? impact-metrics { project-id: project-id })
)

(define-read-only (calculate-impact-score (project-id uint))
  (match (map-get? impact-metrics { project-id: project-id })
    metrics (ok (+
      (/ (get carbon-sequestered metrics) u100)
      (get biodiversity-score metrics)
      (get water-quality-improvement metrics)
      (get soil-health-score metrics)
    ))
    ERR_IMPACT_NOT_FOUND
  )
)
