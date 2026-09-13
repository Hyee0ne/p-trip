import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 알림 탭이 플러그인(flutter_local_notifications)까지 닿게 한다 (2026-09-13).
    // 이 줄이 없으면 알림 센터 델리게이트가 비어 있어 iOS 가 탭을 아무에게도 안 준다 —
    // 앱만 열리고 페이로드(spot:<id>)는 버려졌다 (실기기). 플러그인 README 의 필수 설정이다.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
