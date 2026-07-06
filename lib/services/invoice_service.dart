import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/purchase.dart';
import '../models/sale.dart';

class InvoiceService {
  static Future<void> generatePurchaseInvoice({
    required Map<String, dynamic> company,
    required Map<String, dynamic> supplier,
    required List<Purchase> items,
    required String transactionId,
    required String date,
  }) async {
    final pdf = await buildPurchaseInvoice(
      company: company,
      supplier: supplier,
      items: items,
      transactionId: transactionId,
      date: date,
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> sharePurchaseInvoice({
    required Map<String, dynamic> company,
    required Map<String, dynamic> supplier,
    required List<Purchase> items,
    required String transactionId,
    required String date,
  }) async {
    final pdf = await buildPurchaseInvoice(
      company: company,
      supplier: supplier,
      items: items,
      transactionId: transactionId,
      date: date,
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Purchase_$transactionId.pdf');
  }

  static Future<pw.Document> buildPurchaseInvoice({
    required Map<String, dynamic> company,
    required Map<String, dynamic> supplier,
    required List<Purchase> items,
    required String transactionId,
    required String date,
  }) async {
    final pdf = pw.Document();
    final total = items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    final totalQty = items.fold(0, (sum, item) => sum + item.quantity);
    final totalCommission = items.fold(0.0, (sum, item) => sum + item.commission);
    final cleanDate = date.split(' ').first;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(company['name'] ?? 'My Company', 'PURCHASE ORDER', transactionId, cleanDate),
              pw.SizedBox(height: 30),
              _buildAddressSection(company, supplier, 'Supplier'),
              pw.SizedBox(height: 30),
              _buildItemsTable(items.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                return {
                  'no': (i + 1).toString(),
                  'name': '${e.brandName ?? ''} ${e.productName ?? ''}\n${e.productCode ?? 'N/A'}'.trim(),
                  'qty': e.quantity.toString(),
                  'price': e.price.toStringAsFixed(2),
                  'total': (e.price * e.quantity).toStringAsFixed(2),
                };
              }).toList(), total + totalCommission, totalQty.toDouble(), totalCommission: totalCommission),
              pw.SizedBox(height: 20),
              pw.Spacer(),
              _buildFooter(),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  static Future<void> generateSaleInvoice({
    required Map<String, dynamic> company,
    required Map<String, dynamic> customer,
    required List<Sale> items,
    required String transactionId,
    required String date,
  }) async {
    final pdf = await buildSaleInvoice(
      company: company,
      customer: customer,
      items: items,
      transactionId: transactionId,
      date: date,
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> shareSaleInvoice({
    required Map<String, dynamic> company,
    required Map<String, dynamic> customer,
    required List<Sale> items,
    required String transactionId,
    required String date,
  }) async {
    final pdf = await buildSaleInvoice(
      company: company,
      customer: customer,
      items: items,
      transactionId: transactionId,
      date: date,
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Invoice_$transactionId.pdf');
  }

  static Future<pw.Document> buildSaleInvoice({
    required Map<String, dynamic> company,
    required Map<String, dynamic> customer,
    required List<Sale> items,
    required String transactionId,
    required String date,
  }) async {
    final pdf = pw.Document();
    final total = items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    final totalQty = items.fold(0, (sum, item) => sum + item.quantity);
    final cleanDate = date.split(' ').first;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(company['name'] ?? 'My Company', 'INVOICE', transactionId, cleanDate),
              pw.SizedBox(height: 30),
              _buildAddressSection(company, customer, 'Customer'),
              pw.SizedBox(height: 30),
              _buildItemsTable(items.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                return {
                  'no': (i + 1).toString(),
                  'name': '${e.brandName ?? ''} ${e.productName ?? 'Unknown'}\n${e.productCode ?? 'N/A'}'.trim(),
                  'qty': e.quantity.toString(),
                  'price': e.price.toStringAsFixed(2),
                  'total': (e.price * e.quantity).toStringAsFixed(2),
                };
              }).toList(), total, totalQty.toDouble()),
              pw.SizedBox(height: 20),
              pw.Spacer(),
              _buildFooter(),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  static pw.Widget _buildHeader(String companyName, String type, String tid, String date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(companyName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
            pw.Text(type, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, letterSpacing: 1.2)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('ID: #$tid', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Date: $date'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildAddressSection(Map<String, dynamic> company, Map<String, dynamic> partner, String partnerLabel) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('FROM:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text(company['name'] ?? 'My Company', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (company['address'] != null && company['address'].isNotEmpty) pw.Text(company['address'], style: const pw.TextStyle(fontSize: 10)),
              if (company['phone'] != null && company['phone'].isNotEmpty) pw.Text('Tel: ${company['phone']}', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
        pw.SizedBox(width: 40),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('BILL TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text(partner['name'] ?? 'Guest', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (partner['company'] != null && partner['company'].isNotEmpty) 
                pw.Text(partner['company'], style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              if (partner['address'] != null && partner['address'].isNotEmpty) 
                pw.Text(partner['address'], textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10)),
              if (partner['contact'] != null && partner['contact'].isNotEmpty) 
                pw.Text(partner['contact'], style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(List<Map<String, String>> items, double totalAmount, double totalQty, {double totalCommission = 0.0}) {
    final List<List<String>> data = items.map((i) => [i['no']!, i['name']!, i['qty']!, i['price']!, i['total']!]).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.TableHelper.fromTextArray(
          headers: ['No.', 'Description', 'Qty', 'Unit Price', 'Total'],
          data: data,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black, fontSize: 9),
          headerDecoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
          ),
          cellHeight: 20,
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
          cellAlignments: {
            0: pw.Alignment.center,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
          },
          border: null,
          headerPadding: const pw.EdgeInsets.all(6),
          cellPadding: const pw.EdgeInsets.all(6),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
          rowDecoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
        ),
        pw.SizedBox(height: 16),
        // Totals summary bar
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 1)),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(children: [
                pw.Text('Total Items: ', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
                pw.Text('${data.length}', style: pw.TextStyle(color: PdfColors.black, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.SizedBox(width: 20),
                pw.Text('Total Qty: ', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
                pw.Text(totalQty.toStringAsFixed(0), style: pw.TextStyle(color: PdfColors.black, fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ]),
              pw.Row(children: [
                if (totalCommission > 0) ...[
                  pw.Text('COMMISSION: ', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9)),
                  pw.Text('QAR ${totalCommission.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.black, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.SizedBox(width: 16),
                ],
                pw.Text('TOTAL AMOUNT: ', style: pw.TextStyle(color: PdfColors.grey800, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.SizedBox(width: 4),
                pw.Text('QAR ${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.black, fontWeight: pw.FontWeight.bold, fontSize: 14)),
              ]),
            ],
          ),
        ),
      ],
    );
  }
  static Future<void> generatePaymentReceipt({
    required Map<String, dynamic> company,
    required Map<String, dynamic> partner,
    required String transactionId,
    required double amount,
    required String date,
    required bool isPurchase,
    required double remainingBalance,
  }) async {
    final pdf = await buildPaymentReceipt(
      company: company,
      partner: partner,
      transactionId: transactionId,
      amount: amount,
      date: date,
      isPurchase: isPurchase,
      remainingBalance: remainingBalance,
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<pw.Document> buildPaymentReceipt({
    required Map<String, dynamic> company,
    required Map<String, dynamic> partner,
    required String transactionId,
    required double amount,
    required String date,
    required bool isPurchase,
    required double remainingBalance,
  }) async {
    final pdf = pw.Document();
    final cleanDate = date.split(' ').first;
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(company['name'] ?? 'My Company', 'PAYMENT RECEIPT', transactionId, cleanDate),
              pw.SizedBox(height: 30),
              _buildAddressSection(company, partner, isPurchase ? 'Supplier' : 'Customer'),
              pw.SizedBox(height: 30),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      isPurchase ? 'Payment to Supplier' : 'Payment from Customer',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Date Received: ', style: const pw.TextStyle(color: PdfColors.grey700)),
                        pw.Text(date, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(color: PdfColors.grey300),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('AMOUNT PAID: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('QAR ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                      ],
                    ),
                    if (remainingBalance > 0) ...[
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Remaining Balance: ', style: const pw.TextStyle(color: PdfColors.grey700)),
                          pw.Text('QAR ${remainingBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                        ],
                      ),
                    ],
                    if (remainingBalance <= 0) ...[
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Remaining Balance: ', style: const pw.TextStyle(color: PdfColors.grey700)),
                          pw.Text('FULLY PAID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green600)),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Spacer(),
              _buildFooter(),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  static pw.Widget _buildFooter() {
    final now = DateTime.now();
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Text('Thank you for your business!', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Text('Report generated on: $formattedTime', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8, fontStyle: pw.FontStyle.italic)),
      ],
    );
  }
}
