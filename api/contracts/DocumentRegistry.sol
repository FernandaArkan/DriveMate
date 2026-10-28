// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DocumentRegistry
 * @dev Smart contract for anchoring and verifying vehicle service certificate document hashes on-chain.
 */
contract DocumentRegistry {
    struct DocumentRecord {
        string documentId;
        bytes32 documentHash;
        uint256 serviceRecordId;
        uint256 registeredAt;
        address recordedBy;
        bool exists;
    }

    // Mapping from documentId => DocumentRecord
    mapping(string => DocumentRecord) private _documents;

    // Mapping from documentHash => array of documentIds
    mapping(bytes32 => string[]) private _hashToDocuments;

    event DocumentRecorded(
        string indexed documentId,
        bytes32 indexed documentHash,
        uint256 serviceRecordId,
        uint256 registeredAt,
        address recordedBy
    );

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Records a new document hash to the blockchain.
     * @param documentId Unique UUID identifier of the document.
     * @param documentHash 32-byte SHA-256 hash of the final PDF bytes.
     * @param serviceRecordId ID of the service record.
     */
    function recordDocument(
        string calldata documentId,
        bytes32 documentHash,
        uint256 serviceRecordId
    ) external {
        require(bytes(documentId).length > 0, "Document ID cannot be empty");
        require(documentHash != bytes32(0), "Document hash cannot be zero");
        require(!_documents[documentId].exists, "Document already recorded");

        _documents[documentId] = DocumentRecord({
            documentId: documentId,
            documentHash: documentHash,
            serviceRecordId: serviceRecordId,
            registeredAt: block.timestamp,
            recordedBy: msg.sender,
            exists: true
        });

        _hashToDocuments[documentHash].push(documentId);

        emit DocumentRecorded(
            documentId,
            documentHash,
            serviceRecordId,
            block.timestamp,
            msg.sender
        );
    }

    /**
     * @dev Retrieves document record details by documentId.
     */
    function getDocument(string calldata documentId)
        external
        view
        returns (
            string memory id,
            bytes32 hash,
            uint256 serviceRecordId,
            uint256 registeredAt,
            address recordedBy,
            bool isRegistered
        )
    {
        DocumentRecord memory doc = _documents[documentId];
        return (
            doc.documentId,
            doc.documentHash,
            doc.serviceRecordId,
            doc.registeredAt,
            doc.recordedBy,
            doc.exists
        );
    }

    /**
     * @dev Verifies whether a given documentId and documentHash match the on-chain record.
     */
    function verifyDocument(string calldata documentId, bytes32 documentHash)
        external
        view
        returns (bool isValid, uint256 registeredAt, address recordedBy)
    {
        DocumentRecord memory doc = _documents[documentId];
        if (doc.exists && doc.documentHash == documentHash) {
            return (true, doc.registeredAt, doc.recordedBy);
        }
        return (false, 0, address(0));
    }
}
