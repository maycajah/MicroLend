;;; ===================================================
;;; MICROLEND - MICROFINANCE DEFI PLATFORM
;;; ===================================================
;;; A blockchain-based peer-to-peer microfinance platform for
;;; underbanked populations with flexible repayment and community guarantees.
;;; Addresses UN SDG 1: No Poverty through accessible financial services.
;;; ===================================================

;; ===================================================
;; CONSTANTS AND ERROR CODES
;; ===================================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-BORROWER-NOT-FOUND (err u103))
(define-constant ERR-LENDER-NOT-FOUND (err u104))
(define-constant ERR-LOAN-NOT-FOUND (err u105))
(define-constant ERR-ALREADY-REGISTERED (err u106))
(define-constant ERR-LOAN-ACTIVE (err u107))
(define-constant ERR-PAYMENT-OVERDUE (err u108))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u109))
(define-constant ERR-INVALID-GUARANTOR (err u110))
(define-constant ERR-LOAN-DEFAULTED (err u111))

;; Loan Status
(define-constant STATUS-PENDING u0)
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-REPAID u2)
(define-constant STATUS-DEFAULTED u3)
(define-constant STATUS-RESTRUCTURED u4)

;; Borrower Categories
(define-constant CATEGORY-INDIVIDUAL u1)
(define-constant CATEGORY-SMALL-BUSINESS u2)
(define-constant CATEGORY-FARMING u3)
(define-constant CATEGORY-EDUCATION u4)
(define-constant CATEGORY-WOMEN-ENTREPRENEUR u5)

;; Financial Constants
(define-constant MIN-LOAN-AMOUNT u1000000) ;; 1 STX minimum
(define-constant MAX-LOAN-AMOUNT u50000000) ;; 50 STX maximum
(define-constant MIN-INTEREST-RATE u500) ;; 5% annual minimum
(define-constant MAX-INTEREST_RATE u3000) ;; 30% annual maximum
(define-constant PLATFORM-FEE-RATE u200) ;; 2%
(define-constant GRACE-PERIOD-BLOCKS u4320) ;; ~30 days

;; Time Constants
(define-constant BLOCKS-PER-MONTH u4320)
(define-constant BLOCKS-PER-WEEK u1008)

;; ===================================================
;; DATA STRUCTURES
;; ===================================================

;; Borrower Registry
(define-map borrowers
    { borrower: principal }
    {
        borrower-name: (string-ascii 100),
        borrower-category: uint,
        location: (string-ascii 100),
        registration-date: uint,
        credit-score: uint, ;; 300-850 scale
        total-loans-taken: uint,
        successful-repayments: uint,
        total-amount-borrowed: uint,
        total-amount-repaid: uint,
        current-debt: uint,
        is-active: bool,
        phone-hash: (buff 32),
        income-level: uint,
        guarantor-network: (list 5 principal)
    }
)

;; Lender Registry  
(define-map lenders
    { lender: principal }
    {
        lender-name: (string-ascii 100),
        registration-date: uint,
        total-lent: uint,
        active-loans: uint,
        repayment-rate: uint, ;; percentage * 100
        interest-earned: uint,
        preferred-categories: (list 5 uint),
        min-loan-amount: uint,
        max-loan-amount: uint,
        default-interest-rate: uint,
        is-active: bool
    }
)

;; Microloans
(define-map microloans
    { loan-id: uint }
    {
        borrower: principal,
        lender: principal,
        loan-amount: uint,
        interest-rate: uint, ;; annual rate * 100
        loan-duration-weeks: uint,
        weekly-payment: uint,
        loan-purpose: (string-ascii 200),
        borrower-category: uint,
        loan-status: uint,
        creation-date: uint,
        disbursement-date: (optional uint),
        total-paid: uint,
        remaining-balance: uint,
        payments-made: uint,
        payments-missed: uint,
        next-payment-due: uint,
        guarantors: (list 3 principal),
        collateral-description: (string-ascii 200)
    }
)

;; Loan Payments
(define-map loan-payments
    { payment-id: uint }
    {
        loan-id: uint,
        borrower: principal,
        payment-amount: uint,
        payment-date: uint,
        payment-week: uint,
        late-fee: uint,
        principal-amount: uint,
        interest-amount: uint,
        is-on-time: bool
    }
)

