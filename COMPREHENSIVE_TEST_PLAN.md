# SIRAPRO - Comprehensive Test Plan

## Overview
This document outlines the complete test scenarios for the Sirapro mobile application, covering the full user journey from client creation through daily settlement.

---

## Test Scenario 1: Client Creation & Assignment

### Objective
Verify that a new client can be created and automatically assigned to the authenticated user's base commerciale and zone.

### Prerequisites
- User must be logged in
- User must have valid `base_commerciale_id` and `zone_id` assigned

### Test Steps

#### 1.1 Navigate to Client Creation
- [ ] From HomePage, tap on "Clients" or "+" button
- [ ] Navigate to CreateClientPage
- [ ] Verify form loads with 3 steps (Administrative, Geographic, Visit Scheduling)

#### 1.2 Fill Administrative Data (Step 1)
- [ ] Enter client code (or use auto-generated)
- [ ] Enter business name (boutiqueName)
- [ ] Select client type (Boutique, Supermarché, Demi-grossiste, Grossiste, Distributeur, Autre)
- [ ] Enter manager name (gerantName)
- [ ] Enter phone number
- [ ] Enter WhatsApp number
- [ ] Enter email (optional)
- [ ] Tap "Next" to proceed to Step 2

#### 1.3 Fill Geographic Data (Step 2)
- [ ] Select city from dropdown (e.g., Abidjan districts)
- [ ] Select district/quartier from dynamic dropdown
- [ ] Enter address description
- [ ] Verify GPS location is auto-filled (or enter manually)
- [ ] Tap "Capture Photos" button
- [ ] Take at least one photo (facade, shelves, stock, anomaly, or other)
- [ ] Verify photo preview appears
- [ ] Tap "Next" to proceed to Step 3

#### 1.4 Fill Visit Scheduling (Step 3)
- [ ] Select visit frequency (weekly, biweekly, monthly, other)
- [ ] Select visit day (Monday-Sunday, optional)
- [ ] Select potential (A, B, C)
- [ ] Tap "Create Client" button

#### 1.5 Verify Client Creation
- [ ] Wait for API call completion
- [ ] Verify success message appears
- [ ] Verify client appears in client list
- [ ] Verify photos are uploaded successfully

### Expected Results
- Client created successfully with all data
- Client automatically assigned to user's `base_commerciale_id` and `zone_id`
- Photos uploaded and associated with client
- Client appears in user's client list

### API Validation
- [ ] `POST /api/clients` returns 200/201 status
- [ ] Response includes client ID
- [ ] `base_commerciale_id` and `zone_id` match authenticated user
- [ ] Photos uploaded via `POST /api/clients/{id}/photos`

### Edge Cases to Test
- [ ] Create client without optional email
- [ ] Create client with auto-generated code
- [ ] Create client with multiple photos (5+)
- [ ] Test GPS failure scenario (manual entry)
- [ ] Test photo upload failure (retry mechanism)

---

## Test Scenario 2: Backend Client Assignment Verification

### Objective
Verify that backend automatically assigns the newly created client to the authenticated user.

### Prerequisites
- Test Scenario 1 completed successfully
- User logged in with valid token

### Test Steps

#### 2.1 Verify Client Assignment
- [ ] Navigate to Clients list
- [ ] Search for newly created client
- [ ] Tap on client to view details (ClientDetailPage)
- [ ] Verify client details include:
  - [ ] User's base commerciale name
  - [ ] User's zone name
  - [ ] All entered data matches

#### 2.2 Verify Client in Routing
- [ ] Navigate to TourneeDetailPage (daily routing)
- [ ] Select today's date
- [ ] Verify newly created client appears in routing list (if assigned to today)
- [ ] Or verify client can be added to future routing

### Expected Results
- Client is visible in user's client list
- Client belongs to user's base commerciale and zone
- Client can be visited by the user

### API Validation
- [ ] `GET /api/clients/{id}` returns client with correct assignments
- [ ] `GET /api/routing/my?date=YYYY-MM-DD` includes client if scheduled

---

## Test Scenario 3: Visit Report Creation

