import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create document
  Future<void> createDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore
          .collection(collection)
          .doc(documentId)
          .set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw 'Error creating document: ${e.message}';
    }
  }

  // Get document
  Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      final doc = await _firestore
          .collection(collection)
          .doc(documentId)
          .get();
      
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } on FirebaseException catch (e) {
      throw 'Error getting document: ${e.message}';
    }
  }

  // Update document
  Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore
          .collection(collection)
          .doc(documentId)
          .update(data);
    } on FirebaseException catch (e) {
      throw 'Error updating document: ${e.message}';
    }
  }

  // Delete document
  Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      await _firestore
          .collection(collection)
          .doc(documentId)
          .delete();
    } on FirebaseException catch (e) {
      throw 'Error deleting document: ${e.message}';
    }
  }

  // Query documents
  Future<List<Map<String, dynamic>>> queryDocuments({
    required String collection,
    String? field,
    dynamic value,
    int? limit,
    String? orderBy,
    bool descending = false,
  }) async {
    try {
      Query query = _firestore.collection(collection);
      
      if (field != null && value != null) {
        query = query.where(field, isEqualTo: value);
      }
      
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }
      
      if (limit != null) {
        query = query.limit(limit);
      }
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    } on FirebaseException catch (e) {
      throw 'Error querying documents: ${e.message}';
    }
  }

  // Stream documents (real-time updates)
  Stream<List<Map<String, dynamic>>> streamDocuments({
    required String collection,
    String? field,
    dynamic value,
    int? limit,
    String? orderBy,
    bool descending = false,
  }) {
    Query query = _firestore.collection(collection);
    
    if (field != null && value != null) {
      query = query.where(field, isEqualTo: value);
    }
    
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    
    if (limit != null) {
      query = query.limit(limit);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    });
  }

  // Batch write
  Future<void> batchWrite(List<Map<String, dynamic>> operations) async {
    try {
      final batch = _firestore.batch();
      
      for (final op in operations) {
        final type = op['type'] as String;
        final collection = op['collection'] as String;
        final documentId = op['documentId'] as String;
        final data = op['data'] as Map<String, dynamic>?;
        
        final ref = _firestore.collection(collection).doc(documentId);
        
        switch (type) {
          case 'set':
            batch.set(ref, data ?? {}, SetOptions(merge: true));
            break;
          case 'update':
            batch.update(ref, data ?? {});
            break;
          case 'delete':
            batch.delete(ref);
            break;
        }
      }
      
      await batch.commit();
    } on FirebaseException catch (e) {
      throw 'Error in batch write: ${e.message}';
    }
  }
}
