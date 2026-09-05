import AVFoundation
import XCTest
@testable import PostcardFilm

final class FlashPlanTests: XCTestCase {
    func testOffYieldsNoneOnBack() {
        XCTAssertEqual(FlashPlan.resolve(isFlashOn: false, position: .back), .none)
    }

    func testOffYieldsNoneOnFront() {
        XCTAssertEqual(FlashPlan.resolve(isFlashOn: false, position: .front), .none)
    }

    func testOnBackYieldsHardware() {
        XCTAssertEqual(FlashPlan.resolve(isFlashOn: true, position: .back), .hardware)
    }

    func testOnFrontYieldsScreen() {
        XCTAssertEqual(FlashPlan.resolve(isFlashOn: true, position: .front), .screen)
    }

    func testLadderKeepsDesiredForFirstTwoAttempts() {
        XCTAssertEqual(CaptureAttemptLadder.preference(forAttempt: 1), .desired)
        XCTAssertEqual(CaptureAttemptLadder.preference(forAttempt: 2), .desired)
    }

    func testLadderForcesOffOnFinalAttempt() {
        XCTAssertEqual(
            CaptureAttemptLadder.preference(forAttempt: CaptureAttemptLadder.maxAttempts),
            .forceOff
        )
    }

    func testHardwareFlashModeDesiredOnHardwarePlan() {
        XCTAssertEqual(
            CaptureAttemptLadder.hardwareFlashMode(preference: .desired, plan: .hardware),
            .on
        )
    }

    func testHardwareFlashModeDesiredOnScreenOrNoneIsOff() {
        XCTAssertEqual(
            CaptureAttemptLadder.hardwareFlashMode(preference: .desired, plan: .screen),
            .off
        )
        XCTAssertEqual(
            CaptureAttemptLadder.hardwareFlashMode(preference: .desired, plan: .none),
            .off
        )
    }

    func testHardwareFlashModeForceOffAlwaysOff() {
        XCTAssertEqual(
            CaptureAttemptLadder.hardwareFlashMode(preference: .forceOff, plan: .hardware),
            .off
        )
        XCTAssertEqual(
            CaptureAttemptLadder.hardwareFlashMode(preference: .forceOff, plan: .screen),
            .off
        )
    }
}
