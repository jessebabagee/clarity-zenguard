;; ZenGuard Contract
;; A meditative tool for managing digital assets

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-DURATION (err u101))
(define-constant ERR-SESSION-EXISTS (err u102))
(define-constant ERR-NO-ACTIVE-SESSION (err u103))
(define-constant ERR-SESSION-NOT-COMPLETE (err u104))
(define-constant MIN-MEDITATION-TIME u300) ;; 5 minutes in seconds

;; Data Variables
(define-map meditation-sessions
  { user: principal }
  {
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
    total-locked: uint
  }
)

;; Public Functions
(define-public (start-session (duration uint) (amount uint))
  (let
    (
      (user tx-sender)
      (existing-session (get-session-data user))
    )
    (asserts! (is-none existing-session) ERR-SESSION-EXISTS)
    (asserts! (>= duration MIN-MEDITATION-TIME) ERR-INVALID-DURATION)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set meditation-sessions
      { user: user }
      {
        start-time: block-height,
        duration: duration,
        locked-amount: amount,
        completed: false
      }
    )
    
    (ok true)
  )
)

(define-public (end-session)
  (let
    (
      (user tx-sender)
      (session (unwrap! (get-session-data user) ERR-NO-ACTIVE-SESSION))
    )
    (asserts! (>= (- block-height (get start-time session)) (get duration session)) ERR-SESSION-NOT-COMPLETE)
    
    ;; Return locked assets
    (try! (as-contract (stx-transfer? (get locked-amount session) tx-sender user)))
    
    ;; Update stats
    (update-user-stats user (get duration session) (get locked-amount session))
    
    ;; Mark session complete
    (map-set meditation-sessions
      { user: user }
      (merge session { completed: true })
    )
    
    (ok true)
  )
)

;; Read Only Functions
(define-read-only (get-session-data (user principal))
  (map-get? meditation-sessions { user: user })
)

(define-read-only (get-user-stats (user principal))
  (default-to
    { total-sessions: u0, total-time: u0, total-locked: u0 }
    (map-get? user-stats { user: user })
  )
)

;; Private Functions
(define-private (update-user-stats (user principal) (duration uint) (amount uint))
  (let
    (
      (current-stats (get-user-stats user))
    )
    (map-set user-stats
      { user: user }
      {
        total-sessions: (+ (get total-sessions current-stats) u1),
        total-time: (+ (get total-time current-stats) duration),
        total-locked: (+ (get total-locked current-stats) amount)
      }
    )
  )
)