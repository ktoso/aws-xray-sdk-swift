import AWSXRayRecorder
import NIO

// TODO: parse arguments

func env(_ name: String) -> String? {
    guard let value = getenv(name) else { return nil }
    return String(cString: value)
}

assert(env("XRAY_ENDPOINT") != nil, "XRAY_ENDPOINT not set")
assert(env("AWS_ACCESS_KEY_ID") != nil, "AWS_ACCESS_KEY_ID not set")
assert(env("AWS_SECRET_ACCESS_KEY") != nil, "AWS_SECRET_ACCESS_KEY not set")

enum ExampleError: Error {
    case test
}

let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let emmiter = XRayEmmiter(eventLoop: group.next(), endpoint: env("XRAY_ENDPOINT"))

let recorder = XRayRecorder()

let segment = recorder.beginSegment(name: "Example")

try? segment.subsegment(name: "Subsegment A") { segment in
    _ = segment.subsegment(name: "Subsegment A.1 with Result") { _ -> String in
        usleep(100_000)
        return "Result"
    }
    try segment.subsegment(name: "Subsegment A.2 with Error") { _ in
        usleep(200_000)
        throw ExampleError.test
    }
}

segment.subsegment(name: "Subsegment B") { _ in usleep(300_000) }
segment.end()

try emmiter.send(segments: recorder.removeReady()).wait()

try group.syncShutdownGracefully()
exit(0)