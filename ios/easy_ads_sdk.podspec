#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint easy_ads_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'easy_ads_sdk'
  s.version          = '0.0.1'
  s.summary          = 'One Flutter API for AdMob and Meta Audience Network, with priority and automatic fallback.'
  s.description      = <<-DESC
One Flutter API for AdMob and Meta Audience Network, with priority and automatic fallback.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'easy_ads_sdk/Sources/easy_ads_sdk/**/*'
  s.dependency 'Flutter'
  s.dependency 'FBAudienceNetwork', '6.22.0'
  s.platform = :ios, '15.0'
  s.static_framework = true

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'easy_ads_sdk_privacy' => ['easy_ads_sdk/Sources/easy_ads_sdk/PrivacyInfo.xcprivacy']}
end
