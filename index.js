'use strict';

const { NativeModules } = require('react-native');
const { MultipleImagePickerManager } = NativeModules;

const DEFAULT_OPTIONS = {
  title: '',
  cancelButtonTitle: '取消',
  takePhotoButtonTitle: '拍照',
  chooseFromLibraryButtonTitle: '从手机相册选择',
  quality: 1.0,
  allowsEditing: false
};

module.exports = {
  ...MultipleImagePickerManager,
  launchCamera: function launchCamera(options, callback) {
    if (typeof options === 'function') {
      callback = options;
      options = {};
    }
    return MultipleImagePickerManager.launchCamera({...DEFAULT_OPTIONS, ...options}, callback);
  }
};
