# MICROLEND - Microfinance DeFi Platform

## Overview

MICROLEND is a blockchain-based **peer-to-peer microfinance platform** designed to provide affordable financial services to underbanked populations. It incorporates flexible repayment structures, community guarantors, and credit scoring to promote financial inclusion. This project aligns with **UN SDG 1: No Poverty**.

## Features

* Borrower and lender registration with detailed profiles
* Loan requests with guarantor commitments and funding deadlines
* Direct loan funding from lenders to borrowers with platform fees
* Weekly repayment schedules with late fee handling
* Automated borrower credit scoring and eligibility checks
* Community guarantor tracking and lending circles
* Financial education participation tracking
* Platform-wide statistics and transparency

## Data Structures

* **borrowers** – Borrower profiles with credit score, history, and guarantor network
* **lenders** – Lender profiles with lending history, preferences, and activity
* **microloans** – Active and past loan records with repayment status
* **loan-payments** – Individual loan repayment records with timing and penalties
* **guarantors** – Community guarantor profiles with exposure and reputation
* **loan-requests** – Borrower loan requests pending lender funding
* **lending-circles** – Group lending structures with pooled contributions
* **education-records** – Financial education participation and certificates

## Loan Lifecycle

1. Borrower registers and submits a loan request
2. Lender funds the request (loan created, funds transferred)
3. Borrower makes weekly repayments
4. System tracks payments, missed deadlines, late fees, and status updates
5. Borrower’s credit score adjusts based on repayment behavior

## Key Functions

### Registration

* `register-borrower(...)` – Register as a borrower with personal and financial details
* `register-lender(...)` – Register as a lender with preferences and lending limits

### Loan Management

* `request-loan(...)` – Submit a loan request with guarantors
* `fund-loan(request-id)` – Lender funds a borrower’s loan request
* `make-payment(loan-id, payment-amount)` – Borrower makes weekly repayments

### Read-Only Queries

* `get-borrower-info(borrower)` – Fetch borrower details
* `get-lender-info(lender)` – Fetch lender details
* `get-loan-info(loan-id)` – Fetch loan details
* `check-loan-eligibility(borrower, amount)` – Check borrower’s loan eligibility
* `get-platform-stats()` – Get platform-wide statistics

### Administration

* `update-platform-fee(new-fee-rate)` – Owner can update platform fee rate

## Loan Status

* `STATUS-PENDING` (0)
* `STATUS-ACTIVE` (1)
* `STATUS-REPAID` (2)
* `STATUS-DEFAULTED` (3)
* `STATUS-RESTRUCTURED` (4)

## Borrower Categories

* Individual
* Small Business
* Farming
* Education
* Women Entrepreneur

## Error Codes

* `ERR-NOT-AUTHORIZED (100)` – Unauthorized action
* `ERR-INVALID-AMOUNT (101)` – Invalid loan or repayment amount
* `ERR-INSUFFICIENT-FUNDS (102)` – Insufficient balance or eligibility
* `ERR-BORROWER-NOT-FOUND (103)` – Borrower not registered
* `ERR-LENDER-NOT-FOUND (104)` – Lender not registered
* `ERR-LOAN-NOT-FOUND (105)` – Loan does not exist
* `ERR-ALREADY-REGISTERED (106)` – User already registered
* `ERR-LOAN-ACTIVE (107)` – Loan already active
* `ERR-PAYMENT-OVERDUE (108)` – Payment overdue
* `ERR-INSUFFICIENT-COLLATERAL (109)` – Not enough collateral
* `ERR-INVALID-GUARANTOR (110)` – Guarantor invalid or not allowed
* `ERR-LOAN-DEFAULTED (111)` – Loan already defaulted

## Financial Parameters

* Minimum Loan: **1 STX**
* Maximum Loan: **50 STX**
* Interest Rate: **5% – 30% annual**
* Platform Fee: **2%**
* Grace Period: **~30 days**