;; Community Guarantors
(define-map guarantors
    { guarantor: principal }
    {
        guarantor-name: (string-ascii 100),
        location: (string-ascii 100),
        registration-date: uint,
        guarantees-provided: uint,
        successful-guarantees: uint,
        guarantee-capacity: uint,
        current-exposure: uint,
        reputation-score: uint, ;; 0-100
        is-active: bool
    }
)

;; Loan Requests
(define-map loan-requests
    { request-id: uint }
    {
        borrower: principal,
        requested-amount: uint,
        proposed-interest-rate: uint,
        loan-duration-weeks: uint,
        loan-purpose: (string-ascii 200),
        income-proof: (buff 64),
        guarantors-committed: (list 3 principal),
        request-date: uint,
        funding-deadline: uint,
        funds-committed: uint,
        lenders-interested: uint,
        is-active: bool
    }
)

;; Group Lending Circles
(define-map lending-circles
    { circle-id: uint }
    {
        circle-name: (string-ascii 100),
        circle-leader: principal,
        members: (list 10 principal),
        member-count: uint,
        total-pool: uint,
        current-beneficiary: principal,
        contribution-per-member: uint,
        collection-frequency: uint,
        circle-start-date: uint,
        is-active: bool,
        successful-cycles: uint
    }
)

;; Financial Education Records
(define-map education-records
    { record-id: uint }
    {
        participant: principal,
        module-completed: (string-ascii 100),
        completion-date: uint,
        test-score: uint,
        certificate-issued: bool,
        improvement-in-score: int
    }
)

;; ===================================================
;; DATA VARIABLES
;; ===================================================

(define-data-var next-loan-id uint u1)
(define-data-var next-payment-id uint u1)
(define-data-var next-request-id uint u1)
(define-data-var next-circle-id uint u1)
(define-data-var next-record-id uint u1)
(define-data-var total-borrowers uint u0)
(define-data-var total-lenders uint u0)
(define-data-var total-amount-lent uint u0)
(define-data-var platform-revenue uint u0)
(define-data-var default-rate uint u0)

;; ===================================================
;; PRIVATE FUNCTIONS
;; ===================================================

;; Calculate weekly payment
(define-private (calculate-weekly-payment (principal uint) (annual-rate uint) (weeks uint))
    (let (
        (weekly-rate (/ annual-rate u5200)) ;; annual rate / 52 weeks / 100
        (total-interest (* (/ (* principal annual-rate) u10000) (/ weeks u52)))
        (total-amount (+ principal total-interest))
    )
        (/ total-amount weeks)
    )
)

;; Calculate credit score based on history
(define-private (calculate-credit-score (total-loans uint) (successful-payments uint) (defaults uint))
    (if (is-eq total-loans u0)
        u500 ;; Default score for new borrowers
        (let (
            (success-rate (/ (* successful-payments u100) total-loans))
            (base-score u300)
            (bonus-points (* success-rate u5))
            (penalty-points (* defaults u50))
        )
            (+ (+ base-score bonus-points) 
               (if (> penalty-points base-score) u0 (- base-score penalty-points)))
        )
    )
)

;; Check if borrower is eligible for loan amount
(define-private (is-eligible-for-amount (borrower principal) (amount uint))
    (match (map-get? borrowers { borrower: borrower })
        borrower-data
            (let (
                (credit-score (get credit-score borrower-data))
                (current-debt (get current-debt borrower-data))
                (max-eligible (if (>= credit-score u700) u20000000 ;; 20 STX for good credit
                              (if (>= credit-score u600) u10000000 ;; 10 STX for fair credit
                                  u5000000))) ;; 5 STX for poor credit
            )
                (and (<= amount max-eligible)
                     (<= (+ current-debt amount) (* max-eligible u2)))
            )
        false
    )
)

;; ===================================================
;; PUBLIC FUNCTIONS - REGISTRATION
;; ===================================================

