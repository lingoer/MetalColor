//
//  ColorNet.swift
//  MetalColor
//
//  Created by Ruoyu Fu on 19/5/2017.
//  Copyright © 2017 Ruoyu. All rights reserved.
//

import Foundation
import MetalPerformanceShaders


func ColorNet(device: MTLDevice) -> Layer {

    let relu = MPSCNNNeuronReLU(device: device, a: 0)
    let sigmoid = MPSCNNNeuronSigmoid(device: device)
    let gray3 = Input(device: device)
    let poolMax = PoolingMax(device: device)
    let scaleAdd = UpscaleAdd(device: device)
    let add = Add(device: device)

    let adjustVGG = AdjustVGG(device: device)
    let adjustGray = AdjustGray(device: device)

    let vgg16_conv1_1 = Conv2d(inputFeatures: 3,   outputFeatures: 64,  activation: relu, device: device, name: "vgg16_conv1_1")
    let vgg16_conv1_2 = Conv2d(inputFeatures: 64,  outputFeatures: 64,  activation: relu, device: device, name: "vgg16_conv1_2")
    let vgg16_conv2_1 = Conv2d(inputFeatures: 64,  outputFeatures: 128, activation: relu, device: device, name: "vgg16_conv2_1")
    let vgg16_conv2_2 = Conv2d(inputFeatures: 128, outputFeatures: 128, activation: relu, device: device, name: "vgg16_conv2_2")
    let vgg16_conv3_1 = Conv2d(inputFeatures: 128, outputFeatures: 256, activation: relu, device: device, name: "vgg16_conv3_1")
    let vgg16_conv3_2 = Conv2d(inputFeatures: 256, outputFeatures: 256, activation: relu, device: device, name: "vgg16_conv3_2")
    let vgg16_conv3_3 = Conv2d(inputFeatures: 256, outputFeatures: 256, activation: relu, device: device, name: "vgg16_conv3_3")
    let vgg16_conv4_1 = Conv2d(inputFeatures: 256, outputFeatures: 512, activation: relu, device: device, name: "vgg16_conv4_1")
    let vgg16_conv4_2 = Conv2d(inputFeatures: 512, outputFeatures: 512, activation: relu, device: device, name: "vgg16_conv4_2")
    let vgg16_conv4_3 = Conv2d(inputFeatures: 512, outputFeatures: 512, activation: relu, device: device, name: "vgg16_conv4_3")

    let bn1 = BatchNorm(features: 64, device: device, name: "pool1")
    let bn2 = BatchNorm(features: 128, device: device, name: "pool2")
    let bn3 = BatchNorm(features: 256, device: device, name: "pool3")
    let bn4 = BatchNorm(features: 512, device: device, name: "pool4")

    let color0 = Conv2d(inputFeatures: 3, outputFeatures: 3,  activation: relu, device: device, name: "color0")
    let color1 = Conv2d(inputFeatures: 64, outputFeatures: 3,  activation: relu, device: device, name: "color1")
    let color2 = Conv2d(inputFeatures: 128, outputFeatures: 64,  activation: relu, device: device, name: "color2")
    let color3 = Conv2d(inputFeatures: 256, outputFeatures: 128,  activation: relu, device: device, name: "color3")
    let color4 = Conv2d(kernelWidth: 1, kernelHeight: 1,
                        inputFeatures: 512, outputFeatures: 256,  activation: relu,
                        device: device, name: "color4")
    
    let uv = Conv2d(inputFeatures: 3, outputFeatures: 2,  activation: sigmoid, device: device, name: "uv")
    return { raw in
        let input = raw
            |> gray3
            |> retain()
        let pool1 = input
            |> adjustVGG
            |> vgg16_conv1_1
            |> vgg16_conv1_2
            |> retain()

        let pool2 = pool1
            |> poolMax
            |> vgg16_conv2_1
            |> vgg16_conv2_2
            |> retain()

        let pool3 = pool2
            |> poolMax
            |> vgg16_conv3_1
            |> vgg16_conv3_2
            |> vgg16_conv3_3
            |> retain()

        let pool4 = pool3
            |> poolMax
            |> vgg16_conv4_1
            |> vgg16_conv4_2
            |> vgg16_conv4_3

        let out = (pool4 |> bn4)
            |> color4
            |> scaleAdd(pool3 |> bn3)
            |> color3
            |> scaleAdd(pool2 |> bn2)
            |> color2
            |> scaleAdd(pool1 |> bn1)
            |> color1
            |> add(input |> adjustGray)
            |> color0
            |> uv

        return out
    }
}
