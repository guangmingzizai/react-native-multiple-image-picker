/**
* @Copyright: 这里科技（天津）有限公司
* @Author: wangjianfei
* @Date:   2016-11-04T18:39:50+08:00
* @Email:  guangmingzizai@qq.com
* @Project: NumOneMatchmaker
* @Last modified by:   wangjianfei
* @Last modified time: 2016-11-09T18:55:21+08:00
*
* @flow
*/
'use strict';

const { NativeModules } = require('react-native');
const { MultipleImagePickerManager } = NativeModules;

export type MultipleImagePickerError = {
  message: 'CANCELLED'|
  'CREATE_CACHE_DIR_FAILED'|
  'NO_CAMERA_PERMISSION'|
  'NO_PHOTO_ALBUM_PERMISSION'|
  'ACCESS_IMAGE_FAILED'|
  'CAMERA_NOT_SUPPORT';
};

export type MultipleImagePickerOptions = {
  title?: string;
  cancelButtonTitle: string;
  takePhotoButtonTitle: string;
  chooseFromLibraryButtonTitle: string;
  cameraType?: 'front'|'rear';
  allowsEditing?: boolean;
  maxSelectionNum?: number; //default 9
  maxWidth?: number;
  maxHeight?: number;
  imageFileType?: 'png'|'jpg'; //default jpg
  quality?: number; //jpg compress quality
  noData?: boolean; //whether callback should contains image data object, default false
  storageOptions?: {
    cameraRoll?: boolean; //whether save image to cameraRoll
    waitUntilSaved?: boolean; //whether callback after saving to cameraRoll
    path?: string; //cache dir
  }; //only for camera
};

export type MultipleImagePikcerResultItem = {
  data?: string; //base64 encoded string
  isVertical: boolean; //whether image.height > image.width
  uri: string; //temp cached file path
  origURL?: string; //image original url
  fileSize?: number; //image data size
  width: number;
  height: number;
};

const DEFAULT_OPTIONS: MultipleImagePickerOptions = {
  title: '',
  cancelButtonTitle: '取消',
  takePhotoButtonTitle: '拍照',
  chooseFromLibraryButtonTitle: '从手机相册选择',
  quality: 1.0,
  allowsEditing: false,
  maxWidth: 800,
  maxHeight: 1280,
  noData: true,
  maxSelectionNum: 4,
};

module.exports = {
  ...MultipleImagePickerManager,
  launchCamera: function (options: MultipleImagePickerOptions, callback) {
    if (typeof options === 'function') {
      callback = options;
      options = {};
    }
    return MultipleImagePickerManager.launchCamera({...DEFAULT_OPTIONS, ...options}, callback);
  },
  launchMultipleImagePicker: function (options: MultipleImagePickerOptions, callback) {
    if (typeof options === 'function') {
      callback = options;
      options = {};
    }
    return MultipleImagePickerManager.launchMultipleImagePicker({...DEFAULT_OPTIONS, ...options}, callback);
  },
  showImagePicker: function (options: MultipleImagePickerOptions, callback) {
    if (typeof options === 'function') {
      callback = options;
      options = {};
    }
    return MultipleImagePickerManager.showImagePicker({...DEFAULT_OPTIONS, ...options}, callback);
  },
};
