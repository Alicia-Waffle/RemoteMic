import Foundation

func pass(_ message: String) {
    // 测试二进制里 Log.swift 覆盖了全局 print，这里直接写标准输出。
    FileHandle.standardOutput.write(Data("PASS: \(message)\n".utf8))
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
    exit(1)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fail(message) }
}

do {
    let protocolHandler = ATVVProtocol()
    try protocolHandler.acceptCapabilities(
        ATVVCapabilities(
            version: .v10,
            codecs: ATVVCodec.adpcm16k.rawValue,
            interactionModel: 0,
            frameSize: 120
        )
    )

    let packet = Data([0x12, 0x34, 0xAB, 0xCD, 0x56, 0x78])
    protocolHandler.beginAudioStream(codec: .adpcm16k)
    let first = protocolHandler.decodeAudio(packet)
    require(first != nil, "first stream did not decode")

    _ = protocolHandler.decodeAudio(Data(repeating: 0x77, count: 24))
    protocolHandler.endAudioStream()
    protocolHandler.beginAudioStream(codec: .adpcm16k)
    let second = protocolHandler.decodeAudio(packet)

    require(second != nil, "second stream did not decode")
    require(first?.samples == second?.samples, "ADPCM state was not reset")
    require(first?.sequence == 0, "first stream sequence did not start at zero")
    require(second?.sequence == 0, "second stream sequence did not restart")

    // AUDIO_SYNC is allowed on either side of AUDIO_START. Verify that START
    // no longer erases a sync received during MIC_OPEN.
    protocolHandler.prepareForAudioStream()
    protocolHandler.applyAudioSync(
        codec: .adpcm16k,
        sequence: 42,
        predictor: 1_234,
        stepIndex: 20
    )
    protocolHandler.beginAudioStream(codec: .adpcm16k)
    let synced = protocolHandler.decodeAudio(Data([0x12, 0x34]))
    require(synced?.sequence == 42, "AUDIO_START erased AUDIO_SYNC sequence")
    require(
        synced?.samples.first != first?.samples.first,
        "AUDIO_START erased AUDIO_SYNC decoder state"
    )

    // A sync applied during one active stream must not become the initializer
    // for the next stream.
    protocolHandler.applyAudioSync(
        codec: .adpcm16k,
        sequence: 70,
        predictor: -2_000,
        stepIndex: 30
    )
    _ = protocolHandler.decodeAudio(Data([0x77, 0x77]))
    protocolHandler.endAudioStream()
    protocolHandler.beginAudioStream(codec: .adpcm16k)
    let afterActiveSync = protocolHandler.decodeAudio(packet)
    require(
        afterActiveSync?.samples == first?.samples,
        "active-stream AUDIO_SYNC leaked into the next stream"
    )
    require(
        afterActiveSync?.sequence == 0,
        "new unsynchronized stream sequence did not reset"
    )

    pass("repeated AUDIO_START resets unsynchronized streams")
    pass("AUDIO_START preserves a fresh AUDIO_SYNC")
    pass("active-stream AUDIO_SYNC does not leak into next stream")
} catch {
    fail("\(error)")
}

runActionSelfTests()
