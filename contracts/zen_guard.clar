;; ZenGuard Contract
;; A meditative tool for managing digital assets

;; Constants 
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-DURATION (err u101))
(define-constant ERR-SESSION-EXISTS (err u102))
(define-constant ERR-NO-ACTIVE-SESSION (err u103))
(define-constant ERR-SESSION-NOT-COMPLETE (err u104))
(define-constant ERR-INVALID-GROUP-SIZE (err u105))
(define-constant ERR-GROUP-NOT-FOUND (err u106))
(define-constant MIN-MEDITATION-TIME u300) ;; 5 minutes in seconds
(define-constant MIN-GROUP-SIZE u2)
(define-constant MAX-GROUP-SIZE u10)

;; Data Variables
(define-map meditation-sessions
  { user: principal }
  {
    start-time: uint,
    duration: uint,
    locked-amount: uint,
    completed: bool,
    group-id: (optional uint)
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

(define-data-var next-group-id uint u0)

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
        completed: false,
        group-id: none
      }
    )
    
    (ok true)
  )
)

(define-public (create-group-session (duration uint) (amount uint))
  (let
    (
      (creator tx-sender)
      (group-id (var-get next-group-id))
    )
    (asserts! (>= duration MIN-MEDITATION-TIME) ERR-INVALID-DURATION)
    
    (try! (stx-transfer? amount creator (as-contract tx-sender)))
    
    (map-set meditation-groups
      { group-id: group-id }
      {
        creator: creator,
        members: (list creator),
        start-time: block-height,
        duration: duration,
        locked-amount: amount,
        completed: false
      }
    )

    (map-set meditation-sessions
      { user: creator }
      {
        start-time: block-height,
        duration: duration,
        locked-amount: amount,
        completed: false,
        group-id: (some group-id)
      }
    )
    
    (var-set next-group-id (+ group-id u1))
    (ok group-id)
  )
)

(define-public (join-group-session (group-id uint) (amount uint))
  (let
    (
      (user tx-sender)
      (group (unwrap! (map-get? meditation-groups { group-id: group-id }) ERR-GROUP-NOT-FOUND))
      (member-count (len (get members group)))
    )
    (asserts! (< member-count MAX-GROUP-SIZE) ERR-INVALID-GROUP-SIZE)
    (asserts! (= amount (get locked-amount group)) ERR-INVALID-DURATION)
    
    (try! (stx-transfer? amount user (as-contract tx-sender)))
    
    (map-set meditation-groups
      { group-id: group-id }
      (merge group { 
        members: (unwrap-panic (as-max-len? (append (get members group) user) u10))
      })
    )

    (map-set meditation-sessions
      { user: user }
      {
        start-time: (get start-time group),
        duration: (get duration group),
        locked-amount: amount,
        completed: false,
        group-id: (some group-id)
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
    (update-user-stats user (get duration session) (get locked-amount session) (is-some (get group-id session)))
    
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
    { total-sessions: u0, total-time: u0, total-locked: u0, total-group-sessions: u0 }
    (map-get? user-stats { user: user })
  )
)

(define-read-only (get-group-data (group-id uint))
  (map-get? meditation-groups { group-id: group-id })
)

;; Private Functions
(define-private (update-user-stats (user principal) (duration uint) (amount uint) (is-group bool))
  (let
    (
      (current-stats (get-user-stats user))
    )
    (map-set user-stats
      { user: user }
      {
        total-sessions: (+ (get total-sessions current-stats) u1),
        total-time: (+ (get total-time current-stats) duration),
        total-locked: (+ (get total-locked current-stats) amount),
        total-group-sessions: (+ (get total-group-sessions current-stats) (if is-group u1 u0))
      }
    )
  )
)