### Objective
Verify that a user can start a visit, create a visit report, and submit it successfully.

### Prerequisites
- Test Scenario 2 completed
- User has at least one assigned client
- User is near client location (proximity validation)
- GPS/location services enabled

### Test Steps

#### 3.1 Navigate to Client
- [ ] From HomePage, navigate to Clients or Routing
- [ ] Select the client to visit
- [ ] View client details (ClientDetailPage)

#### 3.2 Start Visit
- [ ] Tap "Start Visit" button
- [ ] Verify proximity check:
  - [ ] If within range: visit starts successfully
  - [ ] If outside range: error message with distance shown
- [ ] Move closer if needed and retry
- [ ] Verify visit status changes to "started"
- [ ] Verify app bar shows "Visit in Progress" indicator

#### 3.3 Create Visit Report
- [ ] Navigate to ApiVisitDetailPage
- [ ] Fill report data:
  - [ ] Is manager present? (Yes/No)
  - [ ] Order made? (Yes/No)
  - [ ] If order made, enter order reference and amount
  - [ ] Client needs order? (Yes/No)
  - [ ] Stock shortage observed? (Yes/No)
  - [ ] If stock shortage, describe issues
  - [ ] Competitor activity observed? (Yes/No)
  - [ ] If competitor activity, describe details
  - [ ] Add general comments (optional)

#### 3.4 Capture Photos
- [ ] Tap "Add Shelf Photos" button
- [ ] Take 2-3 photos of shelves
- [ ] Tap "Add Other Photos" button
- [ ] Take 1-2 additional photos
- [ ] Verify all photos appear in preview
- [ ] Verify GPS coordinates captured for each photo

#### 3.5 Submit Visit Report
- [ ] Tap "Submit Report" button
- [ ] Verify GPS location is captured
- [ ] Wait for API call completion
- [ ] Verify success message appears
- [ ] Verify photos uploaded successfully

#### 3.6 Terminate Visit
- [ ] Tap "End Visit" or "Terminate Visit" button
- [ ] Verify proximity check:
  - [ ] If within range: visit terminates normally
  - [ ] If outside range: prompt for termination reason
- [ ] Select reason if prompted (e.g., "Client relocated", "Emergency", etc.)
- [ ] Confirm termination
- [ ] Verify visit status changes to "completed"
- [ ] Verify app bar clears "Visit in Progress" indicator

### Expected Results
- Visit started only when within proximity range
- Report submitted with all data and photos
- Visit terminated successfully with proper status
- Visit appears in visit history
- Distance exceed reason captured if applicable

### API Validation
- [ ] `POST /api/visits` returns visit with status="started"
- [ ] `POST /api/visits/{id}/report` returns 200 with photo URLs
- [ ] `POST /api/visits/{id}/terminate` returns status="completed"
- [ ] `GET /api/visits/active` returns null after termination
- [ ] `GET /api/clients/{id}/reports` includes new report

### Edge Cases to Test
- [ ] Start visit from outside proximity range (should fail)
- [ ] Submit report without photos (should succeed)
- [ ] Submit report with 10+ photos
- [ ] Terminate visit from outside range (requires reason)
- [ ] Network interruption during photo upload (retry)
- [ ] GPS disabled during visit (error handling)

---

## Test Scenario 4: Order/Command Creation

### Objective
Verify that a user can create an order for a client during or after a visit.

### Prerequisites
- Test Scenario 3 completed
- Products available in the system
- Client exists and has been visited

### Test Steps

#### 4.1 Navigate to Order Creation
- [ ] From VisitsPage or ClientDetailPage, tap "Create Order"
- [ ] Navigate to CreateOrderPage
- [ ] Verify client information is pre-filled (if coming from client context)

#### 4.2 Select Client (if not pre-filled)
- [ ] Search for client by name or code
- [ ] Select client from search results
- [ ] Verify client details display correctly

#### 4.3 Add Order Items
- [ ] Tap "Add Product" or "+" button
- [ ] Search for product by name or SKU
- [ ] Select product from results
- [ ] Verify product details display (name, SKU, unit, price)
- [ ] Enter quantity
- [ ] Verify line total calculates correctly (quantity × unit price)
- [ ] Add 3-5 different products to order

