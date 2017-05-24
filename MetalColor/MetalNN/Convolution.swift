//
//  Convolution.swift
//  MetalColor
//
//  Created by Ruoyu Fu on 20/5/2017.
//  Copyright © 2017 Ruoyu. All rights reserved.
//

import Foundation
import MetalPerformanceShaders

func PoolingMax(device: MTLDevice,
                kernelWidth: Int = 2, kernelHeight: Int = 2,
                strideInPixelsX: Int = 2, strideInPixelsY: Int = 2) -> Layer {
    let pool = MPSCNNPoolingMax(device: device,
                                kernelWidth: kernelWidth,
                                kernelHeight: kernelHeight,
                                strideInPixelsX: strideInPixelsX,
                                strideInPixelsY: strideInPixelsY)
    pool.offset = MPSOffset( x: 1, y: 1, z: 0 )
    return { (commandbuffer, input) in
        let outputID = MPSImageDescriptor(channelFormat: .float16,
                                          width: input.width/2,
                                          height: input.height/2,
                                          featureChannels: input.featureChannels)
        let output = MPSTemporaryImage(commandBuffer: commandbuffer, imageDescriptor: outputID)
        pool.encode(commandBuffer: commandbuffer, sourceImage: input, destinationImage: output)
        return (commandbuffer, output)
    }
}

func Conv2d(kernelWidth: Int = 3, kernelHeight: Int = 3,
            inputFeatures: Int, outputFeatures: Int,
            activation: MPSCNNNeuron? = nil, device: MTLDevice, name: String) -> Layer {
    let convDesc = MPSCNNConvolutionDescriptor(kernelWidth: kernelWidth,
                                               kernelHeight: kernelHeight,
                                               inputFeatureChannels: inputFeatures,
                                               outputFeatureChannels: outputFeatures,
                                               neuronFilter: activation)
    let w = loadParam(name: name + "_filter",
                      count: inputFeatures * kernelHeight * kernelWidth * outputFeatures)
    let b = loadParam(name: name + "_biases", count: outputFeatures)
    let conv = MPSCNNConvolution(device: device,
                                 convolutionDescriptor: convDesc,
                                 kernelWeights: w!,
                                 biasTerms: b,
                                 flags: .none)

    return { (commandbuffer, input) in
        let outputID = MPSImageDescriptor(channelFormat: .float16,
                                          width: input.width,
                                          height: input.height,
                                          featureChannels: outputFeatures)
        let output = MPSTemporaryImage(commandBuffer: commandbuffer, imageDescriptor: outputID)
        conv.encode(commandBuffer: commandbuffer, sourceImage: input, destinationImage: output)
        return (commandbuffer, output)
    }
}

func Relu(device: MTLDevice)->Layer{
    let relu = MPSCNNNeuronReLU(device: device, a: 0)
    return { (commandbuffer, image) in
        let outputID = MPSImageDescriptor(channelFormat: .float16,
                                          width: image.width,
                                          height: image.height,
                                          featureChannels: image.featureChannels)
        let output = MPSTemporaryImage(commandBuffer: commandbuffer, imageDescriptor: outputID)
        relu.encode(commandBuffer: commandbuffer, sourceImage: image, destinationImage: output)
        return (commandbuffer, output)
    }
}

func Sigmoid(device: MTLDevice)->Layer{
    let relu = MPSCNNNeuronSigmoid(device: device)
    return { (commandbuffer, image) in
        let outputID = MPSImageDescriptor(channelFormat: .float16,
                                          width: image.width,
                                          height: image.height,
                                          featureChannels: image.featureChannels)
        let output = MPSTemporaryImage(commandBuffer: commandbuffer, imageDescriptor: outputID)
        relu.encode(commandBuffer: commandbuffer, sourceImage: image, destinationImage: output)
        return (commandbuffer, output)
    }
}


