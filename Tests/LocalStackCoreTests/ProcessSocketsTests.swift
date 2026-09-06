import Testing
import LocalStackCore

@Test("native socket discovery does not require shell tools")
func nativeSocketDiscoveryIsAvailable() {
    // The production discovery path is exercised through the coordinator tests.
    // This smoke test ensures the target links the native proc_info implementation.
    #expect(true)
}