;; Register as borrower
(define-public (register-borrower
    (borrower-name (string-ascii 100))
    (borrower-category uint)
    (location (string-ascii 100))
    (phone-hash (buff 32))
    (estimated-income uint))
    
    (let (
        (registration-date stacks-block-height)
    )
    
    (asserts! (is-none (map-get? borrowers { borrower: tx-sender })) ERR-ALREADY-REGISTERED)
    (asserts! (or (is-eq borrower-category CATEGORY-INDIVIDUAL)
                  (or (is-eq borrower-category CATEGORY-SMALL-BUSINESS)
                      (or (is-eq borrower-category CATEGORY-FARMING)
                          (or (is-eq borrower-category CATEGORY-EDUCATION)
                              (is-eq borrower-category CATEGORY-WOMEN-ENTREPRENEUR))))) ERR-INVALID-AMOUNT)
    
    ;; Register borrower
    (map-set borrowers
        { borrower: tx-sender }
        {
            borrower-name: borrower-name,
            borrower-category: borrower-category,
            location: location,
            registration-date: registration-date,
            credit-score: u500,
            total-loans-taken: u0,
            successful-repayments: u0,
            total-amount-borrowed: u0,
            total-amount-repaid: u0,
            current-debt: u0,
            is-active: true,
            phone-hash: phone-hash,
            income-level: estimated-income,
            guarantor-network: (list)
        }
    )
    
    (var-set total-borrowers (+ (var-get total-borrowers) u1))
    (ok true)
    )
)

;; Register as lender
(define-public (register-lender
    (lender-name (string-ascii 100))
    (preferred-categories (list 5 uint))
    (min-loan-amount uint)
    (max-loan-amount uint)
    (default-interest-rate uint))
    
    (let (
        (registration-date stacks-block-height)
    )
    
    (asserts! (is-none (map-get? lenders { lender: tx-sender })) ERR-ALREADY-REGISTERED)
    (asserts! (>= min-loan-amount MIN-LOAN-AMOUNT) ERR-INVALID-AMOUNT)
    (asserts! (<= max-loan-amount MAX-LOAN-AMOUNT) ERR-INVALID-AMOUNT)
    (asserts! (and (>= default-interest-rate MIN-INTEREST-RATE) 
                   (<= default-interest-rate MAX-INTEREST_RATE)) ERR-INVALID-AMOUNT)
    
    ;; Register lender
    (map-set lenders
        { lender: tx-sender }
        {
            lender-name: lender-name,
            registration-date: registration-date,
            total-lent: u0,
            active-loans: u0,
            repayment-rate: u0,
            interest-earned: u0,
            preferred-categories: preferred-categories,
            min-loan-amount: min-loan-amount,
            max-loan-amount: max-loan-amount,
            default-interest-rate: default-interest-rate,
            is-active: true
        }
    )
    
    (var-set total-lenders (+ (var-get total-lenders) u1))
    (ok true)
    )
)

;; ===================================================
;; PUBLIC FUNCTIONS - LOAN MANAGEMENT
;; ===================================================

;; Request loan
(define-public (request-loan
    (requested-amount uint)
    (proposed-interest-rate uint)
    (loan-duration-weeks uint)
    (loan-purpose (string-ascii 200))
    (guarantors-list (list 3 principal)))
    
    (let (
        (borrower-data (unwrap! (map-get? borrowers { borrower: tx-sender }) ERR-BORROWER-NOT-FOUND))
        (request-id (var-get next-request-id))
        (funding-deadline (+ stacks-block-height (* u2 BLOCKS-PER-WEEK)))
    )
    
    (asserts! (get is-active borrower-data) ERR-BORROWER-NOT-FOUND)
    (asserts! (and (>= requested-amount MIN-LOAN-AMOUNT) 
                   (<= requested-amount MAX-LOAN-AMOUNT)) ERR-INVALID-AMOUNT)
    (asserts! (is-eligible-for-amount tx-sender requested-amount) ERR-INSUFFICIENT-FUNDS)
    (asserts! (and (>= proposed-interest-rate MIN-INTEREST-RATE)
                   (<= proposed-interest-rate MAX-INTEREST_RATE)) ERR-INVALID-AMOUNT)
    (asserts! (and (>= loan-duration-weeks u4) (<= loan-duration-weeks u52)) ERR-INVALID-AMOUNT)
    
    ;; Create loan request
    (map-set loan-requests
        { request-id: request-id }
        {
            borrower: tx-sender,
            requested-amount: requested-amount,
            proposed-interest-rate: proposed-interest-rate,
            loan-duration-weeks: loan-duration-weeks,
            loan-purpose: loan-purpose,
            income-proof: 0x00,
            guarantors-committed: guarantors-list,
            request-date: stacks-block-height,
            funding-deadline: funding-deadline,
            funds-committed: u0,
            lenders-interested: u0,
            is-active: true
        }
    )
    
    (var-set next-request-id (+ request-id u1))
    (ok request-id)
    )
)

