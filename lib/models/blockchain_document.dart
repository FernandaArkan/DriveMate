class BlockchainDocument {
  const BlockchainDocument({
    required this.documentId,
    required this.serviceRecordId,
    required this.documentHash,
    required this.verificationStatus,
    this.transactionHash,
    this.networkName = 'Polygon Amoy Testnet',
    this.contractAddress,
    required this.verificationUrl,
    required this.pdfUrl,
    this.pdfDownloadUrl,
    this.createdAt,
    this.blockchainMessage,
  });

  final String documentId;
  final int serviceRecordId;
  final String documentHash;
  final String verificationStatus;
  final String? transactionHash;
  final String networkName;
  final String? contractAddress;
  final String verificationUrl;
  final String pdfUrl;
  final String? pdfDownloadUrl;
  final String? createdAt;
  final String? blockchainMessage;

  bool get isVerified => verificationStatus.toLowerCase() == 'verified';
  bool get isPending =>
      verificationStatus.toLowerCase() == 'pending' ||
      verificationStatus.toLowerCase() == 'unconfirmed';
  bool get isFailed => verificationStatus.toLowerCase() == 'failed';

  factory BlockchainDocument.fromMap(Map<String, dynamic> map) {
    return BlockchainDocument(
      documentId: map['document_id'] as String? ?? '',
      serviceRecordId: (map['service_record_id'] as num?)?.toInt() ?? 0,
      documentHash: map['document_hash'] as String? ?? '',
      verificationStatus: map['verification_status'] as String? ?? 'pending',
      transactionHash: map['transaction_hash'] as String?,
      networkName: map['network_name'] as String? ?? 'Polygon Amoy Testnet',
      contractAddress: map['contract_address'] as String?,
      verificationUrl: map['verification_url'] as String? ?? '',
      pdfUrl: map['pdf_url'] as String? ?? '',
      pdfDownloadUrl: map['pdf_download_url'] as String?,
      createdAt: map['created_at'] as String?,
      blockchainMessage: map['blockchain_message'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'document_id': documentId,
      'service_record_id': serviceRecordId,
      'document_hash': documentHash,
      'verification_status': verificationStatus,
      if (transactionHash != null) 'transaction_hash': transactionHash,
      'network_name': networkName,
      if (contractAddress != null) 'contract_address': contractAddress,
      'verification_url': verificationUrl,
      'pdf_url': pdfUrl,
      if (pdfDownloadUrl != null) 'pdf_download_url': pdfDownloadUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (blockchainMessage != null) 'blockchain_message': blockchainMessage,
    };
  }
}
