Pod::Spec.new do |s|
  s.name             = 'NotifySDK'
  s.version          = '1.0.0'
  s.summary          = 'Native iOS SDK for NotifyMVP Push Notifications Service'
  s.description      = <<-DESC
                       NotifySDK is the official iOS client SDK for NotifyMVP.
                       It handles device registration, APNs/FCM tokens, topic subscriptions,
                       user opt-in/opt-out preferences, and push notification tap events.
                       DESC

  s.homepage         = 'https://github.com/aslamSk301/notyfy'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'NotifyMVP Team' => 'support@notifymvp.com' }
  s.source           = { :git => 'https://github.com/aslamSk301/notyfy.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.7'

  s.source_files = 'Sources/NotifySDK/**/*'
  s.frameworks   = 'Foundation', 'UIKit', 'UserNotifications'
end
