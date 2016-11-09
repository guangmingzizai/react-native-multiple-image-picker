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
  Platform,
  ScrollView,
  Dimensions,
} from 'react-native';

import MultipleImagePicker from 'react-native-multiple-image-picker';
import type {
  MultipleImagePikcerResultItem,
  MultipleImagePickerError,
} from 'react-native-multiple-image-picker';

type Photo = {
  id?: string;
  width: number;
  height: number;
  url: string;
  isStatic: boolean;
  timestamp?: number;
};

export default class Example extends Component {
  state: {
    images: [MultipleImagePikcerResultItem],
  };

  state = {
    images: [],
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
        var images = imageInfos.map((imageInfo: MultipleImagePikcerResultItem) => {
          return {
            width: imageInfo.width,
            height: imageInfo.height,
            url: (Platform.OS === 'android' ? imageInfo.uri : imageInfo.uri.replace('file://', '')),
            isStatic: true,
          };
        });
        this.setState({images});
      }
    });
  }

  render() {
    let screenWidth = Dimensions.get('window').width;
    let photoWidth = (screenWidth - 2 * 15 - 2 * 15) / 3;
    let images = this.state.images;
    return (
      <View style={styles.container}>
        <View style={{alignSelf: 'stretch', backgroundColor: 'pink', height: photoWidth}}>
          <ScrollView
            horizontal={true}
            showsHorizontalScrollIndicator={false}
          >
            {
              this.state.images.map((photo: Photo) => {
                return (
                  <Image
                    style={{width: photoWidth, height: photoWidth, marginLeft: 15}}
                    source={{uri: photo.url, isStatic: photo.isStatic}}
                  />
                )
              })
            }
            <TouchableOpacity onPress={this.selectPhotoTapped.bind(this)}>
              <View style={[{width: photoWidth, height: photoWidth, marginLeft: 15, marginRight: 15}, styles.avatarContainer, {marginLeft: 15}]}>
                <Text>Select a Photo</Text>
              </View>
            </TouchableOpacity>
          </ScrollView>
        </View>
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
});

AppRegistry.registerComponent('Example', () => Example);
