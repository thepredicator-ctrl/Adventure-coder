import XCTest
@testable import AdventureCoder

final class AdvancedTemplatesTests: XCTestCase {
    var tmp: URL!

    override func setUp() {
        super.setUp()
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("template-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmp!)
        super.tearDown()
    }

    func testFlutterTemplate() {
        let files = AdvancedTemplates.flutterFiles(name: "MyApp")
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.contains { $0.0 == "pubspec.yaml" })
        XCTAssertTrue(files.contains { $0.0 == "lib/main.dart" })
    }

    func testKotlinTemplate() {
        let files = AdvancedTemplates.kotlinFiles(name: "MyApp")
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.contains { $0.0 == "build.gradle.kts" })
    }

    func testGoTemplate() {
        let files = AdvancedTemplates.goFiles(name: "MyApp")
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.contains { $0.0 == "go.mod" })
        XCTAssertTrue(files.contains { $0.0 == "main.go" })
    }

    func testJavaTemplate() {
        let files = AdvancedTemplates.javaFiles(name: "MyApp")
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.contains { $0.0 == "pom.xml" })
    }

    func testCSharpTemplate() {
        let files = AdvancedTemplates.csharpFiles(name: "MyApp")
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.contains { $0.0.contains(".csproj") })
    }

    func testVueTemplate() {
        let files = AdvancedTemplates.vueFiles(name: "MyApp")
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.contains { $0.0 == "package.json" })
        XCTAssertTrue(files.contains { $0.0 == "src/App.vue" })
    }

    func testSvelteTemplate() {
        let files = AdvancedTemplates.svelteFiles(name: "MyApp")
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.contains { $0.0.contains("+page.svelte") })
    }

    func testNextJSTemplate() {
        let files = AdvancedTemplates.nextjsFiles(name: "MyApp")
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.contains { $0.0 == "app/page.tsx" })
    }

    func testExpressTemplate() {
        let files = AdvancedTemplates.expressFiles(name: "MyApp")
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.contains { $0.0 == "index.js" })
    }

    func testDjangoTemplate() {
        let files = AdvancedTemplates.djangoFiles(name: "MyApp")
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.contains { $0.0 == "requirements.txt" })
    }

    func testFastAPITemplate() {
        let files = AdvancedTemplates.fastapiFiles(name: "MyApp")
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.contains { $0.0 == "main.py" })
    }

    func testRailsTemplate() {
        let files = AdvancedTemplates.railsFiles(name: "MyApp")
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.contains { $0.0 == "Gemfile" })
    }

    func testMAUITemplate() {
        let files = AdvancedTemplates.mauiFiles(name: "MyApp")
        XCTAssertFalse(files.isEmpty)
        XCTAssertTrue(files.contains { $0.0.contains(".csproj") })
    }

    func testFlutterMainDartContent() {
        let files = AdvancedTemplates.flutterFiles(name: "MyApp")
        let mainDart = files.first { $0.0 == "lib/main.dart" }?.1 ?? ""
        XCTAssertTrue(mainDart.contains("MyApp"))
        XCTAssertTrue(mainDart.contains("MaterialApp"))
    }

    func testGoMainContent() {
        let files = AdvancedTemplates.goFiles(name: "MyApp")
        let mainGo = files.first { $0.0 == "main.go" }?.1 ?? ""
        XCTAssertTrue(mainGo.contains("package main"))
        XCTAssertTrue(mainGo.contains("func main()"))
    }

    func testVueAppContent() {
        let files = AdvancedTemplates.vueFiles(name: "MyApp")
        let appVue = files.first { $0.0 == "src/App.vue" }?.1 ?? ""
        XCTAssertTrue(appVue.contains("<template>"))
        XCTAssertTrue(appVue.contains("MyApp"))
    }
}
