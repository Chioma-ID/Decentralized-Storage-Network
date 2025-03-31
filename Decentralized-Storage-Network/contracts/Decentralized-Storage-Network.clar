
;; Constants and Error Codes
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-FUNDS (err u101))
(define-constant ERR-STORAGE-NOT-FOUND (err u102))
(define-constant ERR-INVALID-STORAGE-STATE (err u103))
(define-constant ERR-VERIFICATION-FAILED (err u104))
(define-constant ERR-DUPLICATE-STORAGE (err u105))
(define-constant ERR-STORAGE-LIMIT-EXCEEDED (err u106))
(define-constant ERR-ENCRYPTION-FAILED (err u107))
(define-constant ERR-RETRIEVAL-FAILED (err u108))

;; Storage States
(define-constant STORAGE-INITIAL u0)
(define-constant STORAGE-UPLOADED u1)
(define-constant STORAGE-VERIFIED u2)
(define-constant STORAGE-CHALLENGED u3)
(define-constant STORAGE-ARCHIVED u4)

;; Advanced Storage Entry Structure
(define-map storage-entries
  {storage-id: uint}
  {
    uploader: principal,
    file-hash: (buff 32),
    encryption-key: (optional (buff 32)),
    file-size: uint,
    storage-nodes: (list 10 principal),
    state: uint,
    upload-timestamp: uint,
    expiration-block: uint,
    access-control: {
      public-access: bool,
      allowed-principals: (list 10 principal),
      encryption-required: bool
    },
    metadata: {
      file-type: (string-utf8 50),
      category: (string-utf8 50),
      tags: (list 5 (string-utf8 30))
    }
  }
)

;; Storage Node Reputation System
(define-map storage-node-reputation
  principal
  {
    total-storage-attempts: uint,
    successful-storage-completions: uint,
    failed-storage-tasks: uint,
    total-data-stored: uint,
    reputation-score: uint,
    last-activity-block: uint,
    verification-success-rate: uint
  }
)

;; Storage Node Stake Tracking
(define-map storage-node-stakes
  principal
  {
    total-stake: uint,
    active-storage-commitments: uint,
    last-stake-block: uint
  }
)

;; File Access Logs
(define-map file-access-logs
  {storage-id: uint, accessor: principal}
  {
    access-timestamp: uint,
    access-type: (string-utf8 20)
  }
)

;; Storage Node Registration
(define-public (register-storage-node 
  (initial-stake uint)
  (node-capabilities (list 5 (string-utf8 50)))
)
  (begin
    ;; Validate initial stake
    (asserts! (> initial-stake u100) ERR-INSUFFICIENT-FUNDS)
    
    ;; Register storage node with initial reputation
    (map-set storage-node-reputation 
      tx-sender
      {
        total-storage-attempts: u0,
        successful-storage-completions: u0,
        failed-storage-tasks: u0,
        total-data-stored: u0,
        reputation-score: u50,
        last-activity-block: stacks-block-height,
        verification-success-rate: u0
      }
    )
    
    ;; Track node stakes
    (map-set storage-node-stakes 
      tx-sender
      {
        total-stake: initial-stake,
        active-storage-commitments: u0,
        last-stake-block: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; Verification Mechanism for Stored Files
(define-public (verify-file-storage 
  (storage-id uint)
  (verification-hash (buff 32))
)
  (let 
    ((storage-entry (unwrap! (map-get? storage-entries {storage-id: storage-id}) ERR-STORAGE-NOT-FOUND))
     (original-hash (get file-hash storage-entry))
     (current-state (get state storage-entry))
    )
    
    ;; Verification conditions
    (asserts! (is-eq current-state STORAGE-UPLOADED) ERR-INVALID-STORAGE-STATE)
    (asserts! (is-eq verification-hash original-hash) ERR-VERIFICATION-FAILED)
    
    ;; Update storage state
    (map-set storage-entries 
      {storage-id: storage-id}
      (merge storage-entry {
        state: STORAGE-VERIFIED
      })
    )
    
    (ok true)
  )
)

;; Archiving Mechanism for Expired Storage
(define-public (archive-storage (storage-id uint))
  (let 
    ((storage-entry (unwrap! (map-get? storage-entries {storage-id: storage-id}) ERR-STORAGE-NOT-FOUND))
     (current-state (get state storage-entry))
     (expiration-block (get expiration-block storage-entry))
    )
    
    ;; Archiving conditions
    (asserts! (>= stacks-block-height expiration-block) ERR-UNAUTHORIZED)
    
    ;; Update storage state
    (map-set storage-entries 
      {storage-id: storage-id}
      (merge storage-entry {
        state: STORAGE-ARCHIVED
      })
    )
    
    (ok true)
  )
)

;; Read-only Functions for Retrieving Information
(define-read-only (get-storage-details (storage-id uint))
  (map-get? storage-entries {storage-id: storage-id})
)

(define-read-only (get-storage-node-reputation (node principal))
  (map-get? storage-node-reputation node)
)

(define-read-only (get-file-access-log (storage-id uint) (accessor principal))
  (map-get? file-access-logs {storage-id: storage-id, accessor: accessor})
)