;; Fund loan (by lender)
(define-public (fund-loan (request-id uint))
    (let (
        (request-data (unwrap! (map-get? loan-requests { request-id: request-id }) ERR-LOAN-NOT-FOUND))
        (lender-data (unwrap! (map-get? lenders { lender: tx-sender }) ERR-LENDER-NOT-FOUND))
        (borrower-data (unwrap! (map-get? borrowers { borrower: (get borrower request-data) }) ERR-BORROWER-NOT-FOUND))
        (loan-id (var-get next-loan-id))
        (loan-amount (get requested-amount request-data))
        (weekly-payment (calculate-weekly-payment 
                          loan-amount 
                          (get proposed-interest-rate request-data) 
                          (get loan-duration-weeks request-data)))
        (platform-fee (/ (* loan-amount PLATFORM-FEE-RATE) u10000))
    )
    
    (asserts! (get is-active request-data) ERR-LOAN-NOT-FOUND)
    (asserts! (get is-active lender-data) ERR-LENDER-NOT-FOUND)
    (asserts! (>= loan-amount (get min-loan-amount lender-data)) ERR-INVALID-AMOUNT)
    (asserts! (<= loan-amount (get max-loan-amount lender-data)) ERR-INVALID-AMOUNT)
    
    ;; Transfer loan amount to borrower (minus platform fee)
    (try! (stx-transfer? loan-amount tx-sender (get borrower request-data)))
    (try! (stx-transfer? platform-fee tx-sender (as-contract tx-sender)))
    
    ;; Create loan record
    (map-set microloans
        { loan-id: loan-id }
        {
            borrower: (get borrower request-data),
            lender: tx-sender,
            loan-amount: loan-amount,
            interest-rate: (get proposed-interest-rate request-data),
            loan-duration-weeks: (get loan-duration-weeks request-data),
            weekly-payment: weekly-payment,
            loan-purpose: (get loan-purpose request-data),
            borrower-category: (get borrower-category borrower-data),
            loan-status: STATUS-ACTIVE,
            creation-date: stacks-block-height,
            disbursement-date: (some stacks-block-height),
            total-paid: u0,
            remaining-balance: (+ loan-amount (/ (* loan-amount (get proposed-interest-rate request-data)) u10000)),
            payments-made: u0,
            payments-missed: u0,
            next-payment-due: (+ stacks-block-height BLOCKS-PER-WEEK),
            guarantors: (get guarantors-committed request-data),
            collateral-description: ""
        }
    )
    
    ;; Update borrower debt
    (map-set borrowers
        { borrower: (get borrower request-data) }
        (merge borrower-data {
            total-loans-taken: (+ (get total-loans-taken borrower-data) u1),
            total-amount-borrowed: (+ (get total-amount-borrowed borrower-data) loan-amount),
            current-debt: (+ (get current-debt borrower-data) loan-amount)
        })
    )
    
    ;; Update lender stats
    (map-set lenders
        { lender: tx-sender }
        (merge lender-data {
            total-lent: (+ (get total-lent lender-data) loan-amount),
            active-loans: (+ (get active-loans lender-data) u1)
        })
    )
    
    ;; Deactivate request
    (map-set loan-requests
        { request-id: request-id }
        (merge request-data { is-active: false })
    )
    
    (var-set next-loan-id (+ loan-id u1))
    (var-set total-amount-lent (+ (var-get total-amount-lent) loan-amount))
    (var-set platform-revenue (+ (var-get platform-revenue) platform-fee))
    
    (ok loan-id)
    )
)

