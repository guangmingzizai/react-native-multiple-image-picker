Pod::Spec.new do |s|
  s.name         = "react-native-multiple-image-picker"
  s.version      = "0.0.1"
  s.license      = "MIT"
  s.homepage     = "https://github.com/guangmingzizai/react-native-multiple-image-picker"
  s.authors      = { 'Wang JianFei' => 'guangmingzizai@qq.com' }
  s.summary      = "A React Native module that allows you to select multiple images from photo assets."
  s.source       = { :git => "https://github.com/guangmingzizai/react-native-multiple-image-picker" }
  s.source_files  = "ios/RNMultipleImagePicker/*.{h,m}"

  s.platform     = :ios, "8.0"
  s.dependency 'React'
  s.dependency 'BLPhotoAssetPickerController'
  s.dependency 'RMUniversalAlert'
end
