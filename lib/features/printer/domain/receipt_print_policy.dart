/// Delivery describes transport, while fulfillment records an operator's paper
/// inspection or a freshly authenticated, single-sale owner exception.
final class ReceiptPrintPolicy {
  const ReceiptPrintPolicy({this.required = false, this.revision = 1});
  final bool required;
  final int revision;
}

final class ReceiptPrintState {
  const ReceiptPrintState({
    required this.sale,
    this.required = false,
    this.resolution,
    this.latestJob,
    this.latestStatus,
    this.confirmableJob,
  });
  final String sale;
  final bool required;
  final String? resolution, latestJob, latestStatus, confirmableJob;
  bool get pending => required && resolution == null;
}
