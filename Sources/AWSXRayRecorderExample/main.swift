import AWSXRayHTTPEmitter
import AWSXRayRecorder
import AWSXRayUDPEmitter
import NIO

func env(_ name: String) -> String? {
    guard let value = getenv(name) else { return nil }
    return String(cString: value)
}

let httpEmitter = env("AWS_XRAY_DAEMON_ADDRESS")?.starts(with: "http") ?? false
if httpEmitter {
    precondition(env("AWS_ACCESS_KEY_ID") != nil, "AWS_ACCESS_KEY_ID not set")
    precondition(env("AWS_SECRET_ACCESS_KEY") != nil, "AWS_SECRET_ACCESS_KEY not set")
}
    
enum ExampleError: Error {
    case test
}

let emitter: XRayEmitter
if httpEmitter {
    emitter = XRayHTTPEmitter()
} else {
    emitter = XRayUDPEmitter()
}

let recorder = XRayRecorder()

// begin and end (sub)segments explicitly
let segment = recorder.beginSegment(name: "Segment 1")
segment.setAnnotation("zip_code", value: 98101)
segment.setMetadata(["debug": ["test": "Metadata string"]])
usleep(100_000)
segment.end()

// use closures for convenience
recorder.segment(name: "Segment 2") { segment in
    try? segment.subsegment(name: "Subsegment 2.1") { segment in
        _ = segment.subsegment(name: "Subsegment 2.1.1 with Result") { _ -> String in
            usleep(100_000)
            return "Result"
        }
        try segment.subsegment(name: "Subsegment 2.1.2 with Error") { _ in
            usleep(200_000)
            throw ExampleError.test
        }
    }
}

try emitter.send(segments: recorder.removeAll())
    .wait()

exit(0)