#### 4.4 Review Order Totals
- [ ] Verify order subtotal calculates correctly (sum of line totals)
- [ ] Verify taxes calculated (if applicable)
- [ ] Verify grand total correct

#### 4.5 Submit Order
- [ ] Tap "Submit Order" or "Create Order" button
- [ ] Wait for API call completion
- [ ] Verify success message appears
- [ ] Verify order reference/number generated
- [ ] Note the order reference for next test

### Expected Results
- Order created successfully with all items
- Order reference generated
- Order appears in orders list with status="pending"
- Client associated with order correctly

### API Validation
- [ ] `POST /api/orders` returns 200/201 with order ID
- [ ] Order includes all items with correct quantities and prices
- [ ] `GET /api/orders?client_id={id}` returns new order

### Edge Cases to Test
- [ ] Create order with single item
- [ ] Create order with 20+ items
- [ ] Add same product multiple times (should combine or create separate lines)
- [ ] Edit quantity after adding product
- [ ] Remove product from order before submission
- [ ] Submit order without items (should fail validation)

---

## Test Scenario 5: Alert Creation

### Objective
Verify that a user can create alerts for clients during visits to report issues or opportunities.

### Prerequisites
- Test Scenario 3 completed
- User has visited a client
- GPS/location services enabled

### Test Steps

#### 5.1 Navigate to Alert Creation
- [ ] From ClientDetailPage, VisitDetailPage, or VisitsPage
- [ ] Tap "Create Alert" button
- [ ] Navigate to AlertCreationPage

#### 5.2 Select Alert Type
- [ ] View available alert types:
  - [ ] Rupture Grave (Severe shortage)
  - [ ] Litige/Problème (Payment dispute/issue)
  - [ ] Problème Rayon (Major shelf problem)
  - [ ] Risque de Perte (Risk of losing client)
  - [ ] Demande Spéciale (Special client request)
  - [ ] Opportunité (New major opportunity)
  - [ ] Autre (Other)
- [ ] Select one alert type (e.g., "Rupture Grave")
- [ ] If "Autre" selected, enter custom type description

#### 5.3 Add Alert Details
- [ ] Enter comment/description (required)
  - Example: "Client is out of stock for product X, needs urgent delivery"
- [ ] Verify GPS coordinates auto-filled
- [ ] If creating from visit context, verify visit_id pre-filled
- [ ] Add visit_report_id if applicable

#### 5.4 Capture Photos (Optional)
- [ ] Tap "Add Photos" button
- [ ] Take 2-3 photos showing the issue
- [ ] Add title for each photo (optional)
- [ ] Verify photo previews appear
- [ ] Test maximum photo limit (10 photos)

#### 5.5 Submit Alert
- [ ] Tap "Submit Alert" or "Create Alert" button
- [ ] Wait for API call completion
- [ ] Verify success message appears
- [ ] Verify alert appears in alerts list

#### 5.6 Verify Alert Details
- [ ] Navigate to AlertesPage
- [ ] Find newly created alert
- [ ] Tap to view AlertDetailPage
- [ ] Verify all details correct:
  - [ ] Type
  - [ ] Comment
  - [ ] Photos
  - [ ] Client name
  - [ ] Status (should be "pending")
  - [ ] Created timestamp

### Expected Results
- Alert created successfully with all details
- Photos uploaded and associated with alert
- Alert status is "pending"
- Alert appears in user's alerts list
- Manager/admin can see alert for follow-up

### API Validation
- [ ] `POST /api/clients/{clientId}/alerts` returns 200/201
- [ ] Response includes alert ID and status
- [ ] `GET /api/alerts` includes new alert
- [ ] `GET /api/alerts?client_id={id}` returns client's alerts

### Edge Cases to Test
- [ ] Create alert without photos (should succeed)
- [ ] Create alert with maximum photos (10)
- [ ] Create alert of type "Autre" with custom type
- [ ] Create multiple alerts for same client
- [ ] Create alert with very long comment (1000+ chars)
- [ ] Create alert without GPS (should fail validation)

