//
//  AKAudioUnit.swift
//  AudioKit
//
//  Created by James Ordner, revision history on GitHub.
//  Copyright © 2020 AudioKit. All rights reserved.
//

import AudioToolbox

open class AKAudioUnitBase: AUAudioUnit {

    // MARK: AUAudioUnit Overrides
    
    private var inputBusArray: [AUAudioUnitBus] = []
    private var outputBusArray: [AUAudioUnitBus] = []
    
    private var pcmBufferArray: [AVAudioPCMBuffer?] = []

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        
        let format = AKSettings.audioFormat
        
        try inputBusArray.forEach{ if $0.format != format { try $0.setFormat(format) }}
        try outputBusArray.forEach{ if $0.format != format { try $0.setFormat(format) }}
        
        // we don't need to allocate a buffer if we can process in place
        if !canProcessInPlace || inputBusArray.count > 1 {
            for i in inputBusArray.indices {
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: maximumFramesToRender)
                pcmBufferArray.append(buffer)
                setBufferDSP(dsp, buffer, i)
            }
        }
        
        allocateRenderResourcesDSP(dsp, format)
    }

    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
        deallocateRenderResourcesDSP(dsp)
        pcmBufferArray.removeAll()
    }

    public override func reset() {
        resetDSP(dsp)
    }

    lazy private var auInputBusArray: AUAudioUnitBusArray = {
        AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: inputBusArray)
    }()
    
    public override var inputBusses: AUAudioUnitBusArray {
        return auInputBusArray
    }
    
    lazy private var auOutputBusArray: AUAudioUnitBusArray = {
        AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: outputBusArray)
    }()

    public override var outputBusses: AUAudioUnitBusArray {
        return auOutputBusArray
    }
    
    public override var internalRenderBlock: AUInternalRenderBlock {
        internalRenderBlockDSP(dsp)
    }

    public override var parameterTree: AUParameterTree? {
        didSet {
            parameterTree?.implementorValueObserver = { [unowned self] parameter, value in
                setParameterDSP(self.dsp, parameter.address, value)
            }

            parameterTree?.implementorValueProvider = { [unowned self] parameter in
                return getParameterDSP(self.dsp, parameter.address)
            }

            parameterTree?.implementorStringFromValueCallback = { parameter, value in
                if let value = value {
                    return String(format: "%.f", value)
                } else {
                    return "Invalid"
                }
            }
        }
    }

    public override var canProcessInPlace: Bool {
        return canProcessInPlaceDSP(dsp)
    }

    // MARK: Lifecycle
    
    public private(set) var dsp: AKDSPRef?
    
    public override init(componentDescription: AudioComponentDescription,
                         options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)

        // Create pointer to the underlying C++ DSP code
        dsp = createDSP()
        if dsp == nil { throw AKError.InvalidDSPObject }
        
        // set default ramp duration
        setRampDurationDSP(dsp, Float(rampDuration))
        
        // create audio bus connection points
        let format = AKSettings.audioFormat
        for _ in 0..<inputBusCountDSP(dsp) {
            inputBusArray.append(try AUAudioUnitBus(format: format))
        }
        for _ in 0..<outputBusCountDSP(dsp) {
            outputBusArray.append(try AUAudioUnitBus(format: format))
        }
    }

    deinit {
        deleteDSP(dsp)
    }

    // MARK: AudioKit
    
    public private(set) var isStarted: Bool = true
    
    /// Paramater ramp duration (seconds)
    public var rampDuration: Double = AKSettings.rampDuration {
        didSet {
            setRampDurationDSP(dsp, Float(rampDuration))
        }
    }
    
    /// This should be overridden. All the base class does is make sure that the pointer to the DSP is invalid.
    public func createDSP() -> AKDSPRef? {
        return nil
    }
    
    public func start() {
        isStarted = true
        startDSP(dsp)
    }

    public func stop() {
        isStarted = false
        stopDSP(dsp)
    }

    public func trigger() {
        triggerDSP(dsp)
    }

    public func triggerFrequency(_ frequency: Float, amplitude: Float) {
        triggerFrequencyDSP(dsp, frequency, amplitude)
    }

    public func setWavetable(_ wavetable: [Float], index: Int = 0) {
        setWavetableDSP(dsp, wavetable, wavetable.count, Int32(index))
    }

    public func setWavetable(data: UnsafePointer<Float>?, size: Int, index: Int = 0) {
        setWavetableDSP(dsp, data, size, Int32(index))
    }
}