// app/Core/RPC/Worker.swift
import BareKit
import Foundation

final class Worker: ObservableObject {
    private var worklet: Worklet?
    var ipc: IPC?

    func start() {
        worklet = Worklet()
        worklet?.start(name: "app", ofType: "bundle")
        if let w = worklet { ipc = IPC(worklet: w) }
    }
    func suspend()   { worklet?.suspend() }
    func resume()    { worklet?.resume() }
    func terminate() { worklet?.terminate() }
}