---

## Test Scenario 6: Bon de Livraison Scanning & Product Stock Addition

### Objective
Verify that scanning a bon de livraison (delivery note/invoice) correctly adds products to the user's stock via OCR API.

### Prerequisites
- User logged in
- Physical bon de livraison or sample invoice image available
- OCR service configured and running

### Test Steps

#### 6.1 Navigate to Invoice Scanning
- [ ] From HomePage, navigate to FacturePage or InvoiceListPage
- [ ] Tap "Scan Invoice" or "+" button
- [ ] Navigate to InvoiceDetailPage in scan mode

#### 6.2 Capture Invoice Image
- [ ] Tap "Capture Photo" button
- [ ] Take clear photo(s) of bon de livraison
  - Ensure text is readable
  - Good lighting
  - All corners visible
- [ ] Can capture multiple pages if needed
- [ ] Tap "Process Invoice" button

#### 6.3 OCR Processing
- [ ] Wait for OCR processing (progress indicator should show)
- [ ] Verify API call to `POST /api/ocr/invoice`
- [ ] Wait for extraction results

#### 6.4 Review Extracted Data
- [ ] Verify invoice header extracted:
  - [ ] Supplier name
  - [ ] Document type
  - [ ] Invoice/delivery note number
  - [ ] Invoice date
- [ ] Verify client information extracted:
  - [ ] Client name
  - [ ] Client code (if present)
- [ ] Verify line items extracted:
  - [ ] Product reference/SKU
  - [ ] Product designation/name
  - [ ] Quantity (packs + units)
  - [ ] Unit price TTC
  - [ ] Line total TTC
- [ ] Verify totals extracted:
  - [ ] Total HT (before tax)
  - [ ] Total Tax
  - [ ] Total TTC (with tax)
  - [ ] Net to pay
- [ ] Verify logistics (if present):
  - [ ] Package count
  - [ ] Total weight
  - [ ] Shipping cost

#### 6.5 Correct/Edit Data
- [ ] Review each line item
- [ ] Correct any OCR errors:
  - [ ] Edit quantities if wrong
  - [ ] Edit prices if wrong
  - [ ] Edit product names if misread
- [ ] Verify totals recalculate after edits
- [ ] Add missing items manually if OCR missed them

#### 6.6 Save Invoice
- [ ] Tap "Save Invoice" button
- [ ] Wait for API call to `POST /api/invoices`
- [ ] Verify success message appears
- [ ] Note the invoice ID for next test

#### 6.7 Verify Stock Updated
- [ ] Navigate to StockCommercialPage or inventory view
- [ ] Search for products from invoice
- [ ] Verify quantities increased by invoice amounts
- [ ] For example:
  - Before: Product A quantity = 10
  - Invoice: Product A quantity = 5
  - After: Product A quantity = 15

### Expected Results
- Invoice scanned and OCR processed successfully
- All data extracted accurately (or correctable)
- Invoice saved to system
- Products added to user's stock
- Stock quantities reflect invoice additions

### API Validation
- [ ] `POST /api/ocr/invoice` returns extracted data
- [ ] Photo IDs included in response
- [ ] `POST /api/invoices` returns 200/201 with invoice ID
- [ ] `GET /api/invoices` includes new invoice
- [ ] Stock quantities updated in database

### Edge Cases to Test
- [ ] Scan poor quality image (OCR should handle or request retry)
- [ ] Scan multi-page invoice (2-3 images)
- [ ] Manually enter invoice data (bypass OCR)
- [ ] Edit all fields after OCR extraction
- [ ] Save invoice with corrected data
- [ ] Scan invoice with 20+ line items
- [ ] Scan invoice with tax breakdown
- [ ] Handle OCR timeout (retry mechanism)

---

## Test Scenario 7: Product Deduction on Order Creation

### Objective
Verify that when a user creates an order (command), products are deducted from the user's stock.

### Prerequisites
- Test Scenario 6 completed (stock populated from invoice)
- User has products in stock
- Client exists to create order for

