import 'api_client.dart';
import 'run_store.dart';

/// Keeps uncertain uploads frozen so retrying cannot award points twice.
class RunSync {
  final ApiClient api;
  final RunStore store;
  RunSync(this.api, this.store);

  Future<Map<String, dynamic>> submit(RunDraft draft) async {
    draft.queued = true;
    await store.save(draft);
    Map<String, dynamic> result;
    try {
      result = await api.saveRun({...draft.payload, 'request_id': draft.id});
    } on ApiException catch (error) {
      // These responses explicitly reject the transaction. The runner may
      // correct the request or continue recording before submitting it again.
      // Timeouts, 409 conflicts and server failures remain immutable.
      if (const [400, 403, 422].contains(error.statusCode)) {
        draft.queued = false;
        await store.save(draft);
      }
      rethrow;
    }
    await store.remove(draft.id);
    return result;
  }
}
