
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

;; New Error Codes for Commitments
(define-constant ERR-COMMITMENT-NOT-FOUND (err u109))
(define-constant ERR-INVALID-COMMITMENT (err u110))
(define-constant ERR-COMMITMENT-EXPIRED (err u111))
(define-constant ERR-ALREADY-COMMITTED (err u112))

;; New Commitment States
(define-constant COMMITMENT-ACTIVE u0)
(define-constant COMMITMENT-FULFILLED u1)
(define-constant COMMITMENT-BREACHED u2)
(define-constant COMMITMENT-EXPIRED u3)

;; Storage Commitments Map
(define-map storage-commitments
  {commitment-id: uint}
  {
    storage-id: uint,
    node: principal,
    commit-block: uint,
    duration-blocks: uint,
    expiration-block: uint,
    stake-amount: uint,
    reward-rate: uint,
    state: uint,
    verification-count: uint,
    last-verified-block: uint,
    incentive-multiplier: uint
  }
)

;; Commitment Fulfillment Records
(define-map commitment-fulfillment
  {commitment-id: uint}
  {
    fulfillment-block: uint,
    rewards-earned: uint,
    performance-score: uint,
    stake-returned: bool
  }
)

;; Global statistics variables
(define-data-var total-storage-count uint u0)
(define-data-var total-commitment-count uint u0)
(define-data-var total-active-storage-size uint u0)

;; Helper function to calculate storage node rewards
(define-read-only (calculate-rewards
  (commitment {
    storage-id: uint,
    node: principal,
    commit-block: uint,
    duration-blocks: uint,
    expiration-block: uint,
    stake-amount: uint,
    reward-rate: uint,
    state: uint,
    verification-count: uint,
    last-verified-block: uint,
    incentive-multiplier: uint
  })
  (node-reputation {
    total-storage-attempts: uint,
    successful-storage-completions: uint,
    failed-storage-tasks: uint,
    total-data-stored: uint,
    reputation-score: uint,
    last-activity-block: uint,
    verification-success-rate: uint
  })
)
  (let
    ((base-reward (* (get stake-amount commitment) (get reward-rate commitment)))
     (verification-bonus (* (get verification-count commitment) u10))
     (reputation-multiplier (/ (+ u100 (get reputation-score node-reputation)) u100))
     (incentive-bonus (* base-reward (get incentive-multiplier commitment)))
    )
    
    ;; Calculate total reward
    (/ (* (+ base-reward verification-bonus incentive-bonus) reputation-multiplier) u100)
  )
)

;; Helper function to calculate verification success rate
(define-read-only (calculate-success-rate
  (successes uint)
  (total uint)
)
  (if (> total u0)
    (/ (* successes u100) total)
    u0)
)

;; Helper function to calculate reward rate based on reputation and commitment parameters
(define-read-only (calculate-reward-rate
  (node-reputation {
    total-storage-attempts: uint,
    successful-storage-completions: uint,
    failed-storage-tasks: uint,
    total-data-stored: uint,
    reputation-score: uint,
    last-activity-block: uint,
    verification-success-rate: uint
  })
  (duration-blocks uint)
  (stake-amount uint)
)
  (let
    ((base-rate u5) ;; 5% base rate
     (duration-bonus (if (> duration-blocks u4320) u2 u0)) ;; Bonus for long-term storage (>30 days)
     (stake-bonus (if (> stake-amount u1000) u1 u0)) ;; Bonus for higher stake
     (reputation-bonus (/ (get reputation-score node-reputation) u50)) ;; Reputation-based bonus
    )
    
    (+ base-rate duration-bonus stake-bonus reputation-bonus)
  )
)

;; Helper function to calculate incentive multiplier
(define-read-only (calculate-incentive-multiplier
  (node-reputation {
    total-storage-attempts: uint,
    successful-storage-completions: uint,
    failed-storage-tasks: uint,
    total-data-stored: uint,
    reputation-score: uint,
    last-activity-block: uint,
    verification-success-rate: uint
  })
  (storage-entry {
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
  })
)
  (let
    ((size-factor (if (> (get file-size storage-entry) u1048576) u5 u2)) ;; Higher incentive for larger files (>1MB)
     (encryption-factor (if (get encryption-required (get access-control storage-entry)) u3 u1)) ;; Higher incentive for encrypted storage
    )
    
    (* size-factor encryption-factor)
  )
)

(define-read-only (get-commitment-details (commitment-id uint))
  (map-get? storage-commitments {commitment-id: commitment-id})
)

(define-read-only (get-commitment-fulfillment-details (commitment-id uint))
  (map-get? commitment-fulfillment {commitment-id: commitment-id})
)

(define-read-only (get-active-commitments-by-node (node principal))
  ;; Note: In practice, this would require an indexing mechanism or custom API
  ;; This is a placeholder for the functionality
  (ok true)
)

(define-read-only (calculate-node-total-rewards (node principal))
  ;; Note: In practice, this would require an indexing mechanism or custom API
  ;; This is a placeholder for the functionality
  (ok u0)
)