### Test Steps

#### 7.1 Check Initial Stock Levels
- [ ] Navigate to StockCommercialPage
- [ ] View current stock for products you'll order
- [ ] Note quantities for 3-5 products
  - Example: Product A = 15 units, Product B = 20 units, Product C = 8 units

#### 7.2 Create Order
- [ ] Navigate to CreateOrderPage
- [ ] Select client
- [ ] Add products from stock:
  - [ ] Add Product A, quantity = 5
  - [ ] Add Product B, quantity = 10
  - [ ] Add Product C, quantity = 3
- [ ] Submit order (refer to Test Scenario 4)
- [ ] Verify order created successfully

#### 7.3 Verify Stock Deduction
- [ ] Navigate back to StockCommercialPage
- [ ] Check stock levels for ordered products
- [ ] Verify quantities decreased:
  - [ ] Product A: 15 - 5 = 10 units
  - [ ] Product B: 20 - 10 = 10 units
  - [ ] Product C: 8 - 3 = 5 units

#### 7.4 Verify Negative Stock Prevention
- [ ] Try to create another order
- [ ] Attempt to order more than available stock
  - Example: Try to order 15 units of Product A (only 10 available)
- [ ] Verify system prevents order or shows warning
- [ ] Verify stock doesn't go negative

### Expected Results
- Order creation deducts products from stock
- Stock quantities accurate after deduction
- System prevents negative stock (or shows warning)
- Stock movements logged/tracked

### API Validation
- [ ] `POST /api/orders` triggers stock deduction
- [ ] `GET /api/stock` or similar endpoint shows updated quantities
- [ ] Stock movement records created

### Edge Cases to Test
- [ ] Order quantity exactly equals stock (stock goes to 0)
- [ ] Order multiple products, some with insufficient stock
- [ ] Cancel order (stock should be restored)
- [ ] Edit order quantities (stock adjusts accordingly)

---

## Test Scenario 8: Wallet Balance Update on Order Delivery

### Objective
Verify that when a user marks order items as delivered, the product price × quantity is added to the user's wallet balance via API.

### Prerequisites
- Test Scenario 7 completed (order created)
- Order exists with status allowing delivery marking
- WalletService configured

### Test Steps

#### 8.1 Check Initial Wallet Balance
- [ ] Navigate to WalletPage
- [ ] View current wallet balance
- [ ] Note the exact balance amount
  - Example: Balance = 50,000 FCFA

#### 8.2 Navigate to Order Details
- [ ] From OrdersPage or OrdersListPage
- [ ] Find the order created in Test Scenario 7
- [ ] Tap to open ApiOrderDetailPage
- [ ] Verify order details and items display

#### 8.3 Mark Items as Delivered
- [ ] For each order item, note:
  - [ ] Product name
  - [ ] Quantity
  - [ ] Unit price
  - [ ] Line total (quantity × unit price)
- [ ] Select first item
- [ ] Change status from "pending" to "delivered"
- [ ] Repeat for 2-3 items (not all items yet)
- [ ] Calculate expected balance increase:
  - Example:
    - Item 1: 5 × 2,000 = 10,000 FCFA
    - Item 2: 10 × 1,500 = 15,000 FCFA
    - Total increase = 25,000 FCFA

#### 8.4 Submit Status Update
- [ ] Tap "Save" or "Update Status" button
- [ ] Wait for API call to `PUT /api/order-items/status`
- [ ] Verify success message appears

#### 8.5 Verify Wallet Balance Updated
- [ ] Navigate back to WalletPage
- [ ] Check updated wallet balance
- [ ] Verify balance increased by delivered item totals:
  - Expected: 50,000 + 25,000 = 75,000 FCFA
- [ ] Verify new transactions appear in recent transactions
- [ ] Tap on transaction to see details:
  - [ ] Type = "credit"
  - [ ] Amount = line item total
  - [ ] Reference type = "InvoiceItem" or "OrderItem"
  - [ ] Reference ID = item ID
  - [ ] Description includes product name

