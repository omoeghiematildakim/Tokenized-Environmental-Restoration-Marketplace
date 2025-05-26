;; Funding Coordination Contract
;; Manages restoration project financing and token distribution

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INSUFFICIENT_FUNDS (err u301))
(define-constant ERR_FUNDING_NOT_FOUND (err u302))
(define-constant ERR_FUNDING_CLOSED (err u303))

(define-fungible-token restoration-token)

(define-map funding-campaigns
  { project-id: uint }
  {
    target-amount: uint,
    raised-amount: uint,
    token-price: uint,
    start-block: uint,
    end-block: uint,
    active: bool,
    project-owner: principal
  }
)

(define-map investor-contributions
  { project-id: uint, investor: principal }
  { amount-contributed: uint, tokens-received: uint }
)

(define-data-var total-supply uint u0)

(define-public (create-funding-campaign
  (project-id uint)
  (target-amount uint)
  (token-price uint)
  (duration-blocks uint))
  (begin
    (map-set funding-campaigns
      { project-id: project-id }
      {
        target-amount: target-amount,
        raised-amount: u0,
        token-price: token-price,
        start-block: block-height,
        end-block: (+ block-height duration-blocks),
        active: true,
        project-owner: tx-sender
      }
    )
    (ok project-id)
  )
)

(define-public (contribute-to-project (project-id uint) (amount uint))
  (let (
    (campaign (unwrap! (map-get? funding-campaigns { project-id: project-id }) ERR_FUNDING_NOT_FOUND))
    (tokens-to-mint (/ amount (get token-price campaign)))
    (current-contribution (default-to
      { amount-contributed: u0, tokens-received: u0 }
      (map-get? investor-contributions { project-id: project-id, investor: tx-sender })
    ))
  )
    (asserts! (get active campaign) ERR_FUNDING_CLOSED)
    (asserts! (<= block-height (get end-block campaign)) ERR_FUNDING_CLOSED)

    ;; Update campaign
    (map-set funding-campaigns
      { project-id: project-id }
      (merge campaign {
        raised-amount: (+ (get raised-amount campaign) amount)
      })
    )

    ;; Update investor contribution
    (map-set investor-contributions
      { project-id: project-id, investor: tx-sender }
      {
        amount-contributed: (+ (get amount-contributed current-contribution) amount),
        tokens-received: (+ (get tokens-received current-contribution) tokens-to-mint)
      }
    )

    ;; Mint tokens
    (try! (ft-mint? restoration-token tokens-to-mint tx-sender))
    (var-set total-supply (+ (var-get total-supply) tokens-to-mint))

    (ok tokens-to-mint)
  )
)

(define-public (close-funding-campaign (project-id uint))
  (let ((campaign (unwrap! (map-get? funding-campaigns { project-id: project-id }) ERR_FUNDING_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get project-owner campaign)) ERR_UNAUTHORIZED)
    (map-set funding-campaigns
      { project-id: project-id }
      (merge campaign { active: false })
    )
    (ok true)
  )
)

(define-read-only (get-funding-campaign (project-id uint))
  (map-get? funding-campaigns { project-id: project-id })
)

(define-read-only (get-investor-contribution (project-id uint) (investor principal))
  (map-get? investor-contributions { project-id: project-id, investor: investor })
)

(define-read-only (get-token-balance (account principal))
  (ft-get-balance restoration-token account)
)
