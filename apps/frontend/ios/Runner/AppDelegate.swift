import Flutter
import UIKit
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // 🚀 REGISTRO DE ANUNCIOS NATIVOS
    let factory = ListTileNativeAdFactory()
    GoogleMobileAdsPlugin.registerNativeAdFactory(self, factoryId: "listTile", nativeAdFactory: factory)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