#### 8.6 View Transaction History
- [ ] Navigate to WalletTransactionsPage
- [ ] Verify all delivered item transactions listed
- [ ] Verify transaction details:
  - [ ] Created timestamp
  - [ ] Amount (green for credit)
  - [ ] Balance after transaction
  - [ ] Description/reference

#### 8.7 Mark Remaining Items
- [ ] Go back to order details
- [ ] Mark remaining items as "delivered"
- [ ] Submit status update
- [ ] Verify wallet balance increases again by remaining totals

### Expected Results
- Marking items as delivered triggers wallet credit
- Wallet balance increases by (quantity × unit_price) for each item
- Transactions recorded with correct references
- Transaction history shows all credits
- Balance calculation is accurate

### API Validation
- [ ] `PUT /api/order-items/status` returns 200/201
- [ ] `GET /api/wallet` shows increased balance
- [ ] `GET /api/wallet/transactions` includes new transactions
- [ ] Each transaction has correct:
  - type = "credit"
  - amount = item total
  - reference_type = "InvoiceItem" or "OrderItem"
  - reference_id = item ID

### Edge Cases to Test
- [ ] Mark items as "not_delivered" (should not credit wallet)
- [ ] Mark same item as delivered twice (should prevent or handle gracefully)
- [ ] Mark partial delivery (some items delivered, some not)
- [ ] Large order (50+ items, verify all credited correctly)
- [ ] Network failure during status update (retry, no duplicate credits)
- [ ] View transaction pagination (if 50+ transactions)

---

## Test Scenario 9: Bon de Versement Settlement

### Objective
Verify that at end of day, user can scan bon de versement (settlement document) and API deducts the value from the wallet balance.

### Status
⚠️ **PARTIALLY IMPLEMENTED** - Routing system exists but full settlement flow is under development.

### Prerequisites
- Test Scenario 8 completed (wallet has balance)
- User has completed daily route
- Bon de versement document available (physical or digital)

### Test Steps (When Implemented)

#### 9.1 Complete Daily Route
- [ ] Navigate to TourneeDetailPageNew
- [ ] View today's routing
- [ ] Verify all clients visited or marked
- [ ] Verify all orders collected
- [ ] Tap "Complete Route" or "End Day" button
- [ ] Verify route status changes to "completed"

#### 9.2 Generate Settlement Summary
- [ ] System should show summary:
  - [ ] Total clients visited
  - [ ] Total orders collected
  - [ ] Total order value
  - [ ] Current wallet balance
  - [ ] Expected settlement amount

#### 9.3 Scan Bon de Versement
- [ ] Tap "Scan Settlement Document" or similar
- [ ] Capture photo of bon de versement
- [ ] OCR processes document
- [ ] Verify extracted amount matches expected settlement

#### 9.4 Confirm Settlement
- [ ] Review settlement details
- [ ] Verify amount to be deducted from wallet
- [ ] Confirm settlement
- [ ] Wait for API call

#### 9.5 Verify Wallet Deduction
- [ ] Navigate to WalletPage
- [ ] Verify balance decreased by settlement amount
- [ ] Verify new debit transaction appears
- [ ] Transaction details:
  - [ ] Type = "debit"
  - [ ] Amount = settlement amount
  - [ ] Reference type = "Settlement" or "BonDeVersement"
  - [ ] Description = "End of day settlement - [date]"

### Expected Results (When Implemented)
- Route completion triggers settlement flow
- Bon de versement scanned and amount extracted
- Wallet balance debited by settlement amount
- Settlement transaction recorded
- User can view settlement history

### API Validation (Future)
- [ ] `POST /api/routing/{id}/complete` triggers settlement
- [ ] `POST /api/ocr/bon-versement` extracts amount
- [ ] `POST /api/settlements` or similar creates settlement
- [ ] `GET /api/wallet` shows decreased balance
- [ ] `GET /api/wallet/transactions` includes debit transaction

### Current Implementation Notes
- ✅ Routing system exists (`GET /api/routing/my?date=YYYY-MM-DD`)
- ✅ Route status tracking (planned → in_progress → completed)
- ✅ Client visit tracking
- ✅ Order count tracking
- ❌ Settlement document scanning NOT YET IMPLEMENTED
- ❌ Automatic balance settlement NOT YET IMPLEMENTED
- ❌ Settlement transaction recording NOT YET IMPLEMENTED

