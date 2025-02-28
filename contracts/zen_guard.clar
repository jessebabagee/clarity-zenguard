;; ZenGuard Contract
;; A meditative tool for managing digital assets

;; Constants 
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-DURATION (err u101))
(define-constant ERR-SESSION-EXISTS (err u102))
(define-constant ERR-NO-ACTIVE-SESSION (err u103))
(define-constant ERR-SESSION-NOT-COMPLETE (err u104))
(define-constant ERR-INVALID-GROUP-SIZE (err u105))
(define-constant ERR-GROUP-NOT-FOUND (err u106))
(define-constant ERR-SESSION-EXPIRED (err u107))
(define-constant ERR-CONTRACT-PAUSED (err u108))

(define-constant MIN-MEDITATION-TIME u300) ;; 5 minutes in seconds
(define-constant MAX-MEDITATION-TIME u7200) ;; 2 hours in seconds
(define-constant SESSION-TIMEOUT u86400) ;; 24 hours in seconds
(define-constant MIN-GROUP-SIZE u2)
(define-constant MAX-GROUP-SIZE u10)

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var next-group-id uint u0)

;; Maps
(define-map meditation-sessions
  { user: principal }
  {
    start-time: uint,
    duration: uint,
    locked-amount: uint,
    completed: bool,
    group-id: (optional uint),
    reward-multiplier: uint
  }
)

(define-map meditation-groups
  { group-id: uint }
  {
    creator: principal,
    members: (list 10 principal),
    start-time: uint,
    duration: uint,
    locked-amount: uint,
    completed: bool
  }
)

(define-map user-stats
  { user: principal }
  {
    total-sessions: uint,
    total-time: uint,
    total-locked: uint,
    total-group-sessions: uint
  }
)

;; Administrative Functions
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused true)
    (ok true)))

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused false)
    (ok true)))

(define-public (emergency-withdraw (user principal))
  (let
    ((session (unwrap! (get-session-data user) ERR-NO-ACTIVE-SESSION)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (- block-height (get start-time session)) SESSION-TIMEOUT) ERR-SESSION-NOT-COMPLETE)
    
    (try! (as-contract (stx-transfer? (get locked-amount session) tx-sender user)))
    
    (map-set meditation-sessions
      { user: user }
      (merge session { completed: true })
    )
    (ok true)
  ))

;; Public Functions
(define-public (start-session (duration uint) (amount uint))
  (let
    (
      (user tx-sender)
      (existing-session (get-session-data user))
      (reward-multiplier (calculate-reward-multiplier duration))
    )
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (is-none existing-session) ERR-SESSION-EXISTS)
    (asserts! (and (>= duration MIN-MEDITATION-TIME) (<= duration MAX-MEDITATION-TIME)) ERR-INVALID-DURATION)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set meditation-sessions
      { user: user }
      {
        start-time: block-height,
        duration: duration,
        locked-amount: amount,
        completed: false,
        group-id: none,
        reward-multiplier: reward-multiplier
      }
    )
    
    (print { type: "new-session", user: user, duration: duration, amount: amount })
    (ok true)
  ))

[... rest of the original contract functions ...]

;; Private Functions
(define-private (calculate-reward-multiplier (duration uint))
  (if (>= duration u3600)
    u120  ;; 20% bonus for sessions >= 1 hour
    u100  ;; Standard rate
  ))
