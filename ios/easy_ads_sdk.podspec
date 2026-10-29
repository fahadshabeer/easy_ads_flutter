Pod::Spec.new do |s|
  s.name             = 'easy_ads_sdk'
  s.version          = '0.2.1'
  s.summary          = 'AdMob ads with Meta Audience Network bidding.'
  s.description      = <<-DESC
AdMob ads with Meta Audience Network bidding. The iOS plugin shows the App Tracking Transparency prompt.
                       DESC
  s.homepage         = 'https://github.com/fahadshabeer/easy_ads_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Easy Ads' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'easy_ads_sdk/Sources/easy_ads_sdk/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.static_framework = true
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