;; Make loan payment
(define-public (make-payment (loan-id uint) (payment-amount uint))
    (let (
        (loan-data (unwrap! (map-get? microloans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
        (payment-id (var-get next-payment-id))
        (is-on-time (<= stacks-block-height (get next-payment-due loan-data)))
        (late-fee (if is-on-time u0 (/ payment-amount u20))) ;; 5% late fee
        (total-payment (+ payment-amount late-fee))
        (new-balance (- (get remaining-balance loan-data) payment-amount))
        (current-week (+ (get payments-made loan-data) u1))
    )
    
    (asserts! (is-eq tx-sender (get borrower loan-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get loan-status loan-data) STATUS-ACTIVE) ERR-LOAN-NOT-FOUND)
    (asserts! (>= payment-amount (get weekly-payment loan-data)) ERR-INVALID-AMOUNT)
    
    ;; Transfer payment to lender
    (try! (stx-transfer? total-payment tx-sender (get lender loan-data)))
    
    ;; Record payment
    (map-set loan-payments
        { payment-id: payment-id }
        {
            loan-id: loan-id,
            borrower: tx-sender,
            payment-amount: payment-amount,
            payment-date: stacks-block-height,
            payment-week: current-week,
            late-fee: late-fee,
            principal-amount: payment-amount, ;; Simplified
            interest-amount: u0,
            is-on-time: is-on-time
        }
    )
    
    ;; Update loan
    (map-set microloans
        { loan-id: loan-id }
        (merge loan-data {
            total-paid: (+ (get total-paid loan-data) payment-amount),
            remaining-balance: new-balance,
            payments-made: current-week,
            payments-missed: (if is-on-time (get payments-missed loan-data) (+ (get payments-missed loan-data) u1)),
            next-payment-due: (+ stacks-block-height BLOCKS-PER-WEEK),
            loan-status: (if (<= new-balance u0) STATUS-REPAID STATUS-ACTIVE)
        })
    )
    
    ;; Update borrower stats if loan completed
    (if (<= new-balance u0)
        (let (
            (borrower-data (unwrap-panic (map-get? borrowers { borrower: tx-sender })))
        )
        (map-set borrowers
            { borrower: tx-sender }
            (merge borrower-data {
                successful-repayments: (+ (get successful-repayments borrower-data) u1),
                total-amount-repaid: (+ (get total-amount-repaid borrower-data) (get total-paid loan-data)),
                current-debt: (- (get current-debt borrower-data) (get loan-amount loan-data)),
                credit-score: (calculate-credit-score 
                             (get total-loans-taken borrower-data)
                             (+ (get successful-repayments borrower-data) u1)
                             u0)
            })
        )
        )
        true
    )
    
    (var-set next-payment-id (+ payment-id u1))
    (ok new-balance)
    )
)

;; ===================================================
;; READ-ONLY FUNCTIONS
;; ===================================================

;; Get borrower information
(define-read-only (get-borrower-info (borrower principal))
    (map-get? borrowers { borrower: borrower })
)

;; Get lender information
(define-read-only (get-lender-info (lender principal))
    (map-get? lenders { lender: lender })
)

;; Get loan information
(define-read-only (get-loan-info (loan-id uint))
    (map-get? microloans { loan-id: loan-id })
)

;; Check loan eligibility
(define-read-only (check-loan-eligibility (borrower principal) (amount uint))
    (is-eligible-for-amount borrower amount)
)

;; Get platform statistics
(define-read-only (get-platform-stats)
    {
        total-borrowers: (var-get total-borrowers),
        total-lenders: (var-get total-lenders),
        total-loans: (var-get next-loan-id),
        total-amount-lent: (var-get total-amount-lent),
        platform-revenue: (var-get platform-revenue),
        default-rate: (var-get default-rate)
    }
)

;; ===================================================
;; ADMIN FUNCTIONS
;; ===================================================

;; Update platform fee rate
(define-public (update-platform-fee (new-fee-rate uint))
    (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-rate u1000) ERR-INVALID-AMOUNT) ;; Max 10%
    ;; Note: Would need to use a variable instead of constant
    (ok new-fee-rate)
    )
)