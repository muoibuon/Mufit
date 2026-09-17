import XCTest

final class MufitUITests: XCTestCase {
    @MainActor
    func testPrimaryButtonOnCurrentSimulator() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        let guest = app.buttons["Dùng thử không cần tài khoản"]
        if guest.waitForExistence(timeout: 5) { guest.tap() }

        if app.buttons["Bắt đầu"].waitForExistence(timeout: 3) {
            app.buttons["Bắt đầu"].tap()
            for _ in 0..<12 {
                if app.buttons["Vào app"].exists {
                    app.buttons["Vào app"].tap()
                    break
                }
                if app.buttons["Bỏ qua"].exists {
                    app.buttons["Bỏ qua"].tap()
                } else if app.buttons["Tiếp tục"].exists {
                    app.buttons["Tiếp tục"].tap()
                }
            }
        }

        XCTAssertTrue(app.staticTexts["Việc hôm nay"].waitForExistence(timeout: 15), app.debugDescription)
        attachScreenshot(app, named: "Current simulator Today")
        app.tabBars.buttons["Cơ thể"].tap()
        XCTAssertTrue(app.navigationBars["Cơ thể"].waitForExistence(timeout: 5), app.debugDescription)
        attachScreenshot(app, named: "Current simulator Body")
        app.tabBars.buttons["Hôm nay"].tap()
        if app.buttons["Mở buổi tập hôm nay"].exists {
            app.buttons["Mở buổi tập hôm nay"].tap()
            if app.buttons["Bắt đầu buổi tập"].waitForExistence(timeout: 5) {
                let repRows = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "reps ×"))
                XCTAssertEqual(repRows.count, 0)
                attachScreenshot(app, named: "Current simulator planned workout")
            }
        }
    }

    @MainActor
    func testQuickWorkoutAndTodayActions() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "Simulator permissions") { alert in
            for title in ["Từ chối", "Không cho phép", "Don’t Allow"] {
                let button = alert.buttons[title]
                if button.exists { button.tap(); return true }
            }
            return false
        }
        app.launch()

        let guest = app.buttons["Dùng thử không cần tài khoản"]
        if guest.waitForExistence(timeout: 8) { guest.tap() }

        if app.buttons["Bắt đầu"].waitForExistence(timeout: 5) {
            app.buttons["Bắt đầu"].tap()
            for _ in 0..<12 {
                if app.buttons["Vào app"].exists {
                    app.buttons["Vào app"].tap()
                    break
                }
                if app.buttons["Bỏ qua"].exists {
                    app.buttons["Bỏ qua"].tap()
                } else if app.buttons["Tiếp tục"].exists {
                    app.buttons["Tiếp tục"].tap()
                }
            }
        }

        for _ in 0..<3 where !app.buttons["Ghi bữa ăn"].isHittable {
            let back = app.navigationBars.buttons["Hôm nay"]
            if back.exists {
                back.tap()
            } else {
                app.tabBars.buttons["Hôm nay"].tap()
            }
        }

        XCTAssertTrue(app.staticTexts["Việc hôm nay"].waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.buttons["Ghi bữa ăn"].isHittable)
        XCTAssertTrue(app.staticTexts["Thông tin thêm"].exists)
        attachScreenshot(app, named: "Today primary action")

        app.tabBars.buttons["Cơ thể"].tap()
        for _ in 0..<5 where !app.buttons["Nhập số đo đầu tiên"].isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        // Hồ sơ đã có số đo sẽ hiện thẻ thành phần cơ thể thay cho nút nhập đầu tiên.
        if app.buttons["Nhập số đo đầu tiên"].isHittable {
            attachScreenshot(app, named: "Body primary action")
        } else {
            XCTAssertTrue(app.staticTexts["Thành phần cơ thể"].exists, app.debugDescription)
        }
        app.tabBars.buttons["Hôm nay"].tap()

        app.buttons["Ghi bữa ăn"].tap()
        XCTAssertTrue(app.navigationBars["Thêm bữa ăn"].waitForExistence(timeout: 8), app.debugDescription)
        app.buttons["Huỷ"].tap()
        app.tabBars.buttons["Hôm nay"].tap()

        if app.buttons["Tạo buổi tập"].exists {
            app.buttons["Tạo buổi tập"].tap()
        } else {
            app.tabBars.buttons["Lịch tập"].tap()
            app.navigationBars["Lịch tập"].buttons["plus"].tap()
        }
        XCTAssertTrue(app.buttons["Thêm bài tập"].waitForExistence(timeout: 8), app.debugDescription)
        app.buttons["Thêm bài tập"].tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 8), app.debugDescription)
        search.tap()
        search.typeText("Barbell Back Squat")
        let squat = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Barbell Back Squat")).firstMatch
        XCTAssertTrue(squat.waitForExistence(timeout: 8), app.debugDescription)
        squat.tap()

        XCTAssertTrue(app.staticTexts["Thiết lập nhanh"].waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.buttons["Thiết lập nâng cao"].exists)
        app.buttons["Thiết lập nâng cao"].tap()
        XCTAssertTrue(app.staticTexts["Chỉnh từng set"].exists)
        app.buttons["Thêm"].tap()

        XCTAssertTrue(app.buttons["Chỉnh chi tiết"].waitForExistence(timeout: 8), app.debugDescription)
        app.buttons["Lưu"].tap()
        app.tabBars.buttons["Hôm nay"].tap()
        XCTAssertTrue(app.buttons["Mở buổi tập hôm nay"].waitForExistence(timeout: 8), app.debugDescription)
        app.buttons["Mở buổi tập hôm nay"].tap()
        XCTAssertTrue(app.buttons["Bắt đầu buổi tập"].waitForExistence(timeout: 8), app.debugDescription)
        let repRows = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "reps ×"))
        XCTAssertEqual(repRows.count, 0, "Set/reps chỉ được hiện sau khi bắt đầu")
        attachScreenshot(app, named: "Workout primary action")
        app.buttons["Bắt đầu buổi tập"].tap()
        XCTAssertGreaterThan(repRows.count, 0, "Set/reps phải hiện khi đang tập")
        attachScreenshot(app, named: "Workout after starting")
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
