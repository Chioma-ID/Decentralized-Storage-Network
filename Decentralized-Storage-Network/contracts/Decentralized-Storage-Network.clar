
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

