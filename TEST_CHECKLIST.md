# OCR Invoice Integration - Test Checklist

## ✅ Implementation Status

### Data Models
- [x] Product models support pack/unit pricing (units_per_pack, can_sell_unit, unit_price, pack_price)
- [x] InvoiceItem model includes quantity_packs, quantity_units, units_per_pack, status
- [x] InvoiceLogistics model includes shippingCost
- [x] CreateInvoiceRequest includes shippingCost and taxes array
- [x] ItemStatusUpdate supports charged/delivered/not_delivered

### UI Components
- [x] Shipping cost field in invoice creation form
- [x] Pack/unit fields in invoice item section
- [ ] Item status controls in invoice detail page
- [ ] Status summary in invoice list page

---

## 🧪 Testing Checklist

### 1. Invoice Creation with OCR

#### Test Case 1.1: Upload Invoice Image
- [ ] Open Facture Page
- [ ] Upload 1-10 invoice images
- [ ] Verify OCR processing completes successfully
- [ ] Check that all fields are populated:
  - [ ] Invoice header (supplier, document type, number, date)
  - [ ] Client info (name, code, reference)
  - [ ] Items list (reference, designation, quantity, prices)
  - [ ] Totals (HT, Tax, TTC, Port, Net to Pay)
  - [ ] **NEW**: Shipping cost populated
  - [ ] **NEW**: Packages count and total weight
  - [ ] **NEW**: Pack/unit fields if present in OCR data

#### Test Case 1.2: Edit Invoice Data
- [ ] Modify shipping cost field
- [ ] Edit pack/unit quantities for items:
  - [ ] Enter quantity_packs (e.g., 5)
  - [ ] Enter quantity_units (e.g., 3)
  - [ ] Enter units_per_pack (e.g., 12)
  - [ ] Verify quantity calculation: total = (5 × 12) + 3 = 63
- [ ] Save invoice

#### Test Case 1.3: Verify API Payload
Expected CreateInvoiceRequest JSON structure:
```json
{
  "supplier": "SUPPLIER NAME",
  "document_type": "FACTURE",
  "invoice_number": "INV-001",
  "invoice_date": "2026-01-04",
  "client_name": "Client ABC",
  "client_code": "CLI-123",
  "total_ht": 10000,
  "total_tax": 1850,
  "total_ttc": 11850,
  "net_to_pay": 11850,
  "packages_count": 5,
  "total_weight": 120.5,
  "shipping_cost": 5000,
  "photo_ids": [101, 102],
  "items": [
    {
      "reference": "PROD-001",
      "designation": "Product Name",
      "quantity": 63,
      "unit_price_ttc": 188.10,
      "total_ttc": 11850,
      "depot": "Warehouse A",
      "quantity_packs": 5,
      "quantity_units": 3,
      "units_per_pack": 12
    }
  ]
}
```

Check response:
- [ ] HTTP 200/201 status
- [ ] Returns invoice ID
- [ ] Photo IDs are linked to invoice
- [ ] Stock automatically updated

---

### 2. Item Status Workflow

#### Test Case 2.1: Mark Items as Charged (Loading Truck)
- [ ] Open invoice detail page
- [ ] Select items to mark as "charged"
- [ ] Verify API call to PUT /api/invoices/{id}/items/status:
```json
{
  "items": [
    {"id": 1, "status": "charged"},
    {"id": 2, "status": "charged"}
  ]
}
```
- [ ] Check that items show "charged" status indicator

#### Test Case 2.2: Mark Items as Delivered
- [ ] Select charged items
- [ ] Mark as "delivered"
- [ ] Verify API call with status: "delivered"
- [ ] **Check that wallet is credited** (backend should handle this)
- [ ] Verify item shows "delivered" status with checkmark icon

#### Test Case 2.3: Mark Items as Not Delivered
- [ ] Select charged items
- [ ] Mark as "not_delivered"
- [ ] Verify API call with status: "not_delivered"
- [ ] Check that wallet is NOT credited
- [ ] Verify item shows "not delivered" status with error icon

#### Test Case 2.4: Status Workflow Validation
- [ ] Attempt to skip "charged" status (go directly pending → delivered)
  - Should work if allowed by UI
- [ ] Verify status history/tracking if implemented

---

### 3. Pack/Unit Pricing

#### Test Case 3.1: Product with Pack Pricing
- [ ] Find product with units_per_pack = 12, can_sell_unit = true
- [ ] Add to invoice with:
  - quantity_packs = 3
  - quantity_units = 5
- [ ] Verify total quantity = (3 × 12) + 5 = 41
- [ ] Check unit price vs pack price calculation

#### Test Case 3.2: Unit-Only Products
- [ ] Find product with can_sell_unit = true, no pack pricing
- [ ] Add with quantity_units only
- [ ] Verify quantity_packs remains 0 or null

#### Test Case 3.3: Pack-Only Products
- [ ] Find product with can_sell_unit = false
- [ ] Add with quantity_packs only
- [ ] Verify quantity_units remains 0 or null

---

### 4. Edge Cases

#### Test Case 4.1: Empty/Null Values
- [ ] Create invoice with shipping_cost = null
- [ ] Create item with no pack/unit data
- [ ] Verify API accepts null values gracefully

#### Test Case 4.2: Large Numbers
- [ ] Test with shipping_cost > 1,000,000
- [ ] Test with quantity_packs > 100
- [ ] Verify number formatting (thousand separators)

#### Test Case 4.3: OCR Failures
- [ ] Upload unclear invoice image
- [ ] Verify OCR returns partial data
- [ ] Manually edit missing fields
- [ ] Save successfully

---

## 🔍 API Endpoint Reference

### OCR Endpoints
- **POST** `/api/ocr/invoice` - Upload and process invoice images
  - Max 10 images, 10MB each
  - Returns: ocr_data + photo_ids

- **GET** `/api/photos/{photo}/ocr` - Retrieve OCR results for photo

### Invoice Endpoints
- **POST** `/api/invoices` - Create invoice with new fields
- **PUT** `/api/invoices/{id}` - Update invoice
- **PUT** `/api/invoices/{invoice}/items/status` - Update item statuses

### Expected Status Codes
- 200: Success
- 201: Created
- 400: Validation error
- 422: Unprocessable entity (check field format)

---

## 📊 Performance Checklist
- [ ] OCR processing completes within 30 seconds for 5 images
- [ ] Form saves without lag with 10+ items
- [ ] Status updates are instant
- [ ] No memory leaks when disposing controllers

---

## 🐛 Known Issues
- Test mock files have invalid_override errors (test/services/*_test.mocks.dart)
  - Not blocking production build
  - Need to regenerate mocks if running tests

---

## 📝 Notes
- All new fields are optional (nullable) to maintain backward compatibility
- Backend handles wallet crediting automatically when item status → delivered
- Pack/unit quantities stored independently for full flexibility
- Shipping cost is separate from port_ht (port HT is part of totals)