### Recommendation
**Test Scenario 9 should be marked as "Pending Implementation"** until the settlement flow is fully developed. Current tests should focus on:
- Route completion (can test)
- Route summary generation (can test)
- Settlement flow preparation (design/planning)

---

## Test Execution Summary

### Test Priority Levels

**P0 - Critical (Must Pass Before Release)**
- ✅ Scenario 1: Client Creation
- ✅ Scenario 2: Client Assignment
- ✅ Scenario 3: Visit Report Creation
- ✅ Scenario 4: Order Creation
- ✅ Scenario 6: Invoice Scanning & Stock Addition
- ✅ Scenario 7: Stock Deduction on Order
- ✅ Scenario 8: Wallet Balance Update

**P1 - High Priority**
- ✅ Scenario 5: Alert Creation

**P2 - Medium Priority (Future Release)**
- ⏳ Scenario 9: Bon de Versement Settlement

### Test Environment Requirements

**Device Requirements:**
- Android 8.0+ or iOS 12.0+
- GPS/location services enabled
- Camera access granted
- Internet connectivity (Wi-Fi or mobile data)
- Minimum 2GB available storage (for photos)

**Backend Requirements:**
- API server running and accessible
- OCR service configured and operational
- Database with test data
- Test user account with proper roles/permissions

**Test Data Requirements:**
- At least 5 test clients
- At least 10 test products
- Sample invoice/bon de livraison images
- GPS coordinates near test client locations

### Test Execution Order

**Day 1: Foundation**
1. Execute Scenario 1 (Client Creation)
2. Execute Scenario 2 (Client Assignment Verification)
3. Execute Scenario 5 (Alert Creation)

**Day 2: Core Workflow**
4. Execute Scenario 3 (Visit Report Creation)
5. Execute Scenario 4 (Order Creation)

**Day 3: Stock & Wallet**
6. Execute Scenario 6 (Invoice Scanning)
7. Execute Scenario 7 (Stock Deduction)
8. Execute Scenario 8 (Wallet Balance Update)

**Future: Settlement**
9. Execute Scenario 9 (when implemented)

### Success Criteria

**Overall Pass Criteria:**
- All P0 scenarios: 100% pass rate
- All P1 scenarios: 95% pass rate
- No critical/blocking bugs
- Performance acceptable (page loads < 3s, API calls < 5s)
- All edge cases handled gracefully

**Individual Scenario Pass Criteria:**
- All test steps executed successfully
- All expected results achieved
- All API validations passed
- All edge cases tested
- No unhandled exceptions or crashes

---

## Bug Reporting Template

When bugs are found during testing, report with this format:

```
**Bug ID:** BUG-XXX
**Scenario:** [Scenario Number & Name]
**Priority:** [Critical/High/Medium/Low]
**Status:** [Open/In Progress/Resolved/Closed]

**Description:**
[Brief description of the bug]

**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected Result:**
[What should happen]

**Actual Result:**
[What actually happened]

**Screenshots/Logs:**
[Attach relevant images or log excerpts]

**Environment:**
- Device: [e.g., iPhone 14, Samsung Galaxy S21]
- OS: [e.g., iOS 16.2, Android 13]
- App Version: [e.g., 1.0.0-beta]
- Network: [Wi-Fi/Mobile Data]

**Additional Notes:**
[Any other relevant information]
```

---

## Test Completion Checklist

- [ ] All test scenarios executed
- [ ] All bugs reported and tracked
- [ ] Critical bugs resolved
- [ ] Regression testing completed
- [ ] Performance testing completed
- [ ] API testing completed
- [ ] Edge cases tested
- [ ] User acceptance testing completed
- [ ] Test results documented
- [ ] Release notes prepared

---

**Document Version:** 1.0
**Last Updated:** 2026-01-04
**Prepared By:** Test Team
**Status:** Ready for Execution
