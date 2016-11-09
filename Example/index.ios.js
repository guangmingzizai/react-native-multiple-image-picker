'use strict';

import React, { Component } from 'react';
import {
  AppRegistry,
  StyleSheet,
  Text,
  View,
  PixelRatio,
  TouchableOpacity,
  Image,
  Platform
} from 'react-native';

import MultipleImagePicker from 'react-native-multiple-image-picker';
import type {
  MultipleImagePikcerResultItem,
  MultipleImagePickerError,
  MultipleImagePickerCallback,
} from 'react-native-multiple-image-picker';

export default class Example extends Component {
  state = {
    avatarSource: null,
  };

  selectPhotoTapped() {
    const options = {
      quality: 1.0,
      maxWidth: 500,
      maxHeight: 500,
      storageOptions: {
        skipBackup: true
      },
      cancelButtonTitle: '取消',
      takePhotoButtonTitle: '拍照',
      chooseFromLibraryButtonTitle: '从相册选取',
    };

    MultipleImagePicker.showImagePicker(options, (error: MultipleImagePickerError, imageInfos: Array<MultipleImagePikcerResultItem>) => {
      console.log(`error:${error}, imageInfos:${imageInfos}`);

      if (error) {
        console.log(error);
      }
      else {
        var response = imageInfos[0];
        var source;

        // You can display the image using either:
        //source = {uri: 'data:image/jpeg;base64,' + response.data, isStatic: true};

        //Or:
        if (Platform.OS === 'android') {
          source = {uri: response.uri, isStatic: true};
        } else {
          source = {uri: response.uri.replace('file://', ''), isStatic: true};
        }

        this.setState({
          avatarSource: source
        });
      }
    });
  }

  render() {
    return (
      <View style={styles.container}>
        <TouchableOpacity onPress={this.selectPhotoTapped.bind(this)}>
          <View style={[styles.avatar, styles.avatarContainer, {marginBottom: 20}]}>
          { this.state.avatarSource === null ? <Text>Select a Photo</Text> :
            <Image style={styles.avatar} source={this.state.avatarSource} />
          }
          </View>
        </TouchableOpacity>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5FCFF',
  },
  avatarContainer: {
    borderColor: '#9B9B9B',
    borderWidth: 1 / PixelRatio.get(),
    justifyContent: 'center',
    alignItems: 'center'
  },
  avatar: {
    borderRadius: 75,
    width: 150,
    height: 150
  }
});

AppRegistry.registerComponent('Example', () => Example);
