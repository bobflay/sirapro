# Server Invoice Generation Prompt

You are tasked with generating a professional PDF invoice/receipt for a sales order. The PDF should match the following specifications exactly.

## Document Specifications

### Page Setup
- **Page Format**: A4 (210mm × 297mm)
- **Margins**: 32 points on all sides (top, bottom, left, right)
- **Layout**: Portrait orientation

### Typography & Styling
- **Main Title**: "Détails de Commande" - 24pt, bold
- **Section Headers**: 16pt, bold
- **Body Text**: 10-12pt, normal weight
- **Table Headers**: 12pt, bold
- **Table Content**: 10pt, normal weight

### Colors
- **Primary Text**: Black
- **Secondary Text**: Grey (#707070 / grey700)
- **Backgrounds**: Light grey (#E0E0E0 / grey200)
- **Borders**: Medium grey (#9E9E9E / grey400)
- **Success/Delivered**: Green (#388E3C / green700)
- **Error/Not Delivered**: Red (#D32F2F / red700)

## Document Structure

The PDF should contain the following sections in order:

### 1. Header Section
Display at the top of the document:
- **Title**: "Détails de Commande" (24pt, bold)
- **Order Reference**: Display the order reference or "Commande #[order_id]" if reference is unavailable (16pt)
- **Order Date**: Format as "DD/MM/YYYY à HH:MM" (12pt, grey)
  - Example: "11/02/2026 à 14:30"

### 2. Status Box
A box with light grey background (#E0E0E0) and rounded corners (8pt radius):
- **Label**: "Statut:" (bold)
- **Value**: The order status display text (normal weight)
- **Padding**: 12pt all around
- **Layout**: Label on left, value on right

### 3. Client Information Section
- **Section Title**: "Informations Client" (16pt, bold)
- **Container**: Box with grey border (#9E9E9E), rounded corners (8pt radius), 12pt padding
- **Fields** (display each as "Label: Value" with label in bold):
  - Nom: [client name] (required, show "-" if missing)
  - Code: [client code] (optional, omit row if not available)
  - Téléphone: [phone] (optional, omit row if not available)
  - Adresse: [address] (optional, omit row if not available)
  - Ville: [city] (optional, omit row if not available)
- **Field Layout**: Label width 150pt, value fills remaining space
- **Field Spacing**: 4pt vertical padding between fields

### 4. Order Items Section
- **Section Title**: "Articles ([total_count])" (16pt, bold)
  - Example: "Articles (15)"
- **Table Structure**:
  - **Border**: All cells bordered with grey (#9E9E9E)
  - **Header Row**: Light grey background (#BDBDBD / grey300)
  - **Headers** (12pt, bold, 8pt padding):
    1. "Article"
    2. "Prix U." (Unit Price)
    3. "Qté" (Quantity)
    4. "Total"
    5. "Statut" (Status)

- **Item Rows** (10pt, 8pt padding):
  - **Article Column**:
    - Line 1: Product display name
    - Line 2: Packaging information (if available)
  - **Prix U. Column**: "[formatted_price] [currency]"
    - Example: "1 250 MAD"
  - **Qté Column**: Quantity as integer
  - **Total Column**: "[formatted_line_total] [currency]"
  - **Statut Column**: One of:
    - "Livré" (if status is delivered)
    - "Non livré" (if status is not_delivered)
    - "En attente" (if status is pending)

### 5. Totals Summary Section
A box with light grey background (#E0E0E0), rounded corners (8pt radius), 16pt padding:

- **Total Row** (18pt label, 20pt value, both bold):
  - Label: "Total"
  - Value: "[formatted_total] [currency]"

- **Divider**: Horizontal line (grey #9E9E9E) with 12pt spacing above/below

- **Delivered Total Row** (bold, green color):
  - Label: "Total livré"
  - Value: "[formatted_delivered_total] [currency]" (green #388E3C)

- **Not Delivered Total Row** (bold, red color):
  - Label: "Total non livré"
  - Value: "[formatted_not_delivered_total] [currency]" (red #D32F2F)

### 6. Additional Information Section (Optional)
Only include if zone, base commerciale, or validated date are available:
- **Section Title**: "Informations additionnelles" (16pt, bold)
- **Container**: Box with grey border, rounded corners (8pt radius), 12pt padding
- **Fields** (same format as client info):
  - Zone: [zone name] (optional)
  - Base commerciale: [base commerciale name] (optional)
  - Date de validation: [formatted validation date] (optional, format: "DD/MM/YYYY à HH:MM")

### 7. Footer
- **Spacing**: 30pt above, then horizontal divider, then 8pt
- **Text**: "Document généré le [generation_date]"
  - Format date as: "DD/MM/YYYY à HH:MM"
  - Color: Light grey (#757575 / grey600)
  - Size: 10pt

## Number Formatting Rules

### Amount Formatting
All monetary amounts must be formatted with:
- **No decimal places** (round to nearest integer)
- **Thousands separators**: Use space as separator
- **Examples**:
  - 1250 → "1 250"
  - 150000 → "150 000"
  - 1250000 → "1 250 000"
  - 500 → "500"

### Date Formatting
- **Date Only**: "DD/MM/YYYY"
  - Example: "11/02/2026"
- **Date with Time**: "DD/MM/YYYY à HH:MM"
  - Example: "11/02/2026 à 14:30"

## Calculation Logic

### Total Delivered
Sum of line totals (unit_price × quantity) for all items where status is "delivered"

### Total Not Delivered
Sum of line totals for all items where status is "not_delivered" OR "pending"

### Grand Total
Sum of all item line totals regardless of status

## Data Model Reference

### Order Object
```json
{
  "id": 123,
  "reference": "CMD-2026-001",
  "ordered_at": "2026-02-11T14:30:00Z",
  "validated_at": "2026-02-11T15:00:00Z",
  "status": "confirmed",
  "statusDisplayText": "Confirmée",
  "total_amount": 150000.00,
  "currency": "MAD",
  "client": {
    "name": "Client Name",
    "code": "CLI001",
    "phone": "+212 6 12 34 56 78",
    "address": "123 Rue Example",
    "city": "Casablanca"
  },
  "zone": {
    "name": "Zone Nord"
  },
  "base_commerciale": {
    "name": "Base Casa"
  },
  "order_items": [
    {
      "id": 1,
      "display_name": "Product Name",
      "sku_snapshot": "SKU123",
      "packaging_snapshot": "Carton 12 unités",
      "unit_price_snapshot": 1250.00,
      "quantity": 10,
      "line_total": 12500.00,
      "status": "delivered"
    }
  ]
}
```

### Item Status Values
- `"delivered"` → Display as "Livré"
- `"not_delivered"` → Display as "Non livré"
- `"pending"` → Display as "En attente"

## Output Requirements

1. **File Format**: PDF/A-4 compliant
2. **File Name**: `commande_[reference or id].pdf`
   - Example: `commande_CMD-2026-001.pdf` or `commande_123.pdf`
3. **Character Encoding**: UTF-8 (to support French accents)
4. **Compression**: Apply standard PDF compression

## Quality Requirements

- All text must be selectable and searchable
- Tables should maintain alignment even with varying content lengths
- Page breaks should occur naturally if content exceeds one page
- Multi-page documents should include page numbers if needed
- Rounded corners should be consistent (8pt radius)
- Spacing between sections should be consistent (20pt)

## Error Handling

- If client name is missing, display "-"
- If optional fields are null/empty, omit the entire row
- If order reference is missing, use "Commande #[id]"
- If dates are invalid, display the raw value as fallback
- If currency is missing, omit the currency symbol

## Example Output Description

The final PDF should look like a clean, professional invoice with:
- Clear hierarchy (larger headers, organized sections)
- Easy-to-read table with alternating row clarity
- Visual separation between sections using boxes and borders
- Color coding to quickly identify delivered vs not delivered items
- Professional grey color scheme with accent colors for statuses
- Consistent spacing and alignment throughout

---

## API Endpoint Specification

### Endpoint
```
GET /api/orders/{order_id}/invoice
```

### Request Headers
- **Authorization**: `Bearer {token}` (required)
- **Accept**: `application/pdf` (required)

### Path Parameters
- **order_id**: Integer - The unique identifier of the order

### Response
- **Success (200 OK)**:
  - Content-Type: `application/pdf`
  - Body: PDF binary data
  - Headers:
    - `Content-Disposition: attachment; filename="commande_{reference or id}.pdf"`
    - `Content-Type: application/pdf`

- **Error Responses**:
  - **401 Unauthorized**: Missing or invalid authentication token
  - **404 Not Found**: Order not found or user doesn't have access
  - **500 Internal Server Error**: PDF generation failed

### Example Request
```bash
curl -X GET "http://your-domain/api/orders/123/invoice" \
  -H "Authorization: Bearer {token}" \
  -H "Accept: application/pdf" \
  --output commande_123.pdf
```

### Implementation Flow
1. **Authentication**: Validate the bearer token
2. **Authorization**: Verify user has access to the order
3. **Data Retrieval**: Fetch order details from database including:
   - Order information (id, reference, dates, status, total)
   - Client information (name, code, phone, address, city)
   - Order items with status (delivered/not_delivered/pending)
   - Zone and base commerciale information
4. **PDF Generation**: Generate PDF using specifications above
5. **Response**: Stream PDF back to client with appropriate headers

### Security Considerations
- Validate user has permission to access the requested order
- Sanitize all data before PDF generation to prevent injection attacks
- Implement rate limiting to prevent abuse
- Log all invoice generation requests for audit trail

---

## Implementation Notes

This specification is based on a Flutter mobile app implementation using the `pdf` package. When implementing on the server, use equivalent PDF generation libraries in your tech stack (e.g., wkhtmltopdf, ReportLab for Python, PDFKit for Node.js, iText for Java, etc.).

The key is to match the visual layout, typography, spacing, and data formatting exactly as specified above.

### Recommended Libraries by Stack
- **Python**: ReportLab, WeasyPrint, or wkhtmltopdf
- **Node.js**: PDFKit, Puppeteer, or jsPDF
- **PHP**: TCPDF, FPDF, or DomPDF
- **Java**: iText, Apache PDFBox, or Flying Saucer
- **.NET**: iTextSharp, PdfSharp, or SelectPdf
