Pod::Spec.new do |s|
  s.name         = "react-native-multiple-image-picker"
  s.version      = "0.1.0"
  s.license      = "MIT"
  s.homepage     = "https://github.com/guangmingzizai/react-native-multiple-image-picker"
  s.authors      = { 'guangmingzizai' => 'guangmingzizai@qq.com' }
  s.summary      = "A React Native module that allows you to select multiple images from photo assets."
  s.description      = <<-DESC
  This library bridge BLPhotoAssetPickerController to react-native.
  BLPhotoAssetPickerController is a multiple image picker of mine.
                       DESC
  s.source       = {
    :git => "https://github.com/guangmingzizai/react-native-multiple-image-picker",
    :tag => '0.1.0'
  }
  s.source_files  = "ios/RNMultipleImagePicker/Classes/**/*"

  s.platform     = :ios, "8.0"
  s.dependency 'React'
  s.dependency 'BLPhotoAssetPickerController'
  s.dependency 'RMUniversalAlert'
end
