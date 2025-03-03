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
(define-constant ERR-COOLDOWN-ACTIVE (err u109))
(define-constant ERR-AMOUNT-TOO-HIGH (err u110))

;; Enhanced Constants
(define-constant MIN-MEDITATION-TIME u300) ;; 5 minutes in seconds
(define-constant MAX-MEDITATION-TIME u7200) ;; 2 hours in seconds
(define-constant SESSION-TIMEOUT u86400) ;; 24 hours in seconds
(define-constant SESSION-COOLDOWN u3600) ;; 1 hour cooldown
(define-constant MIN-GROUP-SIZE u2)
(define-constant MAX-GROUP-SIZE u10)
(define-constant MAX-LOCKED-AMOUNT u1000000000) ;; Maximum STX that can be locked

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var next-group-id uint u0)

;; Enhanced Maps
(define-map meditation-sessions
  { user: principal }
  {
    start-time: uint,
    duration: uint,
    locked-amount: uint,
    completed: bool,
    group-id: (optional uint),
    reward-multiplier: uint,
    last-session-time: uint
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
    total-group-sessions: uint,
    achievement-tier: uint
  }
)

(define-map user-achievements
  { user: principal }
  {
    longest-session: uint,
    highest-locked: uint,
    total-rewards: uint
  }
)

;; Helper Functions
(define-private (verify-session-params (duration uint) (amount uint))
  (begin
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (and (>= duration MIN-MEDITATION-TIME) (<= duration MAX-MEDITATION-TIME)) ERR-INVALID-DURATION)
    (asserts! (<= amount MAX-LOCKED-AMOUNT) ERR-AMOUNT-TOO-HIGH)
    (ok true)))

(define-private (check-cooldown (user principal))
  (let ((session (unwrap! (get-session-data user) (ok true))))
    (asserts! (> (- block-height (get last-session-time session)) SESSION-COOLDOWN) ERR-COOLDOWN-ACTIVE)
    (ok true)))

;; Enhanced Reward Calculation
(define-private (calculate-reward-multiplier (duration uint))
  (cond
    ((>= duration u7200) u150) ;; 50% bonus for 2+ hours
    ((>= duration u3600) u125) ;; 25% bonus for 1+ hour
    ((>= duration u1800) u110) ;; 10% bonus for 30+ minutes
    (true u100))) ;; Standard rate

;; Public Functions
(define-public (start-session (duration uint) (amount uint))
  (let
    (
      (user tx-sender)
      (existing-session (get-session-data user))
      (reward-multiplier (calculate-reward-multiplier duration))
    )
    (try! (verify-session-params duration amount))
    (try! (check-cooldown user))
    (asserts! (is-none existing-session) ERR-SESSION-EXISTS)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set meditation-sessions
      { user: user }
      {
        start-time: block-height,
        duration: duration,
        locked-amount: amount,
        completed: false,
        group-id: none,
        reward-multiplier: reward-multiplier,
        last-session-time: block-height
      }
    )
    
    (print { type: "new-session", user: user, duration: duration, amount: amount })
    (ok true)
  ))

[... rest of original contract functions ...]
