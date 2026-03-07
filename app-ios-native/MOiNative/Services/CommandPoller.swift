// 主界面在前台时轮询待执行指令，与 Flutter CommandPoller 规约一致
import Foundation

final class CommandPoller {
    private var timer: Timer?
    private var deviceId: String?
    private let interval: TimeInterval = 30
    private let firstPollDelay: TimeInterval = 0.3

    func start(deviceId: String) {
        if self.deviceId == deviceId, timer?.isValid == true { return }
        stop()
        self.deviceId = deviceId
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.poll() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + firstPollDelay) { [weak self] in
            Task { await self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        deviceId = nil
    }

    private func poll() async {
        guard let deviceId = deviceId else { return }
        var list = await CommandsApi.fetchPending(deviceId: deviceId)
        list = coalesceDialAndSms(list)
        for item in list {
            await CommandExecutor.execute(item)
        }
    }

    private func coalesceDialAndSms(_ list: [CommandItem]) -> [CommandItem] {
        var lastDial: CommandItem?
        var lastSms: CommandItem?
        var other: [CommandItem] = []
        for item in list {
            if item.cmd == "mop.cmd.dial" { lastDial = item }
            else if item.cmd == "mop.cmd.sms" { lastSms = item }
            else { other.append(item) }
        }
        var out = other
        if let d = lastDial { out.append(d) }
        if let s = lastSms { out.append(s) }
        return out
    }
}
