import Foundation
import Testing
@testable import MacdroidMirrorCore

@Suite("Session State Tests")
struct SessionStateTests {

    @Test("Idle state properties")
    func idleState() {
        let state = SessionState.idle
        #expect(!state.isActive)
        #expect(!state.isTransitioning)
        #expect(state.activeDeviceId == nil)
        #expect(state.statusDescription == "Idle")
    }

    @Test("Starting state properties")
    func startingState() {
        let state = SessionState.starting(deviceId: "SERIAL_A")
        #expect(!state.isActive)
        #expect(state.isTransitioning)
        #expect(state.activeDeviceId == "SERIAL_A")
        #expect(state.statusDescription == "Starting session…")
    }

    @Test("Active state properties")
    func activeState() {
        let now = Date()
        let state = SessionState.active(deviceId: "SERIAL_B", pid: 12345, startTime: now)
        #expect(state.isActive)
        #expect(!state.isTransitioning)
        #expect(state.activeDeviceId == "SERIAL_B")
        #expect(state.statusDescription == "Mirroring active (PID 12345)")
    }

    @Test("Stopping state properties")
    func stoppingState() {
        let state = SessionState.stopping(deviceId: "SERIAL_C")
        #expect(!state.isActive)
        #expect(state.isTransitioning)
        #expect(state.activeDeviceId == "SERIAL_C")
        #expect(state.statusDescription == "Stopping session…")
    }

    @Test("Terminated state properties")
    func terminatedState() {
        let stateWithMsg = SessionState.terminated(deviceId: "SERIAL_D", exitCode: 0, message: "User closed window")
        #expect(!stateWithMsg.isActive)
        #expect(stateWithMsg.activeDeviceId == "SERIAL_D")
        #expect(stateWithMsg.statusDescription == "Session closed (User closed window)")

        let stateWithoutMsg = SessionState.terminated(deviceId: "SERIAL_D", exitCode: 15, message: nil)
        #expect(stateWithoutMsg.statusDescription == "Session terminated (exit code 15)")
    }

    @Test("Failed state properties")
    func failedState() {
        let state = SessionState.failed(deviceId: "SERIAL_E", error: "Connection lost")
        #expect(!state.isActive)
        #expect(state.activeDeviceId == "SERIAL_E")
        #expect(state.statusDescription == "Failed: Connection lost")
    }
